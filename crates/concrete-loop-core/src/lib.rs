//! Concrete Loop's Desktop authority core.
//!
//! The first vertical slice deliberately owns Root/Version invariants in Rust
//! and SQLite rather than in a frontend client.

use std::path::Path;

use rusqlite::{Connection, TransactionBehavior, params};

const MIGRATIONS: &[(i64, &str)] = &[(1, include_str!("../migrations/0001_initial.sql"))];

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("database schema {found} is newer than this application supports ({supported})")]
    NewerSchema { found: i64, supported: i64 },
}

pub type Result<T> = std::result::Result<T, Error>;

/// A randomly generated SQLCipher key. It intentionally exposes no string
/// representation and is only accepted by the Rust-side storage adapter.
pub struct DatabaseKey([u8; 32]);

impl DatabaseKey {
    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    fn sqlcipher_hex(&self) -> String {
        self.0.iter().map(|byte| format!("{byte:02x}")).collect()
    }
}

/// Owns one SQLite connection whose foreign-key enforcement is always enabled.
/// The production adapter will open SQLCipher using the same migration contract.
pub struct Database {
    connection: Connection,
}

impl Database {
    pub fn open_in_memory() -> Result<Self> {
        Self::from_connection(Connection::open_in_memory()?)
    }

    /// Opens a persistent SQLCipher database. There is deliberately no public
    /// unkeyed file-opening API.
    pub fn open_encrypted_path(path: impl AsRef<Path>, key: &DatabaseKey) -> Result<Self> {
        let connection = Connection::open(path)?;
        apply_sqlcipher_key(&connection, key)?;
        Self::from_connection(connection)
    }

    fn from_connection(mut connection: Connection) -> Result<Self> {
        connection.pragma_update(None, "foreign_keys", "ON")?;
        migrate(&mut connection)?;
        Ok(Self { connection })
    }

    pub fn applied_migrations(&self) -> Result<Vec<i64>> {
        let mut statement = self
            .connection
            .prepare("SELECT version FROM schema_migrations ORDER BY version")?;
        Ok(statement
            .query_map([], |row| row.get(0))?
            .collect::<std::result::Result<Vec<i64>, _>>()?)
    }

    pub fn create_question(
        &mut self,
        question_id: &str,
        version_id: &str,
        body: &str,
        created_at: i64,
    ) -> Result<()> {
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)?;
        transaction.execute(
            "INSERT INTO questions (id, created_at) VALUES (?1, ?2)",
            params![question_id, created_at],
        )?;
        transaction.execute(
            "INSERT INTO question_versions
             (id, question_id, version_no, body, created_at)
             VALUES (?1, ?2, 1, ?3, ?4)",
            params![version_id, question_id, body, created_at],
        )?;
        transaction.execute(
            "UPDATE questions SET current_version_id = ?1 WHERE id = ?2",
            params![version_id, question_id],
        )?;
        transaction.commit()?;
        Ok(())
    }

    pub fn append_question_version(
        &mut self,
        question_id: &str,
        version_id: &str,
        body: &str,
        created_at: i64,
    ) -> Result<()> {
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)?;
        let (previous_version_id, previous_version_no): (String, i64) = transaction.query_row(
            "SELECT current_version_id, version_no
             FROM questions JOIN question_versions ON question_versions.id = questions.current_version_id
             WHERE questions.id = ?1",
            [question_id],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )?;
        transaction.execute(
            "INSERT INTO question_versions
             (id, question_id, version_no, body, previous_version_id, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                version_id,
                question_id,
                previous_version_no + 1,
                body,
                previous_version_id,
                created_at
            ],
        )?;
        transaction.execute(
            "UPDATE questions SET current_version_id = ?1 WHERE id = ?2",
            params![version_id, question_id],
        )?;
        transaction.commit()?;
        Ok(())
    }

    /// This method exists to make the ownership constraint explicit at the
    /// repository boundary. SQLite's deferred composite FK is the final guard.
    pub fn set_current_question_version(
        &mut self,
        question_id: &str,
        version_id: &str,
    ) -> Result<()> {
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)?;
        transaction.execute(
            "UPDATE questions SET current_version_id = ?1 WHERE id = ?2",
            params![version_id, question_id],
        )?;
        transaction.commit()?;
        Ok(())
    }

    pub fn current_question_version(&self, question_id: &str) -> Result<String> {
        Ok(self.connection.query_row(
            "SELECT current_version_id FROM questions WHERE id = ?1",
            [question_id],
            |row| row.get(0),
        )?)
    }

    pub fn question_body(&self, version_id: &str) -> Result<String> {
        Ok(self.connection.query_row(
            "SELECT body FROM question_versions WHERE id = ?1",
            [version_id],
            |row| row.get(0),
        )?)
    }

    pub fn question_version_count(&self, question_id: &str) -> Result<i64> {
        Ok(self.connection.query_row(
            "SELECT COUNT(*) FROM question_versions WHERE question_id = ?1",
            [question_id],
            |row| row.get(0),
        )?)
    }

    pub fn register_fragment_resource_ref(
        &mut self,
        resource_ref_id: &str,
        fragment_id: &str,
        created_at: i64,
    ) -> Result<()> {
        self.connection.execute(
            "INSERT INTO resource_refs
             (id, resource_type, resource_id, fragment_id, created_at)
             VALUES (?1, 'FRAGMENT', ?2, ?2, ?3)",
            params![resource_ref_id, fragment_id, created_at],
        )?;
        Ok(())
    }
}

fn apply_sqlcipher_key(connection: &Connection, key: &DatabaseKey) -> Result<()> {
    // The value is derived only from fixed-size random bytes, then hex encoded;
    // no user-controlled SQL is interpolated into this PRAGMA.
    connection.execute_batch(&format!("PRAGMA key = \"x'{}'\";", key.sqlcipher_hex()))?;
    connection.query_row("SELECT COUNT(*) FROM sqlite_master", [], |row| {
        row.get::<_, i64>(0)
    })?;
    Ok(())
}

fn migrate(connection: &mut Connection) -> Result<()> {
    connection.execute_batch(
        "CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            applied_at INTEGER NOT NULL
        );",
    )?;
    let applied: i64 = connection.query_row(
        "SELECT COALESCE(MAX(version), 0) FROM schema_migrations",
        [],
        |row| row.get(0),
    )?;
    let supported = MIGRATIONS.last().map_or(0, |(version, _)| *version);
    if applied > supported {
        return Err(Error::NewerSchema {
            found: applied,
            supported,
        });
    }

    for (version, sql) in MIGRATIONS.iter().filter(|(version, _)| *version > applied) {
        let transaction = connection.transaction_with_behavior(TransactionBehavior::Immediate)?;
        transaction.execute_batch(sql)?;
        transaction.execute(
            "INSERT INTO schema_migrations (version, applied_at) VALUES (?1, unixepoch())",
            [version],
        )?;
        transaction.commit()?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::{
        fs,
        time::{SystemTime, UNIX_EPOCH},
    };

    use super::{Database, DatabaseKey, Error};
    use rusqlite::Connection;

    #[test]
    fn migration_creates_a_versioned_schema_and_records_its_revision() {
        let database = Database::open_in_memory().unwrap();

        assert_eq!(database.applied_migrations().unwrap(), vec![1]);
    }

    #[test]
    fn desktop_schema_is_exercised_against_sqlcipher() {
        let database = Database::open_in_memory().unwrap();

        let cipher_version: String = database
            .connection
            .query_row("PRAGMA cipher_version", [], |row| row.get(0))
            .unwrap();
        assert!(!cipher_version.is_empty());
    }

    #[test]
    fn newer_schema_is_rejected_before_the_database_is_used() {
        let connection = Connection::open_in_memory().unwrap();
        connection
            .execute_batch(
                "CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY, applied_at INTEGER NOT NULL);
                 INSERT INTO schema_migrations (version, applied_at) VALUES (2, 0);",
            )
            .unwrap();

        let result = Database::from_connection(connection);
        assert!(matches!(
            result,
            Err(Error::NewerSchema {
                found: 2,
                supported: 1
            })
        ));
    }

    #[test]
    fn encrypted_file_cannot_be_opened_without_its_key_or_reveal_plaintext() {
        let path = std::env::temp_dir().join(format!(
            "concrete-loop-encryption-{}-{}.db",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let key = DatabaseKey::from_bytes([7; 32]);
        let wrong_key = DatabaseKey::from_bytes([8; 32]);

        {
            let mut database = Database::open_encrypted_path(&path, &key).unwrap();
            database
                .create_question("question-a", "question-a-v1", "秘密の問い", 100)
                .unwrap();
        }

        let file = fs::read(&path).unwrap();
        assert!(
            !file
                .windows("秘密の問い".len())
                .any(|window| window == "秘密の問い".as_bytes())
        );
        assert!(
            Connection::open(&path)
                .unwrap()
                .query_row("SELECT COUNT(*) FROM sqlite_master", [], |row| row
                    .get::<_, i64>(0))
                .is_err()
        );
        assert!(Database::open_encrypted_path(&path, &wrong_key).is_err());
        assert_eq!(
            Database::open_encrypted_path(&path, &key)
                .unwrap()
                .question_body("question-a-v1")
                .unwrap(),
            "秘密の問い"
        );

        fs::remove_file(path).unwrap();
    }

    #[test]
    fn appending_a_question_version_preserves_the_previous_version() {
        let mut database = Database::open_in_memory().unwrap();
        database
            .create_question("question-a", "question-a-v1", "睡眠と集中の関係", 100)
            .unwrap();

        database
            .append_question_version("question-a", "question-a-v2", "睡眠不足と集中の関係", 200)
            .unwrap();

        assert_eq!(
            database.question_body("question-a-v1").unwrap(),
            "睡眠と集中の関係"
        );
        assert_eq!(
            database.question_body("question-a-v2").unwrap(),
            "睡眠不足と集中の関係"
        );
        assert_eq!(
            database.current_question_version("question-a").unwrap(),
            "question-a-v2"
        );
    }

    #[test]
    fn root_cannot_point_at_a_version_owned_by_another_root() {
        let mut database = Database::open_in_memory().unwrap();
        database
            .create_question("question-a", "question-a-v1", "問いA", 100)
            .unwrap();
        database
            .create_question("question-b", "question-b-v1", "問いB", 100)
            .unwrap();

        assert!(
            database
                .set_current_question_version("question-a", "question-b-v1")
                .is_err()
        );
        assert_eq!(
            database.current_question_version("question-a").unwrap(),
            "question-a-v1"
        );
    }

    #[test]
    fn new_version_cannot_name_a_previous_version_from_another_root() {
        let mut database = Database::open_in_memory().unwrap();
        database
            .create_question("question-a", "question-a-v1", "問いA", 100)
            .unwrap();
        database
            .create_question("question-b", "question-b-v1", "問いB", 100)
            .unwrap();

        assert!(
            database
                .connection
                .execute(
                    "INSERT INTO question_versions
                 (id, question_id, version_no, body, previous_version_id, created_at)
                 VALUES ('question-a-v2', 'question-a', 2, '問いAの改訂', 'question-b-v1', 200)",
                    []
                )
                .is_err()
        );
    }

    #[test]
    fn invalid_new_version_rolls_back_without_changing_the_current_pointer() {
        let mut database = Database::open_in_memory().unwrap();
        database
            .create_question("question-a", "question-a-v1", "問いA", 100)
            .unwrap();

        assert!(
            database
                .append_question_version("question-a", "question-a-v2", "   ", 200)
                .is_err()
        );

        assert_eq!(
            database.current_question_version("question-a").unwrap(),
            "question-a-v1"
        );
        assert_eq!(database.question_version_count("question-a").unwrap(), 1);
    }

    #[test]
    fn direct_sql_cannot_mutate_an_immutable_version_payload() {
        let mut database = Database::open_in_memory().unwrap();
        database
            .create_question("question-a", "question-a-v1", "問いA", 100)
            .unwrap();

        assert!(
            database
                .connection
                .execute(
                    "UPDATE question_versions SET body = '書き換え' WHERE id = 'question-a-v1'",
                    []
                )
                .is_err()
        );
        assert_eq!(database.question_body("question-a-v1").unwrap(), "問いA");
    }

    #[test]
    fn direct_sql_cannot_mutate_an_immutable_transformation_event() {
        let database = Database::open_in_memory().unwrap();
        database
            .connection
            .execute(
                "INSERT INTO transformations
                 (id, transformation_type, reason, executed_by, method, created_at)
                 VALUES ('transformation-a', 'MANUAL_CODING', '初回の判断', 'USER', 'MANUAL', 100)",
                [],
            )
            .unwrap();

        assert!(
            database
                .connection
                .execute(
                    "UPDATE transformations SET reason = '書き換え' WHERE id = 'transformation-a'",
                    [],
                )
                .is_err()
        );
    }

    #[test]
    fn resource_reference_cannot_target_a_nonexistent_fragment() {
        let mut database = Database::open_in_memory().unwrap();

        assert!(
            database
                .register_fragment_resource_ref("resource-a", "fragment-that-does-not-exist", 100)
                .is_err()
        );
    }
}
