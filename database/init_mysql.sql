-- ============================================================================
-- MySQL Database Initialization Script
-- Purpose: User Management, Device Registry, Alert Configurations
-- ============================================================================
-- This database handles transactional data requiring ACID compliance
-- Use Case: User authentication, device metadata, alert management
-- ============================================================================

-- Drop existing database if exists (for clean setup)
DROP DATABASE IF EXISTS iot_system;

CREATE DATABASE iot_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE iot_system;

-- ============================================================================
-- TABLE: users
-- Purpose: User accounts and authentication
-- ============================================================================
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role ENUM(
        'admin',
        'manager',
        'operator',
        'viewer'
    ) NOT NULL DEFAULT 'viewer',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_role (role),
    INDEX idx_is_active (is_active)
) ENGINE = InnoDB COMMENT = 'User accounts and authentication';

-- ============================================================================
-- TABLE: device_types
-- Purpose: Sensor type definitions
-- ============================================================================
CREATE TABLE device_types (
    device_type_id INT AUTO_INCREMENT PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    unit_of_measurement VARCHAR(20),
    min_value DECIMAL(10, 2),
    max_value DECIMAL(10, 2),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_type_name (type_name)
) ENGINE = InnoDB COMMENT = 'Sensor type definitions';

-- ============================================================================
-- TABLE: devices
-- Purpose: Device registry with metadata
-- ============================================================================
CREATE TABLE devices (
    device_id VARCHAR(50) PRIMARY KEY,
    device_type_id INT NOT NULL,
    device_name VARCHAR(100) NOT NULL,
    manufacturer VARCHAR(100),
    model VARCHAR(100),
    serial_number VARCHAR(100) UNIQUE,
    firmware_version VARCHAR(50),
    status ENUM(
        'active',
        'inactive',
        'maintenance',
        'error'
    ) NOT NULL DEFAULT 'active',
    installation_date DATE,
    last_maintenance_date DATE,
    created_by INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (device_type_id) REFERENCES device_types (device_type_id) ON DELETE RESTRICT,
    FOREIGN KEY (created_by) REFERENCES users (user_id) ON DELETE RESTRICT,
    INDEX idx_device_type (device_type_id),
    INDEX idx_status (status),
    INDEX idx_serial_number (serial_number),
    INDEX idx_created_by (created_by)
) ENGINE = InnoDB COMMENT = 'Device registry with metadata';

-- ============================================================================
-- TABLE: alert_configurations
-- Purpose: Alert rules and thresholds
-- ============================================================================
CREATE TABLE alert_configurations (
    alert_config_id INT AUTO_INCREMENT PRIMARY KEY,
    device_type_id INT NOT NULL,
    alert_name VARCHAR(100) NOT NULL,
    condition_type ENUM(
        'threshold_high',
        'threshold_low',
        'rate_of_change',
        'no_data'
    ) NOT NULL,
    threshold_value DECIMAL(10, 2),
    time_window_minutes INT DEFAULT 5,
    severity ENUM('critical', 'warning', 'info') NOT NULL DEFAULT 'warning',
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    notification_channels JSON COMMENT 'Array of notification channels: email, sms, slack',
    created_by INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (device_type_id) REFERENCES device_types (device_type_id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users (user_id) ON DELETE RESTRICT,
    INDEX idx_device_type (device_type_id),
    INDEX idx_severity (severity),
    INDEX idx_is_enabled (is_enabled)
) ENGINE = InnoDB COMMENT = 'Alert rules and thresholds';

-- ============================================================================
-- TABLE: notification_logs
-- Purpose: Alert notification history
-- ============================================================================
CREATE TABLE notification_logs (
    notification_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alert_config_id INT NOT NULL,
    device_id VARCHAR(50) NOT NULL,
    triggered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    severity ENUM('critical', 'warning', 'info') NOT NULL,
    message TEXT NOT NULL,
    notification_channel VARCHAR(50) NOT NULL,
    is_sent BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NULL,
    error_message TEXT,
    FOREIGN KEY (alert_config_id) REFERENCES alert_configurations (alert_config_id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices (device_id) ON DELETE CASCADE,
    INDEX idx_triggered_at (triggered_at),
    INDEX idx_device_id (device_id),
    INDEX idx_severity (severity),
    INDEX idx_is_sent (is_sent)
) ENGINE = InnoDB COMMENT = 'Alert notification history';

-- ============================================================================
-- TABLE: audit_logs
-- Purpose: System audit trail
-- ============================================================================
CREATE TABLE audit_logs (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id VARCHAR(50),
    old_values JSON,
    new_values JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_action (action),
    INDEX idx_table_name (table_name),
    INDEX idx_created_at (created_at)
) ENGINE = InnoDB COMMENT = 'System audit trail';

-- ============================================================================
-- SAMPLE DATA INSERTION
-- ============================================================================

-- Insert device types
INSERT INTO
    device_types (
        type_name,
        description,
        unit_of_measurement,
        min_value,
        max_value
    )
VALUES (
        'temperature',
        'Temperature sensor',
        '°C',
        -40.00,
        85.00
    ),
    (
        'humidity',
        'Humidity sensor',
        '%',
        0.00,
        100.00
    ),
    (
        'motion',
        'Motion detector',
        'boolean',
        0.00,
        1.00
    ),
    (
        'energy',
        'Energy consumption meter',
        'kWh',
        0.00,
        999999.99
    ),
    (
        'air_quality',
        'Air quality sensor',
        'AQI',
        0.00,
        500.00
    ),
    (
        'light',
        'Light intensity sensor',
        'lux',
        0.00,
        100000.00
    );

-- Insert sample users
INSERT INTO
    users (
        username,
        email,
        password_hash,
        full_name,
        role
    )
VALUES (
        'admin',
        'admin@iotsystem.com',
        '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIq.Ks6rGu',
        'System Administrator',
        'admin'
    ),
    (
        'john_manager',
        'john@iotsystem.com',
        '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIq.Ks6rGu',
        'John Manager',
        'manager'
    ),
    (
        'jane_operator',
        'jane@iotsystem.com',
        '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIq.Ks6rGu',
        'Jane Operator',
        'operator'
    ),
    (
        'bob_viewer',
        'bob@iotsystem.com',
        '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIq.Ks6rGu',
        'Bob Viewer',
        'viewer'
    );

-- Insert sample devices
INSERT INTO
    devices (
        device_id,
        device_type_id,
        device_name,
        manufacturer,
        model,
        serial_number,
        firmware_version,
        status,
        installation_date,
        created_by
    )
VALUES (
        'TEMP-001',
        1,
        'Temperature Sensor - Lobby',
        'SensorTech',
        'ST-T100',
        'SN-TEMP-001',
        'v2.1.0',
        'active',
        '2024-01-15',
        1
    ),
    (
        'TEMP-002',
        1,
        'Temperature Sensor - Server Room',
        'SensorTech',
        'ST-T100',
        'SN-TEMP-002',
        'v2.1.0',
        'active',
        '2024-01-15',
        1
    ),
    (
        'HUM-001',
        2,
        'Humidity Sensor - Lobby',
        'SensorTech',
        'ST-H50',
        'SN-HUM-001',
        'v1.5.2',
        'active',
        '2024-01-15',
        1
    ),
    (
        'MOT-001',
        3,
        'Motion Detector - Entrance',
        'SecureSense',
        'SS-M200',
        'SN-MOT-001',
        'v3.0.1',
        'active',
        '2024-01-20',
        1
    ),
    (
        'ENR-001',
        4,
        'Energy Meter - Building A',
        'PowerMon',
        'PM-E500',
        'SN-ENR-001',
        'v4.2.0',
        'active',
        '2024-01-10',
        1
    );

-- Insert sample alert configurations
INSERT INTO
    alert_configurations (
        device_type_id,
        alert_name,
        condition_type,
        threshold_value,
        time_window_minutes,
        severity,
        notification_channels,
        created_by
    )
VALUES (
        1,
        'High Temperature Alert',
        'threshold_high',
        30.00,
        5,
        'warning',
        '["email", "slack"]',
        1
    ),
    (
        1,
        'Critical Temperature Alert',
        'threshold_high',
        40.00,
        5,
        'critical',
        '["email", "sms", "slack"]',
        1
    ),
    (
        2,
        'Low Humidity Alert',
        'threshold_low',
        30.00,
        10,
        'warning',
        '["email"]',
        1
    ),
    (
        2,
        'High Humidity Alert',
        'threshold_high',
        70.00,
        10,
        'warning',
        '["email"]',
        1
    ),
    (
        4,
        'High Energy Consumption',
        'threshold_high',
        1000.00,
        60,
        'warning',
        '["email", "slack"]',
        1
    );

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Active devices with type information
CREATE VIEW v_active_devices AS
SELECT
    d.device_id,
    d.device_name,
    dt.type_name,
    dt.unit_of_measurement,
    d.manufacturer,
    d.model,
    d.status,
    d.installation_date,
    u.full_name AS created_by_name
FROM
    devices d
    JOIN device_types dt ON d.device_type_id = dt.device_type_id
    JOIN users u ON d.created_by = u.user_id
WHERE
    d.status = 'active';

-- Alert summary view
CREATE VIEW v_alert_summary AS
SELECT
    ac.alert_config_id,
    ac.alert_name,
    dt.type_name AS device_type,
    ac.condition_type,
    ac.threshold_value,
    ac.severity,
    ac.is_enabled,
    u.full_name AS created_by_name
FROM
    alert_configurations ac
    JOIN device_types dt ON ac.device_type_id = dt.device_type_id
    JOIN users u ON ac.created_by = u.user_id;

-- ============================================================================
-- STORED PROCEDURES (COMMENTED OUT - DBeaver Compatibility Issue)
-- ============================================================================
-- NOTE: DBeaver has issues with CREATE PROCEDURE statements
-- The system works fine without stored procedures
-- If you need them, create them using MySQL command line client
--
-- To use MySQL command line:
--   mysql -u root -p iot_system
--   Then copy/paste the procedures below with DELIMITER commands
--
-- For now, you can use equivalent SQL queries instead:
--   - Instead of sp_log_audit: Direct INSERT INTO audit_logs
--   - Instead of sp_get_device_statistics: Use the SELECT query below

/*
-- Procedure to log user actions
DROP PROCEDURE IF EXISTS sp_log_audit;

DELIMITER $$
CREATE PROCEDURE sp_log_audit(
IN p_user_id INT,
IN p_action VARCHAR(100),
IN p_table_name VARCHAR(50),
IN p_record_id VARCHAR(50),
IN p_old_values JSON,
IN p_new_values JSON,
IN p_ip_address VARCHAR(45)
)
BEGIN
INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values, ip_address)
VALUES (p_user_id, p_action, p_table_name, p_record_id, p_old_values, p_new_values, p_ip_address);
END$$
DELIMITER ;

-- Procedure to get device statistics
DROP PROCEDURE IF EXISTS sp_get_device_statistics;

DELIMITER $$
CREATE PROCEDURE sp_get_device_statistics()
BEGIN
SELECT 
dt.type_name,
COUNT(*) AS total_devices,
SUM(CASE WHEN d.status = 'active' THEN 1 ELSE 0 END) AS active_devices,
SUM(CASE WHEN d.status = 'inactive' THEN 1 ELSE 0 END) AS inactive_devices,
SUM(CASE WHEN d.status = 'maintenance' THEN 1 ELSE 0 END) AS maintenance_devices,
SUM(CASE WHEN d.status = 'error' THEN 1 ELSE 0 END) AS error_devices
FROM devices d
JOIN device_types dt ON d.device_type_id = dt.device_type_id
GROUP BY dt.type_name;
END$$
DELIMITER ;
*/

-- Equivalent query for device statistics (use this instead of stored procedure):
-- SELECT
--     dt.type_name,
--     COUNT(*) AS total_devices,
--     SUM(CASE WHEN d.status = 'active' THEN 1 ELSE 0 END) AS active_devices,
--     SUM(CASE WHEN d.status = 'inactive' THEN 1 ELSE 0 END) AS inactive_devices,
--     SUM(CASE WHEN d.status = 'maintenance' THEN 1 ELSE 0 END) AS maintenance_devices,
--     SUM(CASE WHEN d.status = 'error' THEN 1 ELSE 0 END) AS error_devices
-- FROM devices d
-- JOIN device_types dt ON d.device_type_id = dt.device_type_id
-- GROUP BY dt.type_name;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
-- Additional composite indexes for common query patterns

CREATE INDEX idx_devices_type_status ON devices (device_type_id, status);

CREATE INDEX idx_notifications_device_time ON notification_logs (device_id, triggered_at);

CREATE INDEX idx_audit_user_time ON audit_logs (user_id, created_at);

-- ============================================================================
-- GRANTS (Optional - for production use)
-- ============================================================================
-- CREATE USER 'iot_app'@'%' IDENTIFIED BY 'secure_password';
-- GRANT SELECT, INSERT, UPDATE ON iot_system.* TO 'iot_app'@'%';
-- GRANT EXECUTE ON PROCEDURE iot_system.sp_log_audit TO 'iot_app'@'%';
-- GRANT EXECUTE ON PROCEDURE iot_system.sp_get_device_statistics TO 'iot_app'@'%';

-- ============================================================================
-- END OF MYSQL INITIALIZATION SCRIPT
-- ============================================================================