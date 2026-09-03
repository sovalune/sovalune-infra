-- Sovalune Vector Search Optimization and Triggers

-- Create a more efficient HNSW index for vector search
CREATE INDEX IF NOT EXISTS memory_entries_embedding_hnsw_idx
    ON memory_entries USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Create a GIN index for metadata searches
CREATE INDEX IF NOT EXISTS memory_entries_metadata_idx
    ON memory_entries USING gin (metadata);

-- Create a trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to memory_entries
CREATE TRIGGER update_memory_entries_updated_at
    BEFORE UPDATE ON memory_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to learning_cycles
CREATE TRIGGER update_learning_cycles_updated_at
    BEFORE UPDATE ON learning_cycles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create a view for memory statistics
CREATE OR REPLACE VIEW memory_stats AS
SELECT 
    project_id,
    tier,
    COUNT(*) as count,
    AVG(confidence_score) as avg_confidence,
    AVG(decay_score) as avg_decay,
    SUM(CASE WHEN archived THEN 1 ELSE 0 END) as archived_count
FROM memory_entries
GROUP BY project_id, tier;

-- Create a view for learning cycle statistics
CREATE OR REPLACE VIEW learning_cycle_stats AS
SELECT 
    project_id,
    status,
    COUNT(*) as count,
    AVG(retry_count) as avg_retries,
    AVG(confidence_score) as avg_confidence
FROM learning_cycles
GROUP BY project_id, status;

-- Create a function to get memory context for a project
CREATE OR REPLACE FUNCTION get_memory_context(
    p_project_id UUID,
    p_query_embedding VECTOR(768),
    p_max_tokens INT DEFAULT 4000
)
RETURNS TABLE (
    tier memory_tier,
    content TEXT,
    confidence REAL,
    token_estimate INT
) AS $$
DECLARE
    v_tokens_used INT := 0;
    v_max_tokens INT := p_max_tokens;
BEGIN
    -- First return verified memories (highest priority)
    FOR tier, content, confidence, token_estimate IN
        SELECT 
            me.tier,
            me.content,
            me.confidence_score,
            CEIL(LENGTH(me.content) / 4.0)::INT  -- rough token estimate
        FROM memory_entries me
        WHERE me.project_id = p_project_id
            AND me.tier = 'verified'
            AND NOT me.archived
            AND me.confidence_score >= 0.7
        ORDER BY 
            CASE WHEN me.embedding IS NOT NULL 
                THEN 1 - (me.embedding <=> p_query_embedding)
                ELSE me.confidence_score
            END DESC
        LIMIT 20
    LOOP
        IF v_tokens_used + token_estimate <= v_max_tokens THEN
            v_tokens_used := v_tokens_used + token_estimate;
            RETURN NEXT;
        ELSE
            EXIT;
        END IF;
    END LOOP;
    
    -- Then return consolidated memories
    FOR tier, content, confidence, token_estimate IN
        SELECT 
            me.tier,
            me.content,
            me.confidence_score,
            CEIL(LENGTH(me.content) / 4.0)::INT
        FROM memory_entries me
        WHERE me.project_id = p_project_id
            AND me.tier = 'consolidated'
            AND NOT me.archived
            AND me.confidence_score >= 0.5
        ORDER BY 
            CASE WHEN me.embedding IS NOT NULL 
                THEN 1 - (me.embedding <=> p_query_embedding)
                ELSE me.confidence_score
            END DESC
        LIMIT 30
    LOOP
        IF v_tokens_used + token_estimate <= v_max_tokens THEN
            v_tokens_used := v_tokens_used + token_estimate;
            RETURN NEXT;
        ELSE
            EXIT;
        END IF;
    END LOOP;
    
    -- Finally return raw memories if there's still space
    FOR tier, content, confidence, token_estimate IN
        SELECT 
            me.tier,
            me.content,
            me.confidence_score,
            CEIL(LENGTH(me.content) / 4.0)::INT
        FROM memory_entries me
        WHERE me.project_id = p_project_id
            AND me.tier = 'raw'
            AND NOT me.archived
        ORDER BY 
            CASE WHEN me.embedding IS NOT NULL 
                THEN 1 - (me.embedding <=> p_query_embedding)
                ELSE me.confidence_score
            END DESC
        LIMIT 50
    LOOP
        IF v_tokens_used + token_estimate <= v_max_tokens THEN
            v_tokens_used := v_tokens_used + token_estimate;
            RETURN NEXT;
        ELSE
            EXIT;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
