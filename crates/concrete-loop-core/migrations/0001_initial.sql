-- Concrete Loop's initial Desktop schema.
-- Semantic payload is stored in immutable version/event rows. Root rows retain
-- only identity, lifecycle metadata, and the pointer to their current version.

CREATE TABLE external_sources (
    id TEXT PRIMARY KEY,
    provider TEXT NOT NULL,
    external_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    UNIQUE (provider, external_id)
);

CREATE TABLE external_artifacts (
    id TEXT PRIMARY KEY,
    external_source_id TEXT NOT NULL REFERENCES external_sources(id),
    external_id TEXT NOT NULL,
    artifact_type TEXT NOT NULL,
    lifecycle TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (lifecycle IN ('ACTIVE', 'TRASHED')),
    external_state TEXT NOT NULL DEFAULT 'AVAILABLE' CHECK (external_state IN ('AVAILABLE', 'NOT_OBSERVED', 'ACCESS_LOST', 'OUT_OF_SCOPE', 'DELETION_CONFIRMED')),
    current_version_id TEXT,
    created_at INTEGER NOT NULL,
    UNIQUE (external_source_id, external_id),
    FOREIGN KEY (current_version_id, id) REFERENCES external_artifact_versions(id, external_artifact_id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE external_artifact_versions (
    id TEXT PRIMARY KEY,
    external_artifact_id TEXT NOT NULL REFERENCES external_artifacts(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL CHECK (version_no > 0),
    content TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    external_updated_at INTEGER,
    previous_version_id TEXT REFERENCES external_artifact_versions(id),
    created_at INTEGER NOT NULL,
    UNIQUE (external_artifact_id, version_no),
    UNIQUE (id, external_artifact_id)
);

CREATE TABLE questions (
    id TEXT PRIMARY KEY,
    lifecycle TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (lifecycle IN ('ACTIVE', 'TRASHED')),
    current_version_id TEXT,
    created_at INTEGER NOT NULL,
    trashed_at INTEGER,
    FOREIGN KEY (current_version_id, id) REFERENCES question_versions(id, question_id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE question_versions (
    id TEXT PRIMARY KEY,
    question_id TEXT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL CHECK (version_no > 0),
    body TEXT NOT NULL CHECK (length(trim(body)) > 0),
    previous_version_id TEXT REFERENCES question_versions(id),
    created_at INTEGER NOT NULL,
    change_reason TEXT,
    UNIQUE (question_id, version_no),
    UNIQUE (id, question_id)
);

CREATE TRIGGER question_versions_are_immutable
BEFORE UPDATE ON question_versions
BEGIN
    SELECT RAISE(ABORT, 'question_versions are immutable');
END;

CREATE TABLE code_definitions (
    id TEXT PRIMARY KEY,
    lifecycle TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (lifecycle IN ('ACTIVE', 'TRASHED')),
    current_version_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (current_version_id, id) REFERENCES code_definition_versions(id, code_definition_id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE code_definition_versions (
    id TEXT PRIMARY KEY,
    code_definition_id TEXT NOT NULL REFERENCES code_definitions(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL CHECK (version_no > 0),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    definition TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    previous_version_id TEXT REFERENCES code_definition_versions(id),
    UNIQUE (code_definition_id, version_no),
    UNIQUE (id, code_definition_id)
);

CREATE TRIGGER code_definition_versions_are_immutable
BEFORE UPDATE ON code_definition_versions
BEGIN
    SELECT RAISE(ABORT, 'code_definition_versions are immutable');
END;

CREATE TABLE variable_definitions (
    id TEXT PRIMARY KEY,
    lifecycle TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (lifecycle IN ('ACTIVE', 'TRASHED')),
    current_version_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (current_version_id, id) REFERENCES variable_definition_versions(id, variable_definition_id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE variable_definition_versions (
    id TEXT PRIMARY KEY,
    variable_definition_id TEXT NOT NULL REFERENCES variable_definitions(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL CHECK (version_no > 0),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    operational_definition TEXT NOT NULL,
    scale_definition TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    previous_version_id TEXT REFERENCES variable_definition_versions(id),
    UNIQUE (variable_definition_id, version_no),
    UNIQUE (id, variable_definition_id)
);

CREATE TRIGGER variable_definition_versions_are_immutable
BEFORE UPDATE ON variable_definition_versions
BEGIN
    SELECT RAISE(ABORT, 'variable_definition_versions are immutable');
END;

CREATE TABLE fragments (
    id TEXT PRIMARY KEY,
    external_artifact_version_id TEXT NOT NULL REFERENCES external_artifact_versions(id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
    body TEXT NOT NULL CHECK (length(trim(body)) > 0),
    created_at INTEGER NOT NULL,
    UNIQUE (external_artifact_version_id, ordinal)
);

CREATE TABLE code_assignments (
    id TEXT PRIMARY KEY,
    fragment_id TEXT NOT NULL REFERENCES fragments(id) ON DELETE CASCADE,
    code_definition_version_id TEXT NOT NULL REFERENCES code_definition_versions(id),
    origin_type TEXT NOT NULL CHECK (origin_type IN ('USER', 'AI_PROPOSAL', 'IMPORT')),
    created_at INTEGER NOT NULL,
    UNIQUE (fragment_id, code_definition_version_id)
);

CREATE TABLE measurements (
    id TEXT PRIMARY KEY,
    variable_definition_version_id TEXT NOT NULL REFERENCES variable_definition_versions(id),
    value REAL NOT NULL,
    source_type TEXT NOT NULL CHECK (source_type IN ('DIRECT_USER_INPUT', 'DERIVED')),
    source_id TEXT,
    measured_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE resource_refs (
    id TEXT PRIMARY KEY,
    resource_type TEXT NOT NULL,
    resource_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    UNIQUE (resource_type, resource_id)
);

CREATE TABLE transformations (
    id TEXT PRIMARY KEY,
    transformation_type TEXT NOT NULL,
    reason TEXT NOT NULL,
    gain TEXT,
    loss TEXT,
    assumption_text TEXT,
    executed_by TEXT NOT NULL,
    method TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE transformation_inputs (
    transformation_id TEXT NOT NULL REFERENCES transformations(id) ON DELETE CASCADE,
    resource_ref_id TEXT NOT NULL REFERENCES resource_refs(id),
    PRIMARY KEY (transformation_id, resource_ref_id)
);

CREATE TABLE transformation_outputs (
    transformation_id TEXT NOT NULL REFERENCES transformations(id) ON DELETE CASCADE,
    resource_ref_id TEXT NOT NULL REFERENCES resource_refs(id),
    PRIMARY KEY (transformation_id, resource_ref_id)
);

CREATE TABLE dataset_snapshots (
    id TEXT PRIMARY KEY,
    canonical_hash TEXT NOT NULL UNIQUE,
    filter_definition TEXT NOT NULL,
    column_definition TEXT NOT NULL,
    transformation_definition TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE dataset_snapshot_members (
    dataset_snapshot_id TEXT NOT NULL REFERENCES dataset_snapshots(id) ON DELETE CASCADE,
    resource_ref_id TEXT NOT NULL REFERENCES resource_refs(id),
    ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
    PRIMARY KEY (dataset_snapshot_id, resource_ref_id),
    UNIQUE (dataset_snapshot_id, ordinal)
);

CREATE TABLE analysis_plans (
    id TEXT PRIMARY KEY,
    lifecycle TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (lifecycle IN ('ACTIVE', 'TRASHED')),
    current_version_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (current_version_id, id) REFERENCES analysis_plan_versions(id, analysis_plan_id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE analysis_plan_versions (
    id TEXT PRIMARY KEY,
    analysis_plan_id TEXT NOT NULL REFERENCES analysis_plans(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL CHECK (version_no > 0),
    question_version_id TEXT NOT NULL REFERENCES question_versions(id),
    method TEXT NOT NULL,
    parameters_json TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    previous_version_id TEXT REFERENCES analysis_plan_versions(id),
    UNIQUE (analysis_plan_id, version_no),
    UNIQUE (id, analysis_plan_id)
);

CREATE TRIGGER analysis_plan_versions_are_immutable
BEFORE UPDATE ON analysis_plan_versions
BEGIN
    SELECT RAISE(ABORT, 'analysis_plan_versions are immutable');
END;

CREATE TABLE analysis_runs (
    id TEXT PRIMARY KEY,
    analysis_plan_version_id TEXT NOT NULL REFERENCES analysis_plan_versions(id),
    dataset_snapshot_id TEXT NOT NULL REFERENCES dataset_snapshots(id),
    code_artifact_version TEXT NOT NULL,
    environment_version TEXT NOT NULL,
    parameters_json TEXT NOT NULL,
    process_state TEXT NOT NULL CHECK (process_state IN ('PENDING', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
    created_at INTEGER NOT NULL,
    completed_at INTEGER
);

CREATE TABLE analysis_results (
    id TEXT PRIMARY KEY,
    analysis_run_id TEXT NOT NULL REFERENCES analysis_runs(id) ON DELETE CASCADE,
    result_kind TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE evidence_links (
    id TEXT PRIMARY KEY,
    subject_resource_ref_id TEXT NOT NULL REFERENCES resource_refs(id),
    object_resource_ref_id TEXT NOT NULL REFERENCES resource_refs(id),
    relationship TEXT NOT NULL CHECK (relationship IN ('SUPPORTS', 'CONTRADICTS', 'SOURCE', 'CONTEXT')),
    created_at INTEGER NOT NULL,
    UNIQUE (subject_resource_ref_id, object_resource_ref_id, relationship)
);

CREATE TABLE insights (
    id TEXT PRIMARY KEY,
    lifecycle TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (lifecycle IN ('ACTIVE', 'ARCHIVED', 'TRASHED')),
    current_version_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (current_version_id, id) REFERENCES insight_versions(id, insight_id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE insight_versions (
    id TEXT PRIMARY KEY,
    insight_id TEXT NOT NULL REFERENCES insights(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL CHECK (version_no > 0),
    body TEXT NOT NULL,
    uncertainty TEXT NOT NULL,
    origin_type TEXT NOT NULL,
    previous_version_id TEXT REFERENCES insight_versions(id),
    created_at INTEGER NOT NULL,
    UNIQUE (insight_id, version_no),
    UNIQUE (id, insight_id)
);

CREATE TRIGGER insight_versions_are_immutable
BEFORE UPDATE ON insight_versions
BEGIN
    SELECT RAISE(ABORT, 'insight_versions are immutable');
END;

CREATE TABLE learning_notes (
    id TEXT PRIMARY KEY,
    lifecycle TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (lifecycle IN ('ACTIVE', 'TRASHED')),
    current_version_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (current_version_id, id) REFERENCES learning_note_versions(id, learning_note_id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE learning_note_versions (
    id TEXT PRIMARY KEY,
    learning_note_id TEXT NOT NULL REFERENCES learning_notes(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL CHECK (version_no > 0),
    body TEXT NOT NULL,
    origin_type TEXT NOT NULL,
    previous_version_id TEXT REFERENCES learning_note_versions(id),
    created_at INTEGER NOT NULL,
    UNIQUE (learning_note_id, version_no),
    UNIQUE (id, learning_note_id)
);

CREATE TRIGGER learning_note_versions_are_immutable
BEFORE UPDATE ON learning_note_versions
BEGIN
    SELECT RAISE(ABORT, 'learning_note_versions are immutable');
END;

CREATE TABLE import_batches (
    id TEXT PRIMARY KEY,
    external_source_id TEXT NOT NULL REFERENCES external_sources(id),
    process_state TEXT NOT NULL CHECK (process_state IN ('PENDING', 'RUNNING', 'SUCCEEDED', 'PARTIAL_SUCCESS', 'FAILED', 'CANCELLED')),
    started_at INTEGER NOT NULL,
    completed_at INTEGER
);

CREATE TABLE import_batch_items (
    id TEXT PRIMARY KEY,
    import_batch_id TEXT NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
    external_artifact_version_id TEXT REFERENCES external_artifact_versions(id),
    result_type TEXT NOT NULL CHECK (result_type IN ('CREATED', 'UPDATED', 'UNCHANGED', 'DELETION_DETECTED', 'FAILED')),
    error_code TEXT,
    created_at INTEGER NOT NULL
);

CREATE TABLE ai_requests (
    id TEXT PRIMARY KEY,
    provider TEXT NOT NULL,
    model_identifier TEXT NOT NULL,
    prompt_version TEXT NOT NULL,
    input_hmac TEXT,
    context_scope TEXT NOT NULL,
    consented_at INTEGER NOT NULL,
    requested_at INTEGER NOT NULL
);

CREATE TABLE ai_request_inputs (
    ai_request_id TEXT NOT NULL REFERENCES ai_requests(id) ON DELETE CASCADE,
    resource_ref_id TEXT NOT NULL REFERENCES resource_refs(id),
    PRIMARY KEY (ai_request_id, resource_ref_id)
);

CREATE TABLE ai_request_outcomes (
    id TEXT PRIMARY KEY,
    ai_request_id TEXT NOT NULL REFERENCES ai_requests(id) ON DELETE CASCADE,
    outcome TEXT NOT NULL CHECK (outcome IN ('SUCCEEDED', 'FAILED', 'CANCELLED', 'UNKNOWN')),
    occurred_at INTEGER NOT NULL,
    error_code TEXT
);

CREATE TABLE ai_proposals (
    id TEXT PRIMARY KEY,
    ai_request_outcome_id TEXT NOT NULL REFERENCES ai_request_outcomes(id),
    proposal_type TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE user_decisions (
    id TEXT PRIMARY KEY,
    ai_proposal_id TEXT NOT NULL REFERENCES ai_proposals(id),
    decision TEXT NOT NULL CHECK (decision IN ('ACCEPTED', 'REJECTED', 'MODIFIED_AND_ACCEPTED')),
    decided_at INTEGER NOT NULL
);

CREATE TRIGGER external_artifact_versions_are_immutable
BEFORE UPDATE ON external_artifact_versions
BEGIN
    SELECT RAISE(ABORT, 'external_artifact_versions are immutable');
END;

CREATE TRIGGER ai_requests_are_immutable
BEFORE UPDATE ON ai_requests
BEGIN
    SELECT RAISE(ABORT, 'ai_requests are immutable');
END;

CREATE TRIGGER ai_request_outcomes_are_immutable
BEFORE UPDATE ON ai_request_outcomes
BEGIN
    SELECT RAISE(ABORT, 'ai_request_outcomes are immutable');
END;

CREATE TRIGGER ai_proposals_are_immutable
BEFORE UPDATE ON ai_proposals
BEGIN
    SELECT RAISE(ABORT, 'ai_proposals are immutable');
END;

CREATE TRIGGER user_decisions_are_immutable
BEFORE UPDATE ON user_decisions
BEGIN
    SELECT RAISE(ABORT, 'user_decisions are immutable');
END;

CREATE INDEX idx_question_versions_question ON question_versions(question_id, version_no);
CREATE INDEX idx_external_artifact_versions_artifact ON external_artifact_versions(external_artifact_id, version_no);
CREATE INDEX idx_fragments_source_version ON fragments(external_artifact_version_id, ordinal);
CREATE INDEX idx_measurements_variable ON measurements(variable_definition_version_id, measured_at);
CREATE INDEX idx_analysis_runs_plan ON analysis_runs(analysis_plan_version_id, created_at);
CREATE INDEX idx_import_batch_items_batch ON import_batch_items(import_batch_id);
