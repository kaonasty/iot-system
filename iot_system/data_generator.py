"""
Data Generator Module
Simulates IoT sensor data generation for testing
"""

import random
import time
from datetime import datetime, timedelta
from database_manager import DatabaseManager
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class IoTDataGenerator:
    """Generates realistic IoT sensor data"""
    
    def __init__(self, db_manager):
        self.db_manager = db_manager
        self.device_configs = {
            'TEMP-001': {'type': 'temperature', 'base': 22.0, 'variance': 3.0, 'unit': '°C'},
            'TEMP-002': {'type': 'temperature', 'base': 20.0, 'variance': 5.0, 'unit': '°C'},
            'HUM-001': {'type': 'humidity', 'base': 50.0, 'variance': 10.0, 'unit': '%'},
            'MOT-001': {'type': 'motion', 'base': 0.0, 'variance': 1.0, 'unit': 'boolean'},
            'ENR-001': {'type': 'energy', 'base': 100.0, 'variance': 50.0, 'unit': 'kWh'},
        }
    
    def generate_reading(self, device_id):
        """Generate a single sensor reading"""
        config = self.device_configs[device_id]
        
        # Generate value with realistic patterns
        if config['type'] == 'motion':
            value = random.choice([0, 1])  # Binary for motion
        elif config['type'] == 'temperature':
            # Add daily cycle (warmer during day)
            hour = datetime.now().hour
            daily_factor = 2.0 * (1 if 9 <= hour <= 17 else -1)
            value = config['base'] + daily_factor + random.gauss(0, config['variance'])
        else:
            value = config['base'] + random.gauss(0, config['variance'])
        
        # Quality score (90-100 for good sensors)
        quality_score = random.randint(90, 100)
        
        # 2% chance of anomaly
        is_anomaly = random.random() < 0.02
        if is_anomaly:
            value *= random.uniform(1.5, 2.0)  # Anomalous spike
        
        return {
            'device_id': device_id,
            'device_type': config['type'],
            'value': round(value, 2),
            'unit': config['unit'],
            'quality_score': quality_score,
            'is_anomaly': is_anomaly
        }
    
    def insert_reading_to_timescale(self, reading):
        """Insert a reading into TimescaleDB"""
        query = """
        INSERT INTO sensor_readings (time, device_id, device_type, value, unit, quality_score, is_anomaly)
        VALUES (NOW(), %s, %s, %s, %s, %s, %s)
        """
        
        with self.db_manager.get_timescale_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, (
                reading['device_id'],
                reading['device_type'],
                reading['value'],
                reading['unit'],
                reading['quality_score'],
                reading['is_anomaly']
            ))
            logger.info(f"Inserted reading: {reading['device_id']} = {reading['value']} {reading['unit']}")
    
    def generate_batch_readings(self, num_readings=100):
        """Generate batch of readings for all devices"""
        logger.info(f"Generating {num_readings} readings per device...")
        
        for _ in range(num_readings):
            for device_id in self.device_configs.keys():
                reading = self.generate_reading(device_id)
                self.insert_reading_to_timescale(reading)
        
        logger.info(f"Batch generation complete!")
    
    def generate_continuous(self, interval_seconds=5, duration_minutes=10):
        """Generate continuous data stream"""
        logger.info(f"Starting continuous generation for {duration_minutes} minutes...")
        logger.info(f"Sampling interval: {interval_seconds} seconds")
        
        end_time = datetime.now() + timedelta(minutes=duration_minutes)
        
        while datetime.now() < end_time:
            for device_id in self.device_configs.keys():
                reading = self.generate_reading(device_id)
                self.insert_reading_to_timescale(reading)
            
            time.sleep(interval_seconds)
        
        logger.info("Continuous generation complete!")
    
    def generate_historical_data(self, days=7):
        """Generate historical data for the past N days"""
        logger.info(f"Generating historical data for the past {days} days...")
        
        query = """
        INSERT INTO sensor_readings (time, device_id, device_type, value, unit, quality_score, is_anomaly)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        
        with self.db_manager.get_timescale_connection() as conn:
            cursor = conn.cursor()
            
            # Generate data points every minute for the past N days
            start_time = datetime.now() - timedelta(days=days)
            current_time = start_time
            
            batch = []
            batch_size = 1000
            
            while current_time < datetime.now():
                for device_id in self.device_configs.keys():
                    config = self.device_configs[device_id]
                    
                    # Generate value
                    if config['type'] == 'motion':
                        value = random.choice([0, 1])
                    else:
                        value = config['base'] + random.gauss(0, config['variance'])
                    
                    quality_score = random.randint(90, 100)
                    is_anomaly = random.random() < 0.02
                    
                    if is_anomaly:
                        value *= random.uniform(1.5, 2.0)
                    
                    batch.append((
                        current_time,
                        device_id,
                        config['type'],
                        round(value, 2),
                        config['unit'],
                        quality_score,
                        is_anomaly
                    ))
                    
                    # Insert in batches for performance
                    if len(batch) >= batch_size:
                        cursor.executemany(query, batch)
                        conn.commit()
                        logger.info(f"Inserted batch of {len(batch)} readings (up to {current_time})")
                        batch = []
                
                current_time += timedelta(minutes=1)
            
            # Insert remaining batch
            if batch:
                cursor.executemany(query, batch)
                conn.commit()
                logger.info(f"Inserted final batch of {len(batch)} readings")
        
        logger.info("Historical data generation complete!")


if __name__ == "__main__":
    db_manager = DatabaseManager()
    generator = IoTDataGenerator(db_manager)
    
    print("\n" + "="*50)
    print("IOT DATA GENERATOR")
    print("="*50)
    print("1. Generate batch readings (100 per device)")
    print("2. Generate continuous data (10 minutes)")
    print("3. Generate historical data (7 days)")
    print("="*50)
    
    choice = input("Select option (1-3): ")
    
    if choice == '1':
        generator.generate_batch_readings(100)
    elif choice == '2':
        generator.generate_continuous(interval_seconds=5, duration_minutes=10)
    elif choice == '3':
        generator.generate_historical_data(days=7)
    else:
        print("Invalid choice!")
