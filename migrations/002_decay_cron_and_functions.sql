-- Sovalune Decay Tick Cron Job
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a function to run decay tick
CREATE OR REPLACE FUNCTION run_decay_tick()
RETURNS void AS $$
BEGIN
    -- Update decay_score for all non-archived memory entries
    -- Decay is based on time since last access and confidence
    UPDATE memory_entries
    SET 
        decay_score = GREATEST(0.1, decay_score * 0.995),
        updated_at = now()
    WHERE NOT archived
        AND decay_score > 0.1;
    
    -- Archive entries with very low decay score
    UPDATE memory_entries
    SET archived = true
    WHERE NOT archived
        AND decay_score <= 0.1
        AND tier = 'raw';
    
    -- Log the decay tick
    RAISE NOTICE 'Decay tick completed at %', now();
END;
$$ LANGUAGE plpgsql;

-- Schedule the decay tick to run every hour
SELECT cron.schedule(
    'decay-tick-hourly',
    '0 * * * *',  -- Every hour
    $$SELECT run_decay_tick()$$
);

-- Create a function to consolidate memory entries
CREATE OR REPLACE FUNCTION consolidate_memory(
    p_project_id UUID,
    p_source_ids UUID[],
    p_content TEXT,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    v_new_id UUID;
BEGIN
    -- Create new consolidated entry
    INSERT INTO memory_entries (project_id, tier, content, metadata, confidence_score, source_entry_ids)
    VALUES (p_project_id, 'consolidated', p_content, p_metadata, 0.7, p_source_ids)
    RETURNING id INTO v_new_id;
    
    -- Archive source entries
    UPDATE memory_entries
    SET archived = true
    WHERE id = ANY(p_source_ids);
    
    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- Create a function to promote memory to verified
CREATE OR REPLACE FUNCTION promote_to_verified(
    p_memory_id UUID,
    p_confidence_boost REAL DEFAULT 0.1
)
RETURNS void AS $$
BEGIN
    UPDATE memory_entries
    SET 
        tier = 'verified',
        confidence_score = LEAST(1.0, confidence_score + p_confidence_boost),
        updated_at = now()
    WHERE id = p_memory_id;
END;
$$ LANGUAGE plpgsql;

-- Create a function to search memory by embedding
CREATE OR REPLACE FUNCTION search_memory(
    p_project_id UUID,
    p_query_embedding VECTOR(768),
    p_limit INT DEFAULT 10,
    p_min_score REAL DEFAULT 0.5
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    tier memory_tier,
    confidence_score REAL,
    decay_score REAL,
    score REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        me.id,
        me.content,
        me.tier,
        me.confidence_score,
        me.decay_score,
        1 - (me.embedding <=> p_query_embedding) AS score
    FROM memory_entries me
    WHERE me.project_id = p_project_id
        AND me.embedding IS NOT NULL
        AND me.confidence_score >= p_min_score
        AND NOT me.archived
    ORDER BY me.embedding <=> p_query_embedding
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;
