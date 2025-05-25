import json
from route_safety_inference import RouteSafetyInference

class FrontendAPI:
    def __init__(self, model_path="bengaluru_route_safety_model.pkl"):
        """Initialize the frontend API"""
        self.inference = RouteSafetyInference(model_path)
    
    def process_maps_request(self, maps_response, travel_hour=None):
        """Process Google Maps response and return frontend-ready JSON"""
        
        # Analyze routes
        analysis = self.inference.analyze_routes(maps_response, travel_hour)
        
        # Format for frontend
        frontend_response = {
            'status': 'success',
            'timestamp': analysis['timestamp'],
            'analysis_summary': {
                'total_routes': analysis['total_routes'],
                'recommended_route_index': analysis['recommended_route']['route_index'] if analysis['recommended_route'] else None,
                'travel_hour': travel_hour
            },
            'routes': []
        }
        
        # Format each route for frontend
        for route in analysis['routes']:
            frontend_route = {
                'route_id': route['route_index'],
                'name': route['summary'],
                'distance': route['distance'],
                'duration': route['duration'],
                'safety': {
                    'risk_score': route['risk_score'],
                    'risk_category': route['risk_category'],
                    'safety_score': route['safety_score'],
                    'is_recommended': route['is_recommended']
                },
                'coordinates': [
                    {'lat': float(coord[0]), 'lng': float(coord[1])} 
                    for coord in route['coordinates']
                ],
                'style': self._get_route_style(route['risk_category'])
            }
            frontend_response['routes'].append(frontend_route)
        
        # Add insights
        frontend_response['insights'] = analysis['insights']
        
        return frontend_response
    
    def _get_route_style(self, risk_category):
        """Get map styling for different risk categories"""
        styles = {
            'LOW': {'color': '#4CAF50', 'weight': 6, 'opacity': 0.8},
            'MEDIUM': {'color': '#FF9800', 'weight': 5, 'opacity': 0.7},
            'MEDIUM-HIGH': {'color': '#FF5722', 'weight': 5, 'opacity': 0.7},
            'HIGH': {'color': '#F44336', 'weight': 4, 'opacity': 0.6}
        }
        return styles.get(risk_category, styles['MEDIUM'])
    
    def get_recommended_route_json(self, maps_response, travel_hour=None):
        """Get only the recommended route coordinates"""
        analysis = self.inference.analyze_routes(maps_response, travel_hour)
        
        if not analysis['recommended_route']:
            return {'error': 'No recommended route found'}
        
        recommended = analysis['recommended_route']
        
        return {
            'route_id': recommended['route_index'],
            'summary': recommended['summary'],
            'safety_score': recommended['safety_score'],
            'risk_category': recommended['risk_category'],
            'coordinates': [
                {'lat': float(coord[0]), 'lng': float(coord[1])} 
                for coord in recommended['coordinates']
            ]
        }

def save_analysis_to_json(analysis, filename):
    """Save analysis results to JSON file"""
    with open(filename, 'w') as f:
        json.dump(analysis, f, indent=2)
    print(f"✅ Analysis saved to {filename}")
