# package_model.py
import pickle
import pandas as pd
import numpy as np
from datetime import datetime
import json
import warnings
warnings.filterwarnings('ignore')

class BengaluruRouteSafetyModel:
    def __init__(self, csv_file_path):
        """Initialize and train the model"""
        self.crime_weights = {
            'MURDER': 10, 'ATTEMPT TO MURDER': 8, 'RAPE': 9, 'DACOITY': 9,
            'ROBBERY': 6, 'BURGLARY-DAY': 4, 'BURGLARY-NIGHT': 5, 'THEFT': 2,
            'RIOTS': 7, 'CASES OF HURT': 3, 'CYBER CRIME': 1, 'POCSO': 9,
            'MOLESTATION': 6, 'CRUELTY BY HUSBAND': 5, 'DOWRY DEATHS': 8
        }
        
        self.lat_bounds = (12.8, 13.2)
        self.lon_bounds = (77.4, 77.8)
        
        self.time_multipliers = {
            range(0, 6): 1.4,    # Late night/early morning
            range(6, 9): 0.8,    # Morning rush
            range(9, 17): 0.9,   # Daytime
            range(17, 20): 1.0,  # Evening rush
            range(20, 24): 1.2   # Night
        }
        
        # Load and process crime data
        self._load_and_process_data(csv_file_path)
        
    def _load_and_process_data(self, csv_file_path):
        """Load crime data and create risk model"""
        print("📊 Loading and processing crime data...")
        
        # Load CSV data
        df = pd.read_csv(csv_file_path)
        bengaluru_row = df[df['DISTRICT/UNITS'] == 'Bengaluru City'].iloc[0]
        
        # Extract crime data
        self.crime_data = {}
        for col in df.columns[2:]:
            if col in self.crime_weights:
                value = bengaluru_row[col]
                if pd.notna(value) and value > 0:
                    self.crime_data[col] = int(value)
        
        # Generate synthetic crime locations
        self._generate_crime_locations()
        
        # Calculate risk percentiles
        self._calculate_risk_percentiles()
        
        print(f"✅ Model trained with {sum(self.crime_data.values())} crime records")
    
    def _generate_crime_locations(self):
        """Generate realistic crime location data"""
        self.crime_locations = []
        
        hotspot_patterns = {
            'THEFT': [(12.97, 77.59), (12.95, 77.65), (12.93, 77.61)],
            'ROBBERY': [(12.82, 77.42), (13.18, 77.78), (12.85, 77.75)],
            'CYBER CRIME': 'distributed',
            'MURDER': [(12.85, 77.60), (12.95, 77.55)],
            'RAPE': [(12.82, 77.42), (13.18, 77.78)]
        }
        
        for crime_type, count in self.crime_data.items():
            if crime_type in self.crime_weights:
                pattern = hotspot_patterns.get(crime_type, 'distributed')
                
                if pattern == 'distributed':
                    # Uniform distribution
                    for _ in range(min(count, 200)):
                        lat = np.random.uniform(*self.lat_bounds)
                        lon = np.random.uniform(*self.lon_bounds)
                        self.crime_locations.append({
                            'lat': lat, 'lon': lon, 
                            'weight': self.crime_weights[crime_type],
                            'type': crime_type
                        })
                else:
                    # Clustered around hotspots
                    points_per_center = count // len(pattern)
                    for center in pattern:
                        for _ in range(points_per_center):
                            lat = np.random.normal(center[0], 0.01)
                            lon = np.random.normal(center[1], 0.01)
                            lat = np.clip(lat, *self.lat_bounds)
                            lon = np.clip(lon, *self.lon_bounds)
                            self.crime_locations.append({
                                'lat': lat, 'lon': lon,
                                'weight': self.crime_weights[crime_type],
                                'type': crime_type
                            })
    
    def _calculate_risk_percentiles(self):
        """Calculate risk score percentiles for categorization"""
        sample_risks = []
        
        for _ in range(500):
            lat = np.random.uniform(*self.lat_bounds)
            lon = np.random.uniform(*self.lon_bounds)
            risk = self._calculate_point_risk(lat, lon)
            sample_risks.append(risk)
        
        self.risk_percentiles = np.percentile(sample_risks, [25, 50, 75])
    
    def _calculate_point_risk(self, lat, lon, radius=0.005):
        """Calculate risk score for a specific point"""
        total_risk = 0
        
        for crime in self.crime_locations:
            distance = np.sqrt((crime['lat'] - lat)**2 + (crime['lon'] - lon)**2)
            if distance < radius:
                weight = max(0, 1 - distance * 200)  # Linear decay
                total_risk += crime['weight'] * weight
        
        return np.log1p(total_risk * 0.1)
    
    def _get_time_adjusted_risk(self, base_risk, travel_hour):
        """Adjust risk based on time of travel"""
        if travel_hour is None:
            return base_risk
            
        for time_range, multiplier in self.time_multipliers.items():
            if travel_hour in time_range:
                return base_risk * multiplier
        return base_risk
    
    def _categorize_risk(self, risk_score):
        """Categorize risk score"""
        if risk_score <= self.risk_percentiles[0]:
            return "LOW"
        elif risk_score <= self.risk_percentiles[1]:
            return "MEDIUM"
        elif risk_score <= self.risk_percentiles[2]:
            return "MEDIUM-HIGH"
        else:
            return "HIGH"

def create_model_package(csv_file_path, output_path="bengaluru_route_safety_model.pkl"):
    """Create and save the model package"""
    print("🚀 Creating Bengaluru Route Safety Model Package...")
    
    # Create model
    model = BengaluruRouteSafetyModel(csv_file_path)
    
    # Save model
    with open(output_path, 'wb') as f:
        pickle.dump(model, f)
    
    print(f"✅ Model saved to {output_path}")
    print(f"📦 Package size: {round(len(pickle.dumps(model)) / 1024 / 1024, 2)} MB")
    
    return model

if __name__ == "__main__":
    model = create_model_package("ka_ipc_crimes_district_2024.csv")
