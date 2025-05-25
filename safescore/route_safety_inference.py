import pickle
import json
import numpy as np
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

class RouteSafetyInference:
    def __init__(self, model_path="bengaluru_route_safety_model.pkl"):
        """Load the trained model"""
        print("📦 Loading Bengaluru Route Safety Model...")
        
        with open(model_path, 'rb') as f:
            self.model = pickle.load(f)
        
        print("✅ Model loaded successfully")
    
    def parse_maps_response(self, maps_response):
        """Parse Google Maps API response to extract route information"""
        if isinstance(maps_response, str):
            maps_response = json.loads(maps_response)
        
        routes = []
        
        for i, route_data in enumerate(maps_response.get('routes', [])):
            # Extract basic route info
            route_info = {
                'route_index': i,
                'summary': route_data.get('summary', f'Route {i+1}'),
                'distance': route_data.get('distance', 'Unknown'),
                'duration': route_data.get('duration', 'Unknown'),
                'coordinates': route_data.get('coordinates', [])
            }
            
            # Convert coordinate format if needed
            if route_info['coordinates']:
                formatted_coords = []
                for coord in route_info['coordinates']:
                    if isinstance(coord, dict):
                        formatted_coords.append((coord['latitude'], coord['longitude']))
                    else:
                        formatted_coords.append(coord)
                route_info['coordinates'] = formatted_coords
            
            routes.append(route_info)
        
        return routes
    
    def calculate_route_risk(self, coordinates, travel_hour=None):
        """Calculate risk score for a route"""
        if not coordinates:
            return 0, 0
        
        segment_risks = []
        
        # Sample every 3rd coordinate to reduce computation
        for lat, lon in coordinates[::3]:
            # Check if coordinates are within Bengaluru bounds
            if (self.model.lat_bounds[0] <= lat <= self.model.lat_bounds[1] and 
                self.model.lon_bounds[0] <= lon <= self.model.lon_bounds[1]):
                
                point_risk = self.model._calculate_point_risk(lat, lon)
                segment_risks.append(point_risk)
            else:
                segment_risks.append(0)  # Outside Bengaluru
        
        if segment_risks:
            total_risk = np.sum(segment_risks)
            route_length = len(coordinates) * 0.1  # Approximate length
            normalized_risk = total_risk / max(route_length, 1)
            
            # Apply time adjustment
            if travel_hour is not None:
                normalized_risk = self.model._get_time_adjusted_risk(normalized_risk, travel_hour)
            
            return normalized_risk, total_risk
        
        return 0, 0
    
    def analyze_routes(self, maps_response, travel_hour=None):
        """Analyze all routes and return recommendations"""
        print("🔍 Analyzing routes for safety...")
        
        # Parse maps response
        routes = self.parse_maps_response(maps_response)
        
        if not routes:
            return {"error": "No routes found in the provided data"}
        
        # Analyze each route
        route_analyses = []
        
        for route in routes:
            # Calculate risk scores
            risk_score, total_risk = self.calculate_route_risk(
                route['coordinates'], travel_hour
            )
            
            # Categorize risk
            risk_category = self.model._categorize_risk(risk_score)
            
            # Calculate safety score (0-10)
            safety_score = max(0, 10 - risk_score * 2)
            
            # Create analysis result
            analysis = {
                'route_index': route['route_index'],
                'summary': route['summary'],
                'distance': route['distance'],
                'duration': route['duration'],
                'risk_score': round(risk_score, 3),
                'total_risk': round(total_risk, 2),
                'risk_category': risk_category,
                'safety_score': round(safety_score, 1),
                'coordinates': route['coordinates'],
                'is_recommended': False  # Will be set for the safest route
            }
            
            route_analyses.append(analysis)
        
        # Sort by risk score (lowest first)
        route_analyses.sort(key=lambda x: x['risk_score'])
        
        # Mark the safest route as recommended
        if route_analyses:
            route_analyses[0]['is_recommended'] = True
        
        # Calculate insights
        insights = self._generate_insights(route_analyses, travel_hour)
        
        return {
            'timestamp': datetime.now().isoformat(),
            'total_routes': len(route_analyses),
            'travel_hour': travel_hour,
            'routes': route_analyses,
            'insights': insights,
            'recommended_route': route_analyses[0] if route_analyses else None
        }
    
    def _generate_insights(self, route_analyses, travel_hour):
        """Generate insights about the route analysis"""
        if len(route_analyses) < 2:
            return {"message": "Only one route available"}
        
        safest = route_analyses[0]
        riskiest = route_analyses[-1]
        
        insights = {
            'safest_route': {
                'index': safest['route_index'],
                'summary': safest['summary'],
                'risk_score': safest['risk_score']
            },
            'riskiest_route': {
                'index': riskiest['route_index'],
                'summary': riskiest['summary'],
                'risk_score': riskiest['risk_score']
            }
        }
        
        # Calculate risk reduction
        if riskiest['risk_score'] > 0:
            risk_reduction = ((riskiest['risk_score'] - safest['risk_score']) / 
                            riskiest['risk_score']) * 100
            insights['risk_reduction_percentage'] = round(risk_reduction, 1)
        
        # Time-based insights
        if travel_hour is not None:
            if 0 <= travel_hour <= 6:
                insights['time_warning'] = "Late night/early morning - higher crime risk"
            elif 6 <= travel_hour <= 9:
                insights['time_info'] = "Morning rush hour - generally safer"
            elif 20 <= travel_hour <= 24:
                insights['time_warning'] = "Night time - increased risk"
        
        return insights
    
    def get_route_coordinates_json(self, analysis_result, route_index=None):
        """Extract coordinates for a specific route in JSON format"""
        if route_index is None:
            # Return recommended route
            route = analysis_result.get('recommended_route')
        else:
            # Find specific route
            route = None
            for r in analysis_result.get('routes', []):
                if r['route_index'] == route_index:
                    route = r
                    break
        
        if not route:
            return {"error": "Route not found"}
        
        # Format coordinates for frontend
        formatted_coords = []
        for coord in route['coordinates']:
            if isinstance(coord, (list, tuple)) and len(coord) >= 2:
                formatted_coords.append({
                    "latitude": float(coord[0]),
                    "longitude": float(coord[1])
                })
        
        return {
            'route_index': route['route_index'],
            'summary': route['summary'],
            'risk_category': route['risk_category'],
            'safety_score': route['safety_score'],
            'coordinates': formatted_coords,
            'total_points': len(formatted_coords)
        }

def analyze_routes_from_maps(maps_response_file, travel_hour=None, 
                           model_path="bengaluru_route_safety_model.pkl"):
    """Main function to analyze routes from Google Maps response"""
    
    # Initialize inference engine
    inference = RouteSafetyInference(model_path)
    
    # Load maps response
    if isinstance(maps_response_file, str):
        if maps_response_file.endswith('.json'):
            with open(maps_response_file, 'r') as f:
                maps_response = json.load(f)
        else:
            maps_response = json.loads(maps_response_file)
    else:
        maps_response = maps_response_file
    
    # Analyze routes
    analysis = inference.analyze_routes(maps_response, travel_hour)
    
    return analysis, inference

if __name__ == "__main__":
    # Example usage
    sample_maps_response = {
        "routes": [
            {
                "route_index": 0,
                "summary": "Dr Besant Rd",
                "distance": "3.3 km",
                "duration": "13 mins",
                "coordinates": [
                    {"latitude": 13.05011, "longitude": 80.28132},
                    {"latitude": 13.05069, "longitude": 80.28141}
                ]
            }
        ]
    }
    
    analysis, inference = analyze_routes_from_maps(sample_maps_response, travel_hour=14)
    print(json.dumps(analysis, indent=2))
