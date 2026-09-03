-- Sovalune Storage Schema - Initial Migration
-- Extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Projects table
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    settings JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Sessions table
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Message roles enum
CREATE TYPE message_role AS ENUM ('user', 'assistant', 'tool', 'system');

-- Messages table
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    role message_role NOT NULL,
    content TEXT NOT NULL,
    tool_call JSONB,
    request_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Memory tiers enum
CREATE TYPE memory_tier AS ENUM ('raw', 'consolidated', 'verified');

-- Memory entries table (will be used in Stage 2-3)
CREATE TABLE memory_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id),
    tier memory_tier NOT NULL DEFAULT 'raw',
    content TEXT NOT NULL,
    embedding VECTOR(768),
    metadata JSONB NOT NULL DEFAULT '{}',
    confidence_score REAL NOT NULL DEFAULT 0.5,
    decay_score REAL NOT NULL DEFAULT 1.0,
    archived BOOLEAN NOT NULL DEFAULT false,
    source_entry_ids UUID[] DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Learning cycle statuses enum
CREATE TYPE learning_cycle_status AS ENUM (
    'detected', 'researching', 'verifying',
    'practicing', 'testing', 'applying',
    'completed', 'failed'
);

-- Learning cycles table (will be used in Stage 3)
CREATE TABLE learning_cycles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id),
    status learning_cycle_status NOT NULL DEFAULT 'detected',
    origin_task_id UUID NOT NULL,
    failure_reason TEXT,
    retry_count INT NOT NULL DEFAULT 0,
    confidence_score REAL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Learning cycle evidence table
CREATE TABLE learning_cycle_evidence (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cycle_id UUID NOT NULL REFERENCES learning_cycles(id) ON DELETE CASCADE,
    source_type TEXT NOT NULL,
    source_url TEXT,
    excerpt TEXT NOT NULL,
    trust_tier INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Learning cycle test results table
CREATE TABLE learning_cycle_test_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cycle_id UUID NOT NULL REFERENCES learning_cycles(id) ON DELETE CASCADE,
    stage TEXT NOT NULL,
    passed BOOLEAN NOT NULL,
    detail JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Training artifacts table
CREATE TABLE training_artifacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cycle_id UUID REFERENCES learning_cycles(id),
    version INT NOT NULL,
    artifact_uri TEXT NOT NULL,
    metrics JSONB NOT NULL DEFAULT '{}',
    promoted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX memory_entries_embedding_idx
    ON memory_entries USING hnsw (embedding vector_cosine_ops);

CREATE INDEX memory_entries_project_tier_idx
    ON memory_entries (project_id, tier) WHERE NOT archived;

CREATE INDEX sessions_project_id_idx ON sessions(project_id);
CREATE INDEX messages_session_id_idx ON messages(session_id);
CREATE INDEX learning_cycles_project_id_idx ON learning_cycles(project_id);
CREATE INDEX learning_cycle_evidence_cycle_id_idx ON learning_cycle_evidence(cycle_id);
CREATE INDEX learning_cycle_test_results_cycle_id_idx ON learning_cycle_test_results(cycle_id);
CREATE INDEX training_artifacts_cycle_id_idx ON training_artifacts(cycle_id);

-- Enable Row Level Security (Supabase feature)
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_cycle_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_cycle_test_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_artifacts ENABLE ROW LEVEL SECURITY;

-- Basic policies (can be customized later)
CREATE POLICY "Allow all for anon" ON projects FOR ALL USING (true);
CREATE POLICY "Allow all for anon" ON sessions FOR ALL USING (true);
CREATE POLICY "Allow all for anon" ON messages FOR ALL USING (true);
CREATE POLICY "Allow all for anon" ON memory_entries FOR ALL USING (true);
CREATE POLICY "Allow all for anon" ON learning_cycles FOR ALL USING (true);
CREATE POLICY "Allow all for anon" ON learning_cycle_evidence FOR ALL USING (true);
CREATE POLICY "Allow all for anon" ON learning_cycle_test_results FOR ALL USING (true);
CREATE POLICY "Allow all for anon" ON training_artifacts FOR ALL USING (true);
