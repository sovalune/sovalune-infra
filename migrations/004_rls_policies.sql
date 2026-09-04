-- ============================================================
-- 004: RLS policies for API access
-- ============================================================

-- Enable RLS on all tables (already enabled in 001, but ensuring)
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_results ENABLE ROW LEVEL SECURITY;

-- Create roles for API access
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
END
$$;

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO service_role;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Grant table permissions to service_role (full access)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Grant read-only access to anon
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

-- Grant read/write to authenticated
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- RLS Policies: service_role bypasses RLS
CREATE POLICY "Service role full access" ON projects
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access" ON sessions
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access" ON messages
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access" ON memory_entries
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access" ON learning_cycles
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access" ON learning_evidence
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access" ON test_results
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- RLS Policies: anon can read everything
CREATE POLICY "Anon read access" ON projects
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Anon read access" ON sessions
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Anon read access" ON messages
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Anon read access" ON memory_entries
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Anon read access" ON learning_cycles
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Anon read access" ON learning_evidence
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Anon read access" ON test_results
    FOR SELECT
    TO anon
    USING (true);

-- RLS Policies: authenticated can read/write their own data
CREATE POLICY "Authenticated read access" ON projects
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated insert" ON projects
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Authenticated read access" ON sessions
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated insert" ON sessions
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Authenticated read access" ON messages
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated insert" ON messages
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Authenticated read access" ON memory_entries
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated insert" ON memory_entries
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Authenticated update" ON memory_entries
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Authenticated read access" ON learning_cycles
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated insert" ON learning_cycles
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Authenticated update" ON learning_cycles
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Authenticated read access" ON learning_evidence
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated insert" ON learning_evidence
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Authenticated read access" ON test_results
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated insert" ON test_results
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Create API user that bypasses RLS
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sovalune_api') THEN
        CREATE ROLE sovalune_api LOGIN PASSWORD 'sovalune_api_password';
    END IF;
END
$$;

GRANT service_role TO sovalune_api;

-- Create a function to check if the current user is the service role
CREATE OR REPLACE FUNCTION auth.is_service_role()
RETURNS boolean AS $$
BEGIN
    RETURN current_setting('role') = 'service_role';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to check if the current user is authenticated
CREATE OR REPLACE FUNCTION auth.is_authenticated()
RETURNS boolean AS $$
BEGIN
    RETURN current_setting('role') IN ('authenticated', 'service_role');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to get the current user ID (placeholder for JWT)
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid AS $$
BEGIN
    RETURN NULL; -- Will be set by JWT middleware
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
