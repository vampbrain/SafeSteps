from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import os
import sys
from datetime import datetime

# Add the data directory to Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
data_dir = os.path.join(current_dir, 'data')
sys.path.append(data_dir)

try:
    from route_safety_inference import analyze_routes_from_maps
    from frontend_integration import FrontendAPI
    ML_AVAILABLE = True
    print("✅ ML modules loaded successfully!")
except ImportError as e:
    print(f"⚠️  Warning: Could not load ML modules: {e}")
    print("🔄 Running in fallback mode...")
    ML_AVAILABLE = False

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app

# Initialize the frontend API if available
if ML_AVAILABLE:
    try:
        frontend_api = FrontendAPI()
        print("✅ Frontend API initialized!")
    except Exception as e:
        print(f"⚠️  Warning: Could not initialize Frontend API: {e}")
        ML_AVAILABLE = False

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'SafeSteps ML API',
        'ml_available': ML_AVAILABLE,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/analyze_routes', methods=['POST'])
def analyze_routes():
    """Main endpoint for route analysis"""
    try:
        # Get data from Flutter app
        data = request.json
        
        if not data or 'routes' not in data:
            return jsonify({'error': 'Invalid request data'}), 400
        
        if ML_AVAILABLE:
            # Extract travel hour (default to current hour if not provided)
            travel_hour = data.get('travel_hour', datetime.now().hour)
            
            # Process using your existing ML model
            frontend_response = frontend_api.process_maps_request(data, travel_hour=travel_hour)
            return jsonify(frontend_response)
        else:
            # Fallback analysis
            return fallback_analysis(data)
        
    except Exception as e:
        print(f"Error in analyze_routes: {str(e)}")
        return jsonify({
            'error': 'Internal server error',
            'message': str(e)
        }), 500

def fallback_analysis(data):
    """Fallback analysis when ML is not available"""
    routes = data.get('routes', [])
    
    if not routes:
        return jsonify({'error': 'No routes provided'}), 400
    
    # Simple analysis based on distance and duration
    best_route = None
    best_score = float('inf')
    
    for route in routes:
        # Calculate simple score based on distance and duration
        distance_val = route.get('distance_value', 1000000)
        duration_val = route.get('duration_value', 1000000)
        score = (distance_val * 0.6) + (duration_val * 0.4)
        
        if score < best_score:
            best_score = score
            best_route = route
    
    if not best_route:
        best_route = routes[0]  # Default to first route
    
    return {
        'status': 'success',
        'total_routes': len(routes),
        'recommended_route': {
            'route_index': best_route.get('route_index', 0),
            'summary': best_route.get('summary', 'Route'),
            'safety_score': 7.0,  # Default score
            'crime_risk_level': 'Medium',
            'distance': best_route.get('distance', 'Unknown'),
            'duration': best_route.get('duration', 'Unknown')
        },
        'analysis_summary': {
            'confidence': 0.7,
            'analysis_type': 'fallback',
            'factors_considered': [
                'Distance optimization',
                'Duration optimization',
                'Basic route comparison'
            ]
        },
        'timestamp': datetime.now().isoformat()
    }

@app.route('/quick_analysis', methods=['POST'])
def quick_analysis():
    """Simplified endpoint for basic route comparison"""
    try:
        data = request.json
        routes = data.get('routes', [])
        
        if not routes:
            return jsonify({'error': 'No routes provided'}), 400
        
        # Simple analysis based on distance and duration
        best_route = min(routes, key=lambda r: r.get('distance_value', float('inf')))
        
        return jsonify({
            'status': 'success',
            'recommended_route': {
                'route_index': best_route.get('route_index', 0),
                'summary': best_route.get('summary', 'Route'),
                'safety_score': 7.5,  # Default score
                'crime_risk_level': 'Low'
            },
            'confidence': 0.8,
            'analysis_type': 'quick'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/model_info', methods=['GET'])
def model_info():
    """Get information about the ML model"""
    return jsonify({
        'model_name': 'Bengaluru Route Safety Model',
        'version': '1.0',
        'ml_available': ML_AVAILABLE,
        'features': [
            'Crime density analysis',
            'Time-based safety scoring',
            'Route optimization',
            'Risk level assessment'
        ],
        'data_source': 'Karnataka IPC Crimes District 2024',
        'last_updated': datetime.now().isoformat()
    })

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    # Check if model files exist
    model_path = os.path.join(data_dir, 'bengaluru_route_safety_model.pkl')
    
    if os.path.exists(model_path):
        print("✅ Model file found!")
    else:
        print(f"⚠️  Warning: Model file not found at {model_path}")
        print("🔄 API will run in fallback mode")
    
    print("🚀 Starting SafeSteps ML API...")
    print("📍 Endpoints available:")
    print("  - GET  /health - Health check")
    print("  - POST /analyze_routes - Full ML analysis")
    print("  - POST /quick_analysis - Quick route comparison")
    print("  - GET  /model_info - Model information")
    print(f"🔧 ML Mode: {'Enabled' if ML_AVAILABLE else 'Fallback Only'}")
    
    # Run the Flask app
    app.run(
        host='0.0.0.0',  # Allow external connections
        port=5000,
        debug=True
    )