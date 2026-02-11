"""
Query Examples Module
Demonstrates key queries for each database type
"""

from database_manager import DatabaseManager
import json
from datetime import datetime, timedelta


class QueryExamples:
    """Demonstrates queries for MySQL, PostgreSQL, and TimescaleDB"""
    
    def __init__(self, db_manager):
        self.db_manager = db_manager
    
    def print_results(self, title, results, headers=None):
        """Pretty print query results"""
        print("\n" + "="*80)
        print(f"  {title}")
        print("="*80)
        
        if not results:
            print("No results found.")
            return
        
        if headers:
            print(" | ".join(str(h).ljust(15) for h in headers))
            print("-" * 80)
        
        for row in results:
            if isinstance(row, dict):
                print(" | ".join(str(v).ljust(15) for v in row.values()))
            else:
                print(" | ".join(str(v).ljust(15) for v in row))
        
        print(f"\nTotal rows: {len(results)}")
        print("="*80)
    
    # ========================================================================
    # MYSQL QUERIES - Transactional Data
    # ========================================================================
    
    def mysql_get_active_devices(self):
        """Get all active devices with type information"""
        query = """
        SELECT 
            d.device_id,
            d.device_name,
            dt.type_name,
            d.manufacturer,
            d.status,
            d.installation_date
        FROM devices d
        JOIN device_types dt ON d.device_type_id = dt.device_type_id
        WHERE d.status = 'active'
        ORDER BY d.device_id
        """
        
        with self.db_manager.get_mysql_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
            
        self.print_results(
            "MySQL: Active Devices",
            results,
            ['Device ID', 'Name', 'Type', 'Manufacturer', 'Status', 'Install Date']
        )
        return results
    
    def mysql_get_alert_configurations(self):
        """Get all enabled alert configurations"""
        query = """
        SELECT 
            ac.alert_name,
            dt.type_name AS device_type,
            ac.condition_type,
            ac.threshold_value,
            ac.severity,
            ac.notification_channels
        FROM alert_configurations ac
        JOIN device_types dt ON ac.device_type_id = dt.device_type_id
        WHERE ac.is_enabled = TRUE
        ORDER BY ac.severity DESC, dt.type_name
        """
        
        with self.db_manager.get_mysql_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
        
        self.print_results(
            "MySQL: Alert Configurations",
            results,
            ['Alert Name', 'Device Type', 'Condition', 'Threshold', 'Severity', 'Channels']
        )
        return results
    
    def mysql_get_device_statistics(self):
        """Get device statistics using direct SQL query"""
        query = """
        SELECT 
            dt.type_name,
            COUNT(*) AS total_devices,
            SUM(CASE WHEN d.status = 'active' THEN 1 ELSE 0 END) AS active_devices,
            SUM(CASE WHEN d.status = 'inactive' THEN 1 ELSE 0 END) AS inactive_devices,
            SUM(CASE WHEN d.status = 'maintenance' THEN 1 ELSE 0 END) AS maintenance_devices,
            SUM(CASE WHEN d.status = 'error' THEN 1 ELSE 0 END) AS error_devices
        FROM devices d
        JOIN device_types dt ON d.device_type_id = dt.device_type_id
        GROUP BY dt.type_name
        """
        
        with self.db_manager.get_mysql_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
        
        self.print_results(
            "MySQL: Device Statistics",
            results,
            ['Type', 'Total', 'Active', 'Inactive', 'Maintenance', 'Error']
        )
        return results
    
    # ========================================================================
    # POSTGRESQL QUERIES - Complex Analytics & Geospatial
    # ========================================================================
    
    def postgres_get_building_hierarchy(self):
        """Get complete building hierarchy"""
        query = """
        SELECT 
            b.building_name,
            f.floor_name,
            r.room_name,
            r.room_type,
            r.area_sqm,
            COUNT(dl.device_id) AS device_count
        FROM buildings b
        LEFT JOIN floors f ON b.building_id = f.building_id
        LEFT JOIN rooms r ON f.floor_id = r.floor_id
        LEFT JOIN device_locations dl ON r.room_id = dl.room_id
        GROUP BY b.building_name, b.building_id, f.floor_name, f.floor_number, r.room_name, r.room_type, r.area_sqm, r.room_code
        ORDER BY b.building_name, f.floor_number, r.room_code
        LIMIT 20
        """
        
        with self.db_manager.get_postgres_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
        
        self.print_results(
            "PostgreSQL: Building Hierarchy",
            results,
            ['Building', 'Floor', 'Room', 'Type', 'Area (sqm)', 'Devices']
        )
        return results
    
    def postgres_geospatial_query(self):
        """Find devices within 100m of a point"""
        query = """
        SELECT 
            dl.device_id,
            b.building_name,
            r.room_name,
            ROUND(ST_Distance(
                dl.position,
                ST_GeographyFromText('POINT(106.8456 -6.2088)')
            )::NUMERIC, 2) AS distance_meters
        FROM device_locations dl
        LEFT JOIN rooms r ON dl.room_id = r.room_id
        LEFT JOIN floors f ON r.floor_id = f.floor_id
        LEFT JOIN buildings b ON f.building_id = b.building_id
        WHERE ST_DWithin(
            dl.position,
            ST_GeographyFromText('POINT(106.8456 -6.2088)'),
            100
        )
        ORDER BY distance_meters
        """
        
        with self.db_manager.get_postgres_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
        
        self.print_results(
            "PostgreSQL: Geospatial Query (Devices within 100m)",
            results,
            ['Device ID', 'Building', 'Room', 'Distance (m)']
        )
        return results
    
    def postgres_jsonb_query(self):
        """Query JSONB configuration data"""
        query = """
        SELECT 
            device_id,
            config_data->>'sampling_rate_sec' AS sampling_rate,
            config_data->>'precision' AS precision,
            config_data->'range'->>'min' AS min_range,
            config_data->'range'->>'max' AS max_range
        FROM sensor_configurations
        WHERE config_data->>'sampling_rate_sec' IS NOT NULL
        ORDER BY device_id
        """
        
        with self.db_manager.get_postgres_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
        
        self.print_results(
            "PostgreSQL: JSONB Configuration Query",
            results,
            ['Device ID', 'Sample Rate', 'Precision', 'Min Range', 'Max Range']
        )
        return results
    
    def postgres_materialized_view_query(self):
        """Query materialized view for device density"""
        query = """
        SELECT 
            room_code,
            room_name,
            room_type,
            area_sqm,
            device_count,
            devices_per_sqm
        FROM mv_device_density_by_room
        WHERE device_count > 0
        ORDER BY devices_per_sqm DESC
        LIMIT 10
        """
        
        with self.db_manager.get_postgres_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
        
        self.print_results(
            "PostgreSQL: Device Density (Materialized View)",
            results,
            ['Room Code', 'Room Name', 'Type', 'Area', 'Devices', 'Density']
        )
        return results
    
    # ========================================================================
    # TIMESCALEDB QUERIES - Time-Series Data
    # ========================================================================
    
    def timescale_latest_readings(self):
        """Get latest reading for each device"""
        query = """
        SELECT * FROM v_latest_readings
        ORDER BY device_id
        """
        
        with self.db_manager.get_timescale_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
        
        self.print_results(
            "TimescaleDB: Latest Readings",
            results,
            ['Device ID', 'Type', 'Time', 'Value', 'Unit', 'Quality', 'Anomaly']
        )
        return results
    
    def timescale_hourly_aggregates(self, device_id='TEMP-001', hours=24):
        """Get hourly aggregates for a device"""
        query = """
        SELECT 
            bucket,
            reading_count,
            ROUND(avg_value::NUMERIC, 2) AS avg_value,
            ROUND(min_value::NUMERIC, 2) AS min_value,
            ROUND(max_value::NUMERIC, 2) AS max_value,
            anomaly_count
        FROM sensor_readings_1h
        WHERE device_id = %s
            AND bucket > NOW() - INTERVAL '%s hours'
        ORDER BY bucket DESC
        LIMIT %s
        """
        
        with self.db_manager.get_timescale_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, (device_id, hours, hours))
            results = cursor.fetchall()
        
        self.print_results(
            f"TimescaleDB: Hourly Aggregates for {device_id}",
            results,
            ['Time Bucket', 'Count', 'Avg', 'Min', 'Max', 'Anomalies']
        )
        return results
    
    def timescale_anomaly_detection(self):
        """Get recent anomalies"""
        query = """
        SELECT * FROM v_recent_anomalies
        LIMIT 20
        """
        
        with self.db_manager.get_timescale_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
        
        self.print_results(
            "TimescaleDB: Recent Anomalies (Last 24 Hours)",
            results,
            ['Time', 'Device ID', 'Type', 'Value', 'Unit']
        )
        return results
    
    def timescale_device_health(self):
        """Get device health summary"""
        query = """
        SELECT 
            device_id,
            device_type,
            reading_count,
            ROUND(avg_quality_score::NUMERIC, 2) AS avg_quality,
            last_reading_time,
            EXTRACT(EPOCH FROM time_since_last_reading)::INT AS seconds_since_last,
            anomaly_count
        FROM v_device_health_summary
        ORDER BY device_id
        """
        
        with self.db_manager.get_timescale_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
        
        self.print_results(
            "TimescaleDB: Device Health Summary (Last Hour)",
            results,
            ['Device', 'Type', 'Readings', 'Avg Quality', 'Last Reading', 'Seconds Ago', 'Anomalies']
        )
        return results
    
    def timescale_time_bucket_analysis(self, device_id='TEMP-001'):
        """Demonstrate time_bucket function"""
        query = """
        SELECT 
            time_bucket('5 minutes', time) AS bucket,
            COUNT(*) AS reading_count,
            ROUND(AVG(value)::NUMERIC, 2) AS avg_value,
            ROUND(MIN(value)::NUMERIC, 2) AS min_value,
            ROUND(MAX(value)::NUMERIC, 2) AS max_value
        FROM sensor_readings
        WHERE device_id = %s
            AND time > NOW() - INTERVAL '1 hour'
        GROUP BY bucket
        ORDER BY bucket DESC
        """
        
        with self.db_manager.get_timescale_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, (device_id,))
            results = cursor.fetchall()
        
        self.print_results(
            f"TimescaleDB: 5-Minute Buckets for {device_id}",
            results,
            ['Time Bucket', 'Count', 'Avg', 'Min', 'Max']
        )
        return results
    
    def run_all_examples(self):
        """Run all query examples"""
        print("\n" + "🔷"*40)
        print("  RUNNING ALL QUERY EXAMPLES")
        print("🔷"*40)
        
        # MySQL Examples
        print("\n📊 MYSQL QUERIES - Transactional Data")
        self.mysql_get_active_devices()
        self.mysql_get_alert_configurations()
        self.mysql_get_device_statistics()
        
        # PostgreSQL Examples
        print("\n📊 POSTGRESQL QUERIES - Complex Analytics & Geospatial")
        self.postgres_get_building_hierarchy()
        self.postgres_geospatial_query()
        self.postgres_jsonb_query()
        self.postgres_materialized_view_query()
        
        # TimescaleDB Examples
        print("\n📊 TIMESCALEDB QUERIES - Time-Series Data")
        self.timescale_latest_readings()
        self.timescale_hourly_aggregates()
        self.timescale_anomaly_detection()
        self.timescale_device_health()
        self.timescale_time_bucket_analysis()
        
        print("\n" + "🔷"*40)
        print("  ALL EXAMPLES COMPLETED")
        print("🔷"*40)


if __name__ == "__main__":
    db_manager = DatabaseManager()
    query_examples = QueryExamples(db_manager)
    
    query_examples.run_all_examples()
