-- ============================================================================
-- PostgreSQL Database Initialization Script
-- Purpose: Location Hierarchy, Geospatial Data, Complex Analytics
-- ============================================================================
-- This database handles complex relational queries and geospatial operations
-- Use Case: Building/floor/room hierarchy, geospatial queries, analytics
-- ============================================================================

-- Drop existing database if exists (for clean setup)
DROP DATABASE IF EXISTS iot_locations;

CREATE DATABASE iot_locations;

-- ============================================================================
-- NOTE: In DBeaver, you need to manually connect to the iot_locations database
-- after it's created. Right-click on the database in the Database Navigator
-- and select "Set Active Database" or create a new connection to iot_locations.
-- Then run the rest of this script.
-- ============================================================================

-- ============================================================================
-- EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS postgis;
-- Geospatial support
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- UUID generation
CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- Text search optimization

-- ============================================================================
-- TABLE: buildings
-- Purpose: Building information with geospatial coordinates
-- ============================================================================
CREATE TABLE buildings (
    building_id SERIAL PRIMARY KEY,
    building_code VARCHAR(20) NOT NULL UNIQUE,
    building_name VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20),
    location GEOGRAPHY (POINT, 4326), -- WGS 84 coordinate system
    total_floors INT NOT NULL,
    total_area_sqm DECIMAL(10, 2),
    construction_year INT,
    building_type VARCHAR(50), -- office, residential, industrial, mixed
    metadata JSONB, -- Flexible additional data
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- TABLE: floors
-- Purpose: Floor information within buildings
-- ============================================================================
CREATE TABLE floors (
    floor_id SERIAL PRIMARY KEY,
    building_id INT NOT NULL REFERENCES buildings (building_id) ON DELETE CASCADE,
    floor_number INT NOT NULL,
    floor_name VARCHAR(50),
    floor_area_sqm DECIMAL(10, 2),
    ceiling_height_m DECIMAL(4, 2),
    is_accessible BOOLEAN DEFAULT TRUE,
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (building_id, floor_number)
);

-- ============================================================================
-- TABLE: rooms
-- Purpose: Room information within floors
-- ============================================================================
CREATE TABLE rooms (
    room_id SERIAL PRIMARY KEY,
    floor_id INT NOT NULL REFERENCES floors (floor_id) ON DELETE CASCADE,
    room_code VARCHAR(20) NOT NULL,
    room_name VARCHAR(100) NOT NULL,
    room_type VARCHAR(50), -- office, meeting, storage, server, common
    area_sqm DECIMAL(8, 2),
    capacity INT,
    is_occupied BOOLEAN DEFAULT FALSE,
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (floor_id, room_code)
);

-- ============================================================================
-- TABLE: device_locations
-- Purpose: Device placement with geospatial data
-- ============================================================================
CREATE TABLE device_locations (
    location_id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL UNIQUE, -- References MySQL devices table
    room_id INT REFERENCES rooms (room_id) ON DELETE SET NULL,
    position GEOGRAPHY (POINT, 4326), -- Precise location within building
    installation_height_m DECIMAL(4, 2),
    orientation_degrees INT CHECK (
        orientation_degrees >= 0
        AND orientation_degrees < 360
    ),
    is_mobile BOOLEAN DEFAULT FALSE,
    installation_notes TEXT,
    installed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- TABLE: sensor_configurations
-- Purpose: Flexible sensor configurations using JSONB
-- ============================================================================
CREATE TABLE sensor_configurations (
    config_id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL UNIQUE,
    config_data JSONB NOT NULL, -- Flexible configuration storage
    calibration_data JSONB,
    last_calibration_date TIMESTAMP,
    next_calibration_date TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- TABLE: location_zones
-- Purpose: Define zones for grouping locations (e.g., HVAC zones)
-- ============================================================================
CREATE TABLE location_zones (
    zone_id SERIAL PRIMARY KEY,
    zone_name VARCHAR(100) NOT NULL,
    zone_type VARCHAR(50), -- hvac, security, lighting
    building_id INT NOT NULL REFERENCES buildings (building_id) ON DELETE CASCADE,
    zone_boundary GEOGRAPHY (POLYGON, 4326),
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- TABLE: zone_devices
-- Purpose: Many-to-many relationship between zones and devices
-- ============================================================================
CREATE TABLE zone_devices (
    zone_id INT NOT NULL REFERENCES location_zones (zone_id) ON DELETE CASCADE,
    device_id VARCHAR(50) NOT NULL,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (zone_id, device_id)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Geospatial indexes
CREATE INDEX idx_buildings_location ON buildings USING GIST (location);

CREATE INDEX idx_device_locations_position ON device_locations USING GIST (position);

CREATE INDEX idx_zones_boundary ON location_zones USING GIST (zone_boundary);

-- Standard indexes
CREATE INDEX idx_floors_building ON floors (building_id);

CREATE INDEX idx_rooms_floor ON rooms (floor_id);

CREATE INDEX idx_device_locations_room ON device_locations (room_id);

CREATE INDEX idx_device_locations_device ON device_locations (device_id);

CREATE INDEX idx_sensor_configs_device ON sensor_configurations (device_id);

-- JSONB indexes for fast queries
CREATE INDEX idx_buildings_metadata ON buildings USING GIN (metadata);

CREATE INDEX idx_sensor_configs_data ON sensor_configurations USING GIN (config_data);

CREATE INDEX idx_sensor_configs_calibration ON sensor_configurations USING GIN (calibration_data);

-- Text search indexes
CREATE INDEX idx_buildings_name_trgm ON buildings USING GIN (building_name gin_trgm_ops);

CREATE INDEX idx_rooms_name_trgm ON rooms USING GIN (room_name gin_trgm_ops);

-- ============================================================================
-- SAMPLE DATA INSERTION
-- ============================================================================

-- Insert sample buildings
INSERT INTO
    buildings (
        building_code,
        building_name,
        address,
        city,
        country,
        postal_code,
        location,
        total_floors,
        total_area_sqm,
        construction_year,
        building_type,
        metadata
    )
VALUES (
        'BLD-A',
        'Main Office Building',
        '123 Tech Street',
        'Jakarta',
        'Indonesia',
        '12345',
        ST_GeographyFromText ('POINT(106.8456 -6.2088)'),
        10,
        15000.00,
        2020,
        'office',
        '{"parking_spaces": 200, "has_cafeteria": true}'
    ),
    (
        'BLD-B',
        'Research & Development Center',
        '456 Innovation Ave',
        'Jakarta',
        'Indonesia',
        '12346',
        ST_GeographyFromText ('POINT(106.8466 -6.2098)'),
        5,
        8000.00,
        2021,
        'office',
        '{"parking_spaces": 100, "has_lab": true}'
    ),
    (
        'BLD-C',
        'Data Center',
        '789 Server Road',
        'Jakarta',
        'Indonesia',
        '12347',
        ST_GeographyFromText ('POINT(106.8476 -6.2108)'),
        2,
        3000.00,
        2022,
        'industrial',
        '{"backup_power": true, "cooling_system": "advanced"}'
    );

-- Insert sample floors for Building A
INSERT INTO
    floors (
        building_id,
        floor_number,
        floor_name,
        floor_area_sqm,
        ceiling_height_m
    )
VALUES (
        1,
        1,
        'Ground Floor',
        1500.00,
        4.5
    ),
    (
        1,
        2,
        'Second Floor',
        1500.00,
        3.5
    ),
    (
        1,
        3,
        'Third Floor',
        1500.00,
        3.5
    ),
    (
        1,
        4,
        'Fourth Floor',
        1500.00,
        3.5
    ),
    (
        1,
        5,
        'Fifth Floor',
        1500.00,
        3.5
    );

-- Insert sample floors for Building B
INSERT INTO
    floors (
        building_id,
        floor_number,
        floor_name,
        floor_area_sqm,
        ceiling_height_m
    )
VALUES (
        2,
        1,
        'Ground Floor',
        1600.00,
        4.0
    ),
    (
        2,
        2,
        'Second Floor',
        1600.00,
        3.5
    ),
    (
        2,
        3,
        'Third Floor',
        1600.00,
        3.5
    );

-- Insert sample floors for Building C
INSERT INTO
    floors (
        building_id,
        floor_number,
        floor_name,
        floor_area_sqm,
        ceiling_height_m
    )
VALUES (
        3,
        1,
        'Server Floor 1',
        1500.00,
        5.0
    ),
    (
        3,
        2,
        'Server Floor 2',
        1500.00,
        5.0
    );

-- Insert sample rooms
INSERT INTO
    rooms (
        floor_id,
        room_code,
        room_name,
        room_type,
        area_sqm,
        capacity
    )
VALUES
    -- Building A, Floor 1
    (
        1,
        'A1-001',
        'Main Lobby',
        'common',
        200.00,
        100
    ),
    (
        1,
        'A1-002',
        'Reception',
        'office',
        50.00,
        5
    ),
    (
        1,
        'A1-003',
        'Meeting Room A',
        'meeting',
        80.00,
        20
    ),
    -- Building A, Floor 2
    (
        2,
        'A2-001',
        'Open Office Space',
        'office',
        500.00,
        50
    ),
    (
        2,
        'A2-002',
        'Conference Room',
        'meeting',
        100.00,
        30
    ),
    (
        2,
        'A2-003',
        'Server Room',
        'server',
        80.00,
        5
    ),
    -- Building B, Floor 1
    (
        6,
        'B1-001',
        'Research Lab 1',
        'office',
        300.00,
        20
    ),
    (
        6,
        'B1-002',
        'Research Lab 2',
        'office',
        300.00,
        20
    ),
    -- Building C, Floor 1
    (
        9,
        'C1-001',
        'Main Server Room',
        'server',
        1200.00,
        10
    ),
    (
        9,
        'C1-002',
        'Network Operations Center',
        'office',
        300.00,
        15
    );

-- Insert device locations (referencing devices from MySQL)
INSERT INTO
    device_locations (
        device_id,
        room_id,
        position,
        installation_height_m,
        orientation_degrees
    )
VALUES (
        'TEMP-001',
        1,
        ST_GeographyFromText ('POINT(106.8456 -6.2088)'),
        2.5,
        0
    ),
    (
        'TEMP-002',
        6,
        ST_GeographyFromText ('POINT(106.8457 -6.2089)'),
        2.5,
        90
    ),
    (
        'HUM-001',
        1,
        ST_GeographyFromText ('POINT(106.8456 -6.2088)'),
        2.5,
        0
    ),
    (
        'MOT-001',
        1,
        ST_GeographyFromText ('POINT(106.8456 -6.2088)'),
        3.0,
        180
    ),
    (
        'ENR-001',
        6,
        ST_GeographyFromText ('POINT(106.8457 -6.2089)'),
        1.5,
        0
    );

-- Insert sensor configurations
INSERT INTO
    sensor_configurations (
        device_id,
        config_data,
        calibration_data,
        last_calibration_date,
        next_calibration_date
    )
VALUES (
        'TEMP-001',
        '{"sampling_rate_sec": 60, "precision": 0.1, "range": {"min": -10, "max": 50}}',
        '{"offset": 0.0, "scale": 1.0}',
        '2024-01-15',
        '2024-07-15'
    ),
    (
        'TEMP-002',
        '{"sampling_rate_sec": 30, "precision": 0.1, "range": {"min": 0, "max": 60}}',
        '{"offset": -0.2, "scale": 1.0}',
        '2024-01-15',
        '2024-07-15'
    ),
    (
        'HUM-001',
        '{"sampling_rate_sec": 60, "precision": 1.0, "range": {"min": 0, "max": 100}}',
        '{"offset": 0.0, "scale": 1.0}',
        '2024-01-15',
        '2024-07-15'
    ),
    (
        'MOT-001',
        '{"sampling_rate_sec": 1, "sensitivity": "high", "detection_range_m": 10}',
        '{"threshold": 0.5}',
        '2024-01-20',
        '2024-07-20'
    ),
    (
        'ENR-001',
        '{"sampling_rate_sec": 300, "precision": 0.01, "ct_ratio": 1000}',
        '{"offset": 0.0, "scale": 1.0}',
        '2024-01-10',
        '2024-07-10'
    );

-- Insert location zones
INSERT INTO
    location_zones (
        zone_name,
        zone_type,
        building_id,
        metadata
    )
VALUES (
        'Building A - HVAC Zone 1',
        'hvac',
        1,
        '{"target_temp": 22, "target_humidity": 50}'
    ),
    (
        'Building A - Security Zone',
        'security',
        1,
        '{"access_level": "restricted"}'
    ),
    (
        'Building C - Critical Infrastructure',
        'security',
        3,
        '{"access_level": "high_security", "monitoring": "24/7"}'
    );

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Complete device location hierarchy
CREATE VIEW v_device_location_hierarchy AS
SELECT 
    dl.device_id,
    b.building_code,
    b.building_name,
    f.floor_number,
    f.floor_name,
    r.room_code,
    r.room_name,
    r.room_type,
    dl.installation_height_m,
    ST_AsText(dl.position::geometry) AS position_wkt,
    ST_Y(dl.position::geometry) AS latitude,
    ST_X(dl.position::geometry) AS longitude
FROM device_locations dl
LEFT JOIN rooms r ON dl.room_id = r.room_id
LEFT JOIN floors f ON r.floor_id = f.floor_id
LEFT JOIN buildings b ON f.building_id = b.building_id;

-- Building statistics
CREATE VIEW v_building_statistics AS
SELECT
    b.building_id,
    b.building_code,
    b.building_name,
    COUNT(DISTINCT f.floor_id) AS total_floors,
    COUNT(DISTINCT r.room_id) AS total_rooms,
    COUNT(DISTINCT dl.device_id) AS total_devices,
    SUM(r.area_sqm) AS total_room_area_sqm
FROM
    buildings b
    LEFT JOIN floors f ON b.building_id = f.building_id
    LEFT JOIN rooms r ON f.floor_id = r.floor_id
    LEFT JOIN device_locations dl ON r.room_id = dl.room_id
GROUP BY
    b.building_id,
    b.building_code,
    b.building_name;

-- ============================================================================
-- MATERIALIZED VIEWS FOR ANALYTICS
-- ============================================================================

-- Materialized view for device density by room
CREATE MATERIALIZED VIEW mv_device_density_by_room AS
SELECT 
    r.room_id,
    r.room_code,
    r.room_name,
    r.room_type,
    r.area_sqm,
    COUNT(dl.device_id) AS device_count,
    CASE 
        WHEN r.area_sqm > 0 THEN ROUND((COUNT(dl.device_id)::NUMERIC / r.area_sqm), 4)
        ELSE 0 
    END AS devices_per_sqm
FROM rooms r
LEFT JOIN device_locations dl ON r.room_id = dl.room_id
GROUP BY r.room_id, r.room_code, r.room_name, r.room_type, r.area_sqm;

-- Create index on materialized view
CREATE INDEX idx_mv_device_density_room ON mv_device_density_by_room (room_id);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to get all devices within a radius of a point
CREATE OR REPLACE FUNCTION get_devices_within_radius(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION
)
RETURNS TABLE (
    device_id VARCHAR,
    distance_meters DOUBLE PRECISION,
    building_name VARCHAR,
    room_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dl.device_id,
        ST_Distance(
            dl.position,
            ST_GeographyFromText('POINT(' || p_longitude || ' ' || p_latitude || ')')
        ) AS distance_meters,
        b.building_name,
        r.room_name
    FROM device_locations dl
    LEFT JOIN rooms r ON dl.room_id = r.room_id
    LEFT JOIN floors f ON r.floor_id = f.floor_id
    LEFT JOIN buildings b ON f.building_id = b.building_id
    WHERE ST_DWithin(
        dl.position,
        ST_GeographyFromText('POINT(' || p_longitude || ' ' || p_latitude || ')'),
        p_radius_meters
    )
    ORDER BY distance_meters;
END;
$$ LANGUAGE plpgsql;

-- Function to get building hierarchy
CREATE OR REPLACE FUNCTION get_building_hierarchy(p_building_id INT)
RETURNS TABLE (
    level INT,
    type VARCHAR,
    id INT,
    name VARCHAR,
    parent_id INT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE hierarchy AS (
        -- Building level
        SELECT 
            1 AS level,
            'building'::VARCHAR AS type,
            b.building_id AS id,
            b.building_name AS name,
            NULL::INT AS parent_id
        FROM buildings b
        WHERE b.building_id = p_building_id
        
        UNION ALL
        
        -- Floor level
        SELECT 
            2 AS level,
            'floor'::VARCHAR AS type,
            f.floor_id AS id,
            f.floor_name AS name,
            f.building_id AS parent_id
        FROM floors f
        WHERE f.building_id = p_building_id
        
        UNION ALL
        
        -- Room level
        SELECT 
            3 AS level,
            'room'::VARCHAR AS type,
            r.room_id AS id,
            r.room_name AS name,
            r.floor_id AS parent_id
        FROM rooms r
        JOIN floors f ON r.floor_id = f.floor_id
        WHERE f.building_id = p_building_id
    )
    SELECT * FROM hierarchy ORDER BY level, id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_buildings_updated_at BEFORE UPDATE ON buildings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_floors_updated_at BEFORE UPDATE ON floors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rooms_updated_at BEFORE UPDATE ON rooms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_device_locations_updated_at BEFORE UPDATE ON device_locations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sensor_configurations_updated_at BEFORE UPDATE ON sensor_configurations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- REFRESH MATERIALIZED VIEWS (Run periodically)
-- ============================================================================
-- REFRESH MATERIALIZED VIEW mv_device_density_by_room;

-- ============================================================================
-- END OF POSTGRESQL INITIALIZATION SCRIPT
-- ============================================================================