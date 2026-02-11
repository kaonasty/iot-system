"""
Database Manager Module
Handles connections to MySQL, PostgreSQL, and TimescaleDB
"""

import os
import mysql.connector
import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
from dotenv import load_dotenv
import logging

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DatabaseManager:
    """Manages connections to all three databases"""
    
    def __init__(self):
        self.mysql_config = {
            'host': os.getenv('MYSQL_HOST', 'localhost'),
            'port': int(os.getenv('MYSQL_PORT', 3306)),
            'user': os.getenv('MYSQL_USER', 'root'),
            'password': os.getenv('MYSQL_PASSWORD', ''),
            'database': os.getenv('MYSQL_DATABASE', 'iot_system')
        }
        
        self.postgres_config = {
            'host': os.getenv('POSTGRES_HOST', 'localhost'),
            'port': int(os.getenv('POSTGRES_PORT', 5432)),
            'user': os.getenv('POSTGRES_USER', 'postgres'),
            'password': os.getenv('POSTGRES_PASSWORD', ''),
            'database': os.getenv('POSTGRES_DATABASE', 'iot_locations')
        }
        
        self.timescale_config = {
            'host': os.getenv('TIMESCALE_HOST', 'localhost'),
            'port': int(os.getenv('TIMESCALE_PORT', 5433)),
            'user': os.getenv('TIMESCALE_USER', 'postgres'),
            'password': os.getenv('TIMESCALE_PASSWORD', ''),
            'database': os.getenv('TIMESCALE_DATABASE', 'iot_timeseries')
        }
    
    @contextmanager
    def get_mysql_connection(self):
        """Context manager for MySQL connections"""
        conn = None
        try:
            conn = mysql.connector.connect(**self.mysql_config)
            logger.info("MySQL connection established")
            yield conn
            conn.commit()
        except mysql.connector.Error as e:
            logger.error(f"MySQL error: {e}")
            if conn:
                conn.rollback()
            raise
        finally:
            if conn and conn.is_connected():
                conn.close()
                logger.info("MySQL connection closed")
    
    @contextmanager
    def get_postgres_connection(self):
        """Context manager for PostgreSQL connections"""
        conn = None
        try:
            conn = psycopg2.connect(**self.postgres_config)
            logger.info("PostgreSQL connection established")
            yield conn
            conn.commit()
        except psycopg2.Error as e:
            logger.error(f"PostgreSQL error: {e}")
            if conn:
                conn.rollback()
            raise
        finally:
            if conn:
                conn.close()
                logger.info("PostgreSQL connection closed")
    
    @contextmanager
    def get_timescale_connection(self):
        """Context manager for TimescaleDB connections"""
        conn = None
        try:
            conn = psycopg2.connect(**self.timescale_config)
            logger.info("TimescaleDB connection established")
            yield conn
            conn.commit()
        except psycopg2.Error as e:
            logger.error(f"TimescaleDB error: {e}")
            if conn:
                conn.rollback()
            raise
        finally:
            if conn:
                conn.close()
                logger.info("TimescaleDB connection closed")
    
    def test_connections(self):
        """Test all database connections"""
        results = {
            'mysql': False,
            'postgresql': False,
            'timescaledb': False
        }
        
        # Test MySQL
        try:
            with self.get_mysql_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT VERSION()")
                version = cursor.fetchone()
                logger.info(f"MySQL version: {version[0]}")
                results['mysql'] = True
        except Exception as e:
            logger.error(f"MySQL connection failed: {e}")
        
        # Test PostgreSQL
        try:
            with self.get_postgres_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT version()")
                version = cursor.fetchone()
                logger.info(f"PostgreSQL version: {version[0]}")
                results['postgresql'] = True
        except Exception as e:
            logger.error(f"PostgreSQL connection failed: {e}")
        
        # Test TimescaleDB
        try:
            with self.get_timescale_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT extversion FROM pg_extension WHERE extname = 'timescaledb'")
                version = cursor.fetchone()
                if version:
                    logger.info(f"TimescaleDB version: {version[0]}")
                    results['timescaledb'] = True
                else:
                    logger.warning("TimescaleDB extension not found")
        except Exception as e:
            logger.error(f"TimescaleDB connection failed: {e}")
        
        return results


if __name__ == "__main__":
    # Test database connections
    db_manager = DatabaseManager()
    results = db_manager.test_connections()
    
    print("\n" + "="*50)
    print("DATABASE CONNECTION TEST RESULTS")
    print("="*50)
    for db_name, status in results.items():
        status_str = "✓ SUCCESS" if status else "✗ FAILED"
        print(f"{db_name.upper()}: {status_str}")
    print("="*50)
