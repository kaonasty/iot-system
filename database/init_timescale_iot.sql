-- ============================================================================
-- TimescaleDB Database Initialization Script
-- Purpose: High-Frequency Time-Series Sensor Data
-- ============================================================================
-- This database handles time-series data with automatic partitioning
-- Use Case: Sensor readings, continuous aggregates, data retention
-- ============================================================================

-- Drop existing database if exists (for clean setup)
DROP DATABASE IF EXISTS iot_timeseries;

CREATE DATABASE iot_timeseries;

-- Connect to the database
\c iot_timeseries;

-- ============================================================================
-- EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ============================================================================
-- TABLE: sensor_readings (Will be converted to hypertable)
-- Purpose: Main table for all sensor readings
-- ============================================================================
CREATE TABLE sensor_readings (
    time TIMESTAMPTZ NOT NULL,
    device_id VARCHAR(50) NOT NULL,
    device_type VARCHAR(50) NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    unit VARCHAR(20),
    quality_score SMALLINT CHECK (
        quality_score >= 0
        AND quality_score <= 100
    ),
    is_anomaly BOOLEAN DEFAULT FALSE,
    metadata JSONB
);

-- Convert to hypertable (partitioned by time)
SELECT create_hypertable (
        'sensor_readings', 'time', chunk_time_interval = > INTERVAL '1 day'
    );

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Composite index for common queries (device + time range)
CREATE INDEX idx_sensor_readings_device_time ON sensor_readings (device_id, time DESC);

-- Index for device type queries
CREATE INDEX idx_sensor_readings_type_time ON sensor_readings (device_type, time DESC);

-- Index for anomaly detection queries
CREATE INDEX idx_sensor_readings_anomaly ON sensor_readings (is_anomaly, time DESC)
WHERE
    is_anomaly = TRUE;

-- JSONB index for metadata queries
CREATE INDEX idx_sensor_readings_metadata ON sensor_readings USING GIN (metadata);

-- ============================================================================
-- CONTINUOUS AGGREGATES
-- ============================================================================

-- 1-minute aggregates (for real-time dashboards)
CREATE MATERIALIZED VIEW sensor_readings_1min
WITH (timescaledb.continuous) AS
SELECT
    time_bucket ('1 minute', time) AS bucket,
    device_id,
    device_type,
    COUNT(*) AS reading_count,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    STDDEV(value) AS stddev_value,
    PERCENTILE_CONT (0.5) WITHIN GROUP (
        ORDER BY value
    ) AS median_value,
    SUM(
        CASE
            WHEN is_anomaly THEN 1
            ELSE 0
        END
    ) AS anomaly_count
FROM sensor_readings
GROUP BY
    bucket,
    device_id,
    device_type;

-- 1-hour aggregates (for hourly analysis)
CREATE MATERIALIZED VIEW sensor_readings_1h
WITH (timescaledb.continuous) AS
SELECT
    time_bucket ('1 hour', time) AS bucket,
    device_id,
    device_type,
    COUNT(*) AS reading_count,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    STDDEV(value) AS stddev_value,
    PERCENTILE_CONT (0.5) WITHIN GROUP (
        ORDER BY value
    ) AS median_value,
    PERCENTILE_CONT (0.95) WITHIN GROUP (
        ORDER BY value
    ) AS p95_value,
    PERCENTILE_CONT (0.99) WITHIN GROUP (
        ORDER BY value
    ) AS p99_value,
    SUM(
        CASE
            WHEN is_anomaly THEN 1
            ELSE 0
        END
    ) AS anomaly_count
FROM sensor_readings
GROUP BY
    bucket,
    device_id,
    device_type;

-- 1-day aggregates (for daily reports)
CREATE MATERIALIZED VIEW sensor_readings_1d
WITH (timescaledb.continuous) AS
SELECT
    time_bucket ('1 day', time) AS bucket,
    device_id,
    device_type,
    COUNT(*) AS reading_count,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    STDDEV(value) AS stddev_value,
    PERCENTILE_CONT (0.5) WITHIN GROUP (
        ORDER BY value
    ) AS median_value,
    PERCENTILE_CONT (0.95) WITHIN GROUP (
        ORDER BY value
    ) AS p95_value,
    PERCENTILE_CONT (0.99) WITHIN GROUP (
        ORDER BY value
    ) AS p99_value,
    SUM(
        CASE
            WHEN is_anomaly THEN 1
            ELSE 0
        END
    ) AS anomaly_count
FROM sensor_readings
GROUP BY
    bucket,
    device_id,
    device_type;

-- ============================================================================
-- REFRESH POLICIES FOR CONTINUOUS AGGREGATES
-- ============================================================================

-- Refresh 1-minute aggregates every minute
SELECT
    add_continuous_aggregate_policy (
        'sensor_readings_1min',
        start_offset = > INTERVAL '1 hour',
        end_offset = > INTERVAL '1 minute',
        schedule_interval = > INTERVAL '1 minute'
    );

-- Refresh 1-hour aggregates every hour
SELECT
    add_continuous_aggregate_policy (
        'sensor_readings_1h',
        start_offset = > INTERVAL '1 day',
        end_offset = > INTERVAL '1 hour',
        schedule_interval = > INTERVAL '1 hour'
    );

-- Refresh 1-day aggregates every day
SELECT
    add_continuous_aggregate_policy (
        'sensor_readings_1d',
        start_offset = > INTERVAL '7 days',
        end_offset = > INTERVAL '1 day',
        schedule_interval = > INTERVAL '1 day'
    );

-- ============================================================================
-- COMPRESSION POLICIES
-- ============================================================================

-- Enable compression on sensor_readings hypertable
ALTER TABLE sensor_readings SET(
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id, device_type',
    timescaledb.compress_orderby = 'time DESC'
);

-- Compress chunks older than 7 days
SELECT add_compression_policy ( 'sensor_readings', INTERVAL '7 days' );

-- ============================================================================
-- RETENTION POLICIES
-- ============================================================================

-- Drop raw data older than 90 days (keep aggregates)
SELECT add_retention_policy ( 'sensor_readings', INTERVAL '90 days' );

-- ============================================================================
-- ADDITIONAL TABLES
-- ============================================================================

-- Table for device status changes (separate from readings)
CREATE TABLE device_status_events (
    time TIMESTAMPTZ NOT NULL,
    device_id VARCHAR(50) NOT NULL,
    old_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    reason TEXT,
    changed_by VARCHAR(50)
);

SELECT create_hypertable (
        'device_status_events', 'time', chunk_time_interval = > INTERVAL '7 days'
    );

CREATE INDEX idx_device_status_device_time ON device_status_events (device_id, time DESC);

-- Table for alert events
CREATE TABLE alert_events (
    time TIMESTAMPTZ NOT NULL,
    device_id VARCHAR(50) NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    threshold_value DOUBLE PRECISION,
    actual_value DOUBLE PRECISION,
    message TEXT,
    is_acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by VARCHAR(50),
    acknowledged_at TIMESTAMPTZ
);

SELECT create_hypertable (
        'alert_events', 'time', chunk_time_interval = > INTERVAL '7 days'
    );

CREATE INDEX idx_alert_events_device_time ON alert_events (device_id, time DESC);

CREATE INDEX idx_alert_events_severity ON alert_events (severity, time DESC);

CREATE INDEX idx_alert_events_unacknowledged ON alert_events (is_acknowledged, time DESC)
WHERE
    is_acknowledged = FALSE;

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Latest reading for each device
CREATE VIEW v_latest_readings AS
SELECT DISTINCT
    ON (device_id) device_id,
    device_type,
    time,
    value,
    unit,
    quality_score,
    is_anomaly
FROM sensor_readings
ORDER BY device_id, time DESC;

-- Recent anomalies (last 24 hours)
CREATE VIEW v_recent_anomalies AS
SELECT
    time,
    device_id,
    device_type,
    value,
    unit
FROM sensor_readings
WHERE
    is_anomaly = TRUE
    AND time > NOW() - INTERVAL '24 hours'
ORDER BY time DESC;

-- Device health summary (last hour)
CREATE VIEW v_device_health_summary AS
SELECT
    device_id,
    device_type,
    COUNT(*) AS reading_count,
    AVG(quality_score) AS avg_quality_score,
    MAX(time) AS last_reading_time,
    NOW() - MAX(time) AS time_since_last_reading,
    SUM(
        CASE
            WHEN is_anomaly THEN 1
            ELSE 0
        END
    ) AS anomaly_count
FROM sensor_readings
WHERE
    time > NOW() - INTERVAL '1 hour'
GROUP BY
    device_id,
    device_type;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to get device statistics for a time range
CREATE OR REPLACE FUNCTION get_device_statistics(
    p_device_id VARCHAR,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ
)
RETURNS TABLE (
    total_readings BIGINT,
    avg_value DOUBLE PRECISION,
    min_value DOUBLE PRECISION,
    max_value DOUBLE PRECISION,
    stddev_value DOUBLE PRECISION,
    anomaly_count BIGINT,
    avg_quality_score DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT AS total_readings,
        AVG(sr.value) AS avg_value,
        MIN(sr.value) AS min_value,
        MAX(sr.value) AS max_value,
        STDDEV(sr.value) AS stddev_value,
        SUM(CASE WHEN sr.is_anomaly THEN 1 ELSE 0 END)::BIGINT AS anomaly_count,
        AVG(sr.quality_score) AS avg_quality_score
    FROM sensor_readings sr
    WHERE sr.device_id = p_device_id
        AND sr.time >= p_start_time
        AND sr.time <= p_end_time;
END;
$$ LANGUAGE plpgsql;

-- Function to detect missing data gaps
CREATE OR REPLACE FUNCTION detect_data_gaps(
    p_device_id VARCHAR,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_expected_interval INTERVAL
)
RETURNS TABLE (
    gap_start TIMESTAMPTZ,
    gap_end TIMESTAMPTZ,
    gap_duration INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    WITH readings_with_next AS (
        SELECT 
            time,
            LEAD(time) OVER (ORDER BY time) AS next_time
        FROM sensor_readings
        WHERE device_id = p_device_id
            AND time >= p_start_time
            AND time <= p_end_time
    )
    SELECT 
        time AS gap_start,
        next_time AS gap_end,
        next_time - time AS gap_duration
    FROM readings_with_next
    WHERE next_time - time > p_expected_interval * 2
    ORDER BY time;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SAMPLE DATA INSERTION
-- ============================================================================

-- Insert sample sensor readings (last 7 days)
INSERT INTO sensor_readings (time, device_id, device_type, value, unit, quality_score, is_anomaly)
SELECT 
    NOW() - (random() * INTERVAL '7 days'),
    device_id,
    device_type,
    base_value + (random() * 10 - 5),  -- Random variation
    unit,
    90 + (random() * 10)::INT,  -- Quality score 90-100
    random() < 0.02  -- 2% anomaly rate
FROM (
    VALUES 
        ('TEMP-001', 'temperature', 22.0, '°C'),
        ('TEMP-002', 'temperature', 20.0, '°C'),
        ('HUM-001', 'humidity', 50.0, '%'),
        ('MOT-001', 'motion', 0.0, 'boolean'),
        ('ENR-001', 'energy', 100.0, 'kWh')
) AS devices(device_id, device_type, base_value, unit),
generate_series(1, 1000);
-- 1000 readings per device

-- Insert sample device status events
INSERT INTO
    device_status_events (
        time,
        device_id,
        old_status,
        new_status,
        reason,
        changed_by
    )
VALUES (
        NOW() - INTERVAL '5 days',
        'TEMP-001',
        'inactive',
        'active',
        'Device installation completed',
        'admin'
    ),
    (
        NOW() - INTERVAL '3 days',
        'TEMP-002',
        'maintenance',
        'active',
        'Maintenance completed',
        'john_manager'
    ),
    (
        NOW() - INTERVAL '1 day',
        'MOT-001',
        'active',
        'maintenance',
        'Scheduled maintenance',
        'jane_operator'
    );

-- Insert sample alert events
INSERT INTO
    alert_events (
        time,
        device_id,
        alert_type,
        severity,
        threshold_value,
        actual_value,
        message
    )
VALUES (
        NOW() - INTERVAL '2 hours',
        'TEMP-001',
        'threshold_high',
        'warning',
        30.0,
        32.5,
        'Temperature exceeded warning threshold'
    ),
    (
        NOW() - INTERVAL '1 hour',
        'TEMP-002',
        'threshold_high',
        'critical',
        40.0,
        42.0,
        'Temperature exceeded critical threshold'
    ),
    (
        NOW() - INTERVAL '30 minutes',
        'HUM-001',
        'threshold_low',
        'warning',
        30.0,
        28.0,
        'Humidity below warning threshold'
    );

-- ============================================================================
-- USEFUL QUERIES FOR DEMONSTRATION
-- ============================================================================

-- Query 1: Get latest reading for each device
-- SELECT * FROM v_latest_readings;

-- Query 2: Get hourly averages for a device
-- SELECT bucket, avg_value, min_value, max_value
-- FROM sensor_readings_1h
-- WHERE device_id = 'TEMP-001'
-- ORDER BY bucket DESC
-- LIMIT 24;

-- Query 3: Detect anomalies in the last 24 hours
-- SELECT * FROM v_recent_anomalies;

-- Query 4: Get device health summary
-- SELECT * FROM v_device_health_summary;

-- Query 5: Time-weighted average (more recent readings weighted higher)
-- SELECT
--     device_id,
--     SUM(value * EXTRACT(EPOCH FROM (NOW() - time))) / SUM(EXTRACT(EPOCH FROM (NOW() - time))) AS weighted_avg
-- FROM sensor_readings
-- WHERE time > NOW() - INTERVAL '1 hour'
-- GROUP BY device_id;

-- Query 6: Detect data gaps
-- SELECT * FROM detect_data_gaps('TEMP-001', NOW() - INTERVAL '7 days', NOW(), INTERVAL '1 minute');

-- Query 7: Get compression statistics
-- SELECT
--     chunk_name,
--     pg_size_pretty(before_compression_total_bytes) AS before_compression,
--     pg_size_pretty(after_compression_total_bytes) AS after_compression,
--     ROUND(100 - (after_compression_total_bytes::NUMERIC / before_compression_total_bytes::NUMERIC * 100), 2) AS compression_ratio_pct
-- FROM timescaledb_information.compressed_chunk_stats
-- ORDER BY chunk_name;

-- ============================================================================
-- PERFORMANCE TIPS
-- ============================================================================
-- 1. Use time_bucket() for time-based aggregations
-- 2. Query continuous aggregates instead of raw data when possible
-- 3. Use EXPLAIN ANALYZE to check query plans
-- 4. Adjust chunk_time_interval based on data volume
-- 5. Use compression for older data to save space
-- 6. Set appropriate retention policies to manage data lifecycle

-- ============================================================================
-- END OF TIMESCALEDB INITIALIZATION SCRIPT
-- ============================================================================