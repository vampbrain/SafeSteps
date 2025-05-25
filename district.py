import json
import csv
import numpy as np
from scipy.interpolate import Rbf
from shapely.geometry import shape, Point, LineString
import googlemaps
from datetime import datetime
import folium
from sklearn.neighbors import KernelDensity
import google.generativeai as genai
import textwrap
import requests

class CrimeAwareRouter:
    def __init__(self, geojson_path, crime_csv_path, google_maps_api_key, gemini_api_key):
        self.gmaps = googlemaps.Client(key=google_maps_api_key)
        self.districts = self._load_geojson(geojson_path)
        self.crime_data = self._load_crime_data(crime_csv_path)
        self.gemini_api_key = gemini_api_key
        
        # Configure Gemini
        genai.configure(api_key=gemini_api_key)
        self.safety_model = genai.GenerativeModel('gemini-1.5-flash')
        
        # Crime type weights (customizable)
        self.crime_weights = {
            'MURDER': 10,
            'RAPE': 8,
            'DACOITY': 7,
            'ROBBERY': 6,
            'BURGLARY-NIGHT': 5,
            'THEFT': 3,
            'MOLESTATION': 6,
            'FATAL_MOTOR_ACCIDENTS': 4
        }
        
        # Time-based multipliers
        self.time_multipliers = {
            'day': {'THEFT': 0.8, 'BURGLARY-NIGHT': 0.5},
            'evening': {'THEFT': 1.2, 'ROBBERY': 1.3},
            'night': {'BURGLARY-NIGHT': 1.8, 'ROBBERY': 1.5}
        }
        self._create_crime_heatmaps()

    def _load_geojson(self, path):
        """Load and parse GeoJSON file."""
        with open(path) as f:
            data = json.load(f)
        
        districts = {}
        for feature in data['features']:
            district_name = feature['properties']['NAME_2']
            geometry = shape(feature['geometry'])
            districts[district_name] = {
                'geometry': geometry,
                'centroid': geometry.centroid
            }
        return districts

    def _load_crime_data(self, path):
        """Load crime statistics from CSV file."""
        crime_data = {}
        with open(path, mode='r', encoding='utf-8-sig') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                district = row['DISTRICT/UNITS'].replace(' City', '').replace(' Dist', '').strip()
                if district in self.districts:
                    crime_data[district] = {
                        'MURDER': int(row['MURDER']),
                        'RAPE': int(row['RAPE']),
                        'DACOITY': int(row['DACOITY']),
                        'ROBBERY': int(row['ROBBERY']),
                        'BURGLARY-NIGHT': int(row['BURGLARY-NIGHT']),
                        'THEFT': int(row['THEFT']),
                        'MOLESTATION': int(row['MOLESTATION']),
                        'FATAL_MOTOR_ACCIDENTS': int(row['FATAL MOTOR ACCIDENTS'])
                    }
        return crime_data

    def _call_gemini_api(self, prompt):
        """Make direct API call to Gemini Flash 2.0"""
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={self.gemini_api_key}"
        headers = {'Content-Type': 'application/json'}
        data = {
            "contents": [{
                "parts": [{
                    "text": prompt
                }]
            }]
        }
        
        try:
            response = requests.post(url, headers=headers, json=data)
            response.raise_for_status()
            return response.json()['candidates'][0]['content']['parts'][0]['text']
        except Exception as e:
            print(f"Error calling Gemini API: {str(e)}")
            return None

    def generate_route_explanation(self, route_data, time_of_day):
        """Generate AI explanation for the recommended route"""
        prompt = textwrap.dedent(f"""
        You're a safety-focused navigation assistant. Explain this route recommendation to a user:
        
        - Current time: {time_of_day}
        - Total distance: {route_data['distance']:.1f} km
        - Estimated duration: {route_data['duration']:.1f} minutes
        - Safety score: {route_data['risk_score']:.1f} (lower is safer)
        - Main risk factors: {', '.join(route_data['top_risk_factors'])}
        
        Provide a concise 2-3 sentence explanation focusing on:
        1. Why this route was chosen
        2. Time-specific safety considerations
        3. Any notable risk areas
        Use friendly, conversational tone.
        """)
        
        try:
            response = self.safety_model.generate_content(prompt)
            return response.text
        except Exception as e:
            print(f"SDK failed, trying direct API: {str(e)}")
            api_response = self._call_gemini_api(prompt)
            return api_response or f"Safety tip: This route was chosen for its lower risk profile during {time_of_day}."

    def _create_crime_heatmaps(self):
        """Generate crime density heatmaps for each district."""
        for district, data in self.districts.items():
            if district not in self.crime_data:
                continue
                
            polygon = data['geometry']
            minx, miny, maxx, maxy = polygon.bounds
            x = np.linspace(minx, maxx, 50)
            y = np.linspace(miny, maxy, 50)
            xx, yy = np.meshgrid(x, y)
            points = np.column_stack([xx.ravel(), yy.ravel()])
            
            mask = [polygon.contains(Point(p)) for p in points]
            valid_points = points[mask]
            
            data['crime_heatmaps'] = {}
            for crime_type in self.crime_weights.keys():
                if crime_type in self.crime_data[district]:
                    kde = KernelDensity(bandwidth=0.02, kernel='gaussian')
                    kde.fit(valid_points)
                    data['crime_heatmaps'][crime_type] = kde

    def _get_location_risk_score(self, point, time_of_day='day'):
        """Calculate risk score for a specific location."""
        point = Point(point)
        total_risk = 0
        
        for district, data in self.districts.items():
            if district in self.crime_data and data['geometry'].contains(point):
                for crime_type, kde in data['crime_heatmaps'].items():
                    density = np.exp(kde.score_samples([[point.x, point.y]]))[0]
                    risk = density * self.crime_weights[crime_type]
                    
                    if time_of_day in self.time_multipliers:
                        if crime_type in self.time_multipliers[time_of_day]:
                            risk *= self.time_multipliers[time_of_day][crime_type]
                    
                    total_risk += risk
                break
                
        return total_risk

    def get_route_alternatives(self, origin, destination, mode="driving"):
        """Fetch route alternatives from Google Maps."""
        now = datetime.now()
        routes = self.gmaps.directions(
            origin, destination, 
            mode=mode, 
            alternatives=True, 
            departure_time=now
        )
        return routes

    def score_route(self, route, time_of_day='day'):
        """Calculate safety score for a route."""
        polyline = route['overview_polyline']['points']
        coords = self._decode_polyline(polyline)
        
        total_risk = 0
        segment_scores = []
        
        for i in range(len(coords)-1):
            start = coords[i]
            end = coords[i+1]
            
            num_points = max(5, int(LineString([start, end]).length * 1000 / 50))
            x = np.linspace(start[0], end[0], num_points)
            y = np.linspace(start[1], end[1], num_points)
            
            segment_risk = 0
            for lat, lng in zip(x, y):
                risk = self._get_location_risk_score((lng, lat), time_of_day)
                segment_risk += risk
            
            avg_segment_risk = segment_risk / num_points
            total_risk += avg_segment_risk * LineString([start, end]).length
            segment_scores.append({
                'start': start,
                'end': end,
                'risk': avg_segment_risk,
                'distance': LineString([start, end]).length
            })
        
        return {
            'total_risk': total_risk,
            'segment_scores': segment_scores,
            'normalized_risk': total_risk / sum(s['distance'] for s in segment_scores) if segment_scores else 0
        }

    @staticmethod
    def _decode_polyline(polyline_str):
        """Decode Google Maps polyline string into coordinates."""
        index, lat, lng = 0, 0, 0
        coordinates = []
        changes = {'latitude': 0, 'longitude': 0}
        
        while index < len(polyline_str):
            for unit in ['latitude', 'longitude']:
                shift, result = 0, 0
                
                while True:
                    byte = ord(polyline_str[index]) - 63
                    index += 1
                    result |= (byte & 0x1f) << shift
                    shift += 5
                    if not byte >= 0x20:
                        break
                
                if (result & 1):
                    changes[unit] = ~(result >> 1)
                else:
                    changes[unit] = (result >> 1)
            
            lat += changes['latitude']
            lng += changes['longitude']
            coordinates.append((lat / 100000.0, lng / 100000.0))
        
        return coordinates

    def recommend_safest_route(self, origin, destination, time_of_day=None):
        """Find and return the safest route with AI explanations."""
        if time_of_day is None:
            hour = datetime.now().hour
            if 6 <= hour < 12: time_of_day = 'day'
            elif 12 <= hour < 18: time_of_day = 'evening'
            else: time_of_day = 'night'
        
        routes = self.get_route_alternatives(origin, destination)
        if not routes:
            return []
            
        scored_routes = []
        
        for route in routes:
            score = self.score_route(route, time_of_day)
            polyline = route['overview_polyline']['points']
            coordinates = self._decode_polyline(polyline)
            
            route_districts = set()
            for coord in coordinates:
                point = Point(coord[1], coord[0])
                for district, data in self.districts.items():
                    if data['geometry'].contains(point):
                        route_districts.add(district)
                        break
            
            top_risks = []
            for district in route_districts:
                if district in self.crime_data:
                    district_risks = sorted(
                        [(k, v) for k, v in self.crime_data[district].items()],
                        key=lambda x: x[1],
                        reverse=True
                    )[:3]
                    top_risks.extend(district_risks)
            
            unique_risks = {}
            for risk in top_risks:
                if risk[0] not in unique_risks or risk[1] > unique_risks[risk[0]]:
                    unique_risks[risk[0]] = risk[1]
            top_3_risks = sorted(unique_risks.items(), key=lambda x: x[1], reverse=True)[:3]
            
            scored_routes.append({
                'route': route,
                'coordinates': [[coord[0], coord[1]] for coord in coordinates],  # Format as [lat, lng]
                'risk_score': score['normalized_risk'],
                'total_risk': score['total_risk'],
                'distance': route['legs'][0]['distance']['value'] / 1000,
                'duration': route['legs'][0]['duration']['value'] / 60,
                'segment_scores': score['segment_scores'],
                'time_of_day': time_of_day,
                'top_risk_factors': [risk[0] for risk in top_3_risks],
                'polyline': polyline
            })
        
        scored_routes.sort(key=lambda x: (x['risk_score'], x['duration']))
        
        if scored_routes:
            scored_routes[0]['ai_explanation'] = self.generate_route_explanation(
                scored_routes[0], 
                time_of_day
            )
            
            for alt_route in scored_routes[1:]:
                alt_route['ai_explanation'] = self.generate_route_explanation(
                    alt_route,
                    time_of_day
                )
        
        return scored_routes

    def get_routes_as_json(self, origin, destination, time_of_day=None):
        """Get routes and return as JSON string with coordinates."""
        routes = self.recommend_safest_route(origin, destination, time_of_day)
        
        if not routes:
            return json.dumps({"error": "No routes found"}, indent=2)
        
        json_output = {
            'recommended_route': {
                'coordinates': routes[0]['coordinates'],
                'risk_score': round(routes[0]['risk_score'], 2),
                'distance_km': round(routes[0]['distance'], 2),
                'duration_minutes': round(routes[0]['duration'], 1),
                'time_of_day': routes[0]['time_of_day'],
                'top_risk_factors': routes[0]['top_risk_factors'],
                'ai_explanation': routes[0]['ai_explanation'],
                'polyline': routes[0]['polyline']
            },
            'alternatives': []
        }
        
        for alt_route in routes[1:]:
            json_output['alternatives'].append({
                'coordinates': alt_route['coordinates'],
                'risk_score': round(alt_route['risk_score'], 2),
                'distance_km': round(alt_route['distance'], 2),
                'duration_minutes': round(alt_route['duration'], 1),
                'time_of_day': alt_route['time_of_day'],
                'top_risk_factors': alt_route['top_risk_factors'],
                'ai_explanation': alt_route['ai_explanation'],
                'polyline': alt_route['polyline']
            })
        
        return json.dumps(json_output, indent=2)

    def save_routes_to_file(self, origin, destination, filename="routes.json", time_of_day=None):
        """Save routes to JSON file."""
        json_data = self.get_routes_as_json(origin, destination, time_of_day)
        with open(filename, 'w') as f:
            f.write(json_data)
        print(f"Routes saved to {filename}")
        return json_data

# Example Usage
if __name__ == "__main__":
    # Initialize with your paths and API keys
    router = CrimeAwareRouter(
        geojson_path="karnataka.geojson",
        crime_csv_path="ka_ipc_crimes_district_2024.csv",
        google_maps_api_key="AIzaSyCroP5ArTzF4g5GmZdr7ml9KDlRviEQfbE",
        gemini_api_key="AIzaSyCwS7Io4cLw0LOQIPREdQVsUwqIuEf0x0g"
    )
    
    # Get route recommendations and convert to JSON
    routes = router.recommend_safest_route("Bengaluru", "Mysuru")
    
    if routes:
        # Convert to JSON with coordinates
        json_output = router.get_routes_as_json("Bengaluru", "Mysuru")
        print(json_output)
        
        # Save to file
        router.save_routes_to_file("Bengaluru", "Mysuru", "bengaluru_mysuru_routes.json")
        
        # Print summary
        print(f"\nRecommended Route Summary:")
        print(f"Risk Score: {routes[0]['risk_score']:.2f}")
        print(f"Distance: {routes[0]['distance']:.1f} km")
        print(f"Duration: {routes[0]['duration']:.1f} min")
        print(f"Coordinates: {len(routes[0]['coordinates'])} points")
    else:
        print("No routes found between the specified locations.")
