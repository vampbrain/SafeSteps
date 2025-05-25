# test_inference.py
import json
from package_model import create_model_package
from route_safety_inference import analyze_routes_from_maps
from frontend_integration import FrontendAPI

def test_complete_pipeline():
    """Test the complete pipeline"""
    
    # Step 1: Create model package (run once)
    print("🚀 Step 1: Creating model package...")
    model = create_model_package("ka_ipc_crimes_district_2024.csv")
    
    # Step 2: Test with sample maps response
    print("\n🔍 Step 2: Testing inference...")
    
    sample_maps_response = {
        "timestamp": "2025-05-22T14:53:50.889209",
        "total_routes": 3,
        "routes": [
            {
                "route_index": 0,
                "summary": "Hosur Road (Direct)",
                "distance": "18.0 km",
                "duration": "35 mins",
                "coordinates": [
                    {"latitude": 12.97, "longitude": 77.59},
                    {"latitude": 12.95, "longitude": 77.61},
                    {"latitude": 12.93, "longitude": 77.63},
                    {"latitude": 12.91, "longitude": 77.65},
                    {"latitude": 12.89, "longitude": 77.67}
                ]
            },
            {
                "route_index": 1,
                "summary": "Outer Ring Road",
                "distance": "22.0 km", 
                "duration": "42 mins",
                "coordinates": [
                    {"latitude": 12.97, "longitude": 77.59},
                    {"latitude": 12.99, "longitude": 77.62},
                    {"latitude": 13.01, "longitude": 77.65},
                    {"latitude": 12.95, "longitude": 77.68},
                    {"latitude": 12.89, "longitude": 77.67}
                ]
            },
            {
                "route_index": 2,
                "summary": "Bannerghatta Road",
                "distance": "25.0 km",
                "duration": "50 mins", 
                "coordinates": [
                    {"latitude": 12.97, "longitude": 77.59},
                    {"latitude": 12.94, "longitude": 77.58},
                    {"latitude": 12.91, "longitude": 77.60},
                    {"latitude": 12.88, "longitude": 77.65},
                    {"latitude": 12.89, "longitude": 77.67}
                ]
            }
        ]
    }
    
    # Analyze routes
    analysis, inference = analyze_routes_from_maps(sample_maps_response, travel_hour=14)
    
    # Print results
    print("\n📊 Analysis Results:")
    print(f"Total routes analyzed: {analysis['total_routes']}")
    print(f"Recommended route: {analysis['recommended_route']['summary']}")
    print(f"Safety score: {analysis['recommended_route']['safety_score']}/10")
    
    # Step 3: Test frontend integration
    print("\n🎨 Step 3: Testing frontend integration...")
    
    frontend_api = FrontendAPI()
    frontend_response = frontend_api.process_maps_request(sample_maps_response, travel_hour=14)
    
    # Save results
    with open('route_analysis_result.json', 'w') as f:
        json.dump(analysis, f, indent=2)
    
    with open('frontend_response.json', 'w') as f:
        json.dump(frontend_response, f, indent=2)
    
    print("✅ Test completed successfully!")
    print("📁 Files created:")
    print("  - bengaluru_route_safety_model.pkl (model package)")
    print("  - route_analysis_result.json (detailed analysis)")
    print("  - frontend_response.json (frontend-ready format)")
    
    return analysis, frontend_response

if __name__ == "__main__":
    test_complete_pipeline()
