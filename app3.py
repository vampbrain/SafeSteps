import json
import csv
import numpy as np
import pandas as pd
from scipy.interpolate import Rbf
from scipy.spatial.distance import cdist
from shapely.geometry import shape, Point, LineString, Polygon
import googlemaps
from datetime import datetime, timedelta
import folium
from sklearn.neighbors import KernelDensity
from sklearn.cluster import DBSCAN
from sklearn.preprocessing import StandardScaler
import google.generativeai as genai
import textwrap
import logging
from typing import List, Dict, Tuple, Optional
import warnings
warnings.filterwarnings('ignore')

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EnhancedCrimeAwareRouter:
    def __init__(self, geojson_path: str, crime_csv_path: str, google_maps_api_key: str, gemini_api_key: str):
      """
      Initialize the Enhanced Crime-Aware Router
      
      Args:
          geojson_path: Path to Karnataka districts GeoJSON file
          crime_csv_path: Path to crime statistics CSV file
          google_maps_api_key: Google Maps API key
          gemini_api_key: Gemini AI API key
      """
      self.gmaps = googlemaps.Client(key=google_maps_api_key)
      self.districts = self._load_geojson(geojson_path)
      
      # MOVE THIS BEFORE _load_crime_data call
      # Enhanced crime type weights with more nuanced scoring
      self.crime_weights = {
          'MURDER': 10.0,
          'ATTEMPT TO MURDER': 8.5,
          'RAPE': 9.0,
          'DACOITY': 7.5,
          'ROBBERY': 6.5,
          'BURGLARY-DAY': 4.0,
          'BURGLARY-NIGHT': 5.5,
          'THEFT': 3.0,
          'MOLESTATION': 7.0,
          'FATAL MOTOR ACCIDENTS': 4.5,
          'NON-FATAL MOTOR ACCIDENTS': 2.0,
          'CYBER CRIME': 1.5,
          'POCSO': 8.0,
          'POCSO RAPE': 9.5
      }
      
      # Enhanced time-based multipliers with more granular time periods
      self.time_multipliers = {
          'early_morning': {  # 4-6 AM
              'BURGLARY-NIGHT': 2.0, 'THEFT': 1.8, 'ROBBERY': 1.6
          },
          'morning': {  # 6-10 AM
              'THEFT': 0.7, 'BURGLARY-DAY': 1.2, 'FATAL MOTOR ACCIDENTS': 1.3
          },
          'midday': {  # 10 AM - 2 PM
              'THEFT': 0.8, 'BURGLARY-DAY': 1.5, 'CYBER CRIME': 1.2
          },
          'afternoon': {  # 2-6 PM
              'THEFT': 1.1, 'ROBBERY': 0.9, 'FATAL MOTOR ACCIDENTS': 1.4
          },
          'evening': {  # 6-10 PM
              'THEFT': 1.3, 'ROBBERY': 1.4, 'MOLESTATION': 1.6
          },
          'night': {  # 10 PM - 2 AM
              'BURGLARY-NIGHT': 2.2, 'ROBBERY': 1.8, 'MOLESTATION': 2.0, 'MURDER': 1.5
          },
          'late_night': {  # 2-4 AM
              'BURGLARY-NIGHT': 2.5, 'MURDER': 1.8, 'ROBBERY': 2.0
          }
      }
      
      # Day of week multipliers
      self.day_multipliers = {
          'weekday': {'BURGLARY-DAY': 1.2, 'CYBER CRIME': 1.1},
          'weekend': {'ROBBERY': 1.3, 'THEFT': 1.2, 'MOLESTATION': 1.4}
      }
      
      # NOW load crime data (after crime_weights is defined)
      self.crime_data = self._load_crime_data(crime_csv_path)
      
      self.gemini_api_key = gemini_api_key
      genai.configure(api_key=gemini_api_key)
      self.safety_model = genai.GenerativeModel('gemini-1.5-flash')
      
      # Initialize crime analysis
      self._analyze_crime_patterns()
      self._create_enhanced_crime_heatmaps()
      self._identify_crime_hotspots()

    def _load_geojson(self, path: str) -> Dict:
        """Load and process GeoJSON data with error handling"""
        try:
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            districts = {}
            for feature in data['features']:
                district_name = feature['properties'].get('NAME_2', 
                    feature['properties'].get('district', 
                    feature['properties'].get('name', 'Unknown')))
                geometry = shape(feature['geometry'])
                districts[district_name] = {
                    'geometry': geometry,
                    'centroid': geometry.centroid,
                    'bounds': geometry.bounds,
                    'area': geometry.area
                }
            
            logger.info(f"Loaded {len(districts)} districts from GeoJSON")
            return districts
        except Exception as e:
            logger.error(f"Error loading GeoJSON: {e}")
            raise

    def _load_crime_data(self, path: str) -> Dict:
        """Load and clean crime statistics with enhanced processing"""
        try:
            df = pd.read_csv(path, encoding='utf-8-sig')
            crime_data = {}
            
            for _, row in df.iterrows():
                district_raw = str(row['DISTRICT/UNITS'])
                
                # Clean district names more thoroughly
                district = (district_raw
                           .replace(' City', '')
                           .replace(' Dist', '')
                           .replace('Commissionerates', '')
                           .replace('Range', '')
                           .strip())
                
                # Skip header rows and empty entries
                if district in ['', 'nan'] or district.isdigit():
                    continue
                
                # Find matching district in GeoJSON (case-insensitive matching)
                matched_district = None
                for geo_district in self.districts.keys():
                    if (district.lower() in geo_district.lower() or 
                        geo_district.lower() in district.lower()):
                        matched_district = geo_district
                        break
                
                if matched_district:
                    crime_data[matched_district] = {}
                    for crime_type in self.crime_weights.keys():
                        # Handle different column name formats
                        col_name = crime_type
                        if col_name not in row:
                            col_name = crime_type.replace('_', ' ')
                        if col_name not in row:
                            col_name = crime_type.replace('-', ' ')
                        
                        try:
                            value = pd.to_numeric(row.get(col_name, 0), errors='coerce')
                            crime_data[matched_district][crime_type] = max(0, value or 0)
                        except:
                            crime_data[matched_district][crime_type] = 0
            
            logger.info(f"Loaded crime data for {len(crime_data)} districts")
            return crime_data
        except Exception as e:
            logger.error(f"Error loading crime data: {e}")
            raise

    def _analyze_crime_patterns(self):
        """Analyze crime patterns to identify trends and correlations"""
        self.crime_stats = {}
        
        for district, crimes in self.crime_data.items():
            total_crimes = sum(crimes.values())
            violent_crimes = sum([crimes.get(ct, 0) for ct in 
                                ['MURDER', 'ATTEMPT TO MURDER', 'RAPE', 'ROBBERY', 'MOLESTATION']])
            property_crimes = sum([crimes.get(ct, 0) for ct in 
                                 ['BURGLARY-DAY', 'BURGLARY-NIGHT', 'THEFT']])
            
            self.crime_stats[district] = {
                'total_crimes': total_crimes,
                'violent_crimes': violent_crimes,
                'property_crimes': property_crimes,
                'crime_rate': total_crimes / self.districts[district]['area'] if self.districts[district]['area'] > 0 else 0,
                'violence_ratio': violent_crimes / total_crimes if total_crimes > 0 else 0
            }

    def _create_enhanced_crime_heatmaps(self):
        """Generate sophisticated crime density maps using multiple techniques"""
        for district, data in self.districts.items():
            if district not in self.crime_data:
                continue
                
            polygon = data['geometry']
            minx, miny, maxx, maxy = polygon.bounds
            
            # Create higher resolution grid
            resolution = 100
            x = np.linspace(minx, maxx, resolution)
            y = np.linspace(miny, maxy, resolution)
            xx, yy = np.meshgrid(x, y)
            grid_points = np.column_stack([xx.ravel(), yy.ravel()])
            
            # Filter points within district
            valid_mask = np.array([polygon.contains(Point(p)) for p in grid_points])
            valid_points = grid_points[valid_mask]
            
            if len(valid_points) == 0:
                continue
            
            # Generate synthetic crime locations based on real data
            crime_locations = self._generate_synthetic_crime_locations(district, valid_points)
            
            data['crime_heatmaps'] = {}
            data['crime_locations'] = crime_locations
            
            # Create KDE for each crime type
            for crime_type, locations in crime_locations.items():
                if len(locations) > 0:
                    # Adaptive bandwidth based on data density
                    n_points = len(locations)
                    bandwidth = max(0.005, min(0.02, 0.1 / np.sqrt(n_points)))
                    
                    try:
                        kde = KernelDensity(bandwidth=bandwidth, kernel='gaussian')
                        # Convert locations to numpy array with proper shape
                        locations_array = np.array(locations)
                        if locations_array.ndim == 1:
                            locations_array = locations_array.reshape(-1, 2)
                        
                        kde.fit(locations_array)
                        data['crime_heatmaps'][crime_type] = kde
                    except Exception as e:
                        logger.warning(f"Failed to create KDE for {crime_type} in {district}: {e}")
                        continue

    def _generate_synthetic_crime_locations(self, district: str, valid_points: np.ndarray) -> Dict:
        """Generate realistic synthetic crime locations to avoid overfitting"""
        crime_locations = {}
        crimes = self.crime_data[district]
        
        # Urban vs rural classification based on district characteristics
        is_urban = any(city in district.lower() for city in ['city', 'bengaluru', 'mysuru', 'hubballi'])
        
        for crime_type, count in crimes.items():
            if count == 0 or not isinstance(count, (int, float)):
                crime_locations[crime_type] = []
                continue
            
            # Convert count to integer
            count = int(count)
            
            # Determine distribution pattern based on crime type and area type
            if crime_type in ['THEFT', 'BURGLARY-DAY', 'CYBER CRIME']:
                # These tend to cluster in commercial/urban areas
                n_clusters = max(1, min(5, count // 10))
                pattern = 'clustered'
            elif crime_type in ['MURDER', 'RAPE', 'DACOITY']:
                # These might be more dispersed
                n_clusters = max(1, min(3, count // 15))
                pattern = 'semi_random'
            else:
                # Mixed pattern
                n_clusters = max(1, min(4, count // 12))
                pattern = 'mixed'
            
            locations = self._generate_crime_pattern(valid_points, count, n_clusters, pattern, is_urban)
            crime_locations[crime_type] = locations
        
        
        if sum(crimes.values()) > 500:
            extra_points = self._generate_crime_pattern(valid_points, 30, 2, 'clustered', is_urban=True)
            for crime_type in crime_locations:
                crime_locations[crime_type].extend(extra_points)
        return crime_locations
        

    def _generate_crime_pattern(self, valid_points: np.ndarray, count: int, n_clusters: int, 
                              pattern: str, is_urban: bool) -> List[Tuple]:
        """Generate crime locations following realistic spatial patterns"""
        if len(valid_points) == 0 or count <= 0:
            return []
        
        locations = []
        # Ensure integer division
        points_per_cluster = max(1, int(count // n_clusters))
        
        for cluster_idx in range(n_clusters):
            # Select cluster center
            center_idx = np.random.randint(0, len(valid_points))
            center = valid_points[center_idx]
            
            # Generate points around center - ensure integer
            try:
                poisson_sample = np.random.poisson(2)
                cluster_size = points_per_cluster + int(poisson_sample)
            except:
                cluster_size = points_per_cluster + 2
            
            for point_idx in range(min(cluster_size, count - len(locations))):
                try:
                    if pattern == 'clustered':
                        # Tight clustering (urban crime hotspots)
                        spread = 0.005 if is_urban else 0.01
                        offset = np.random.normal(0, spread, 2)
                    elif pattern == 'semi_random':
                        # Moderate dispersion
                        spread = 0.01 if is_urban else 0.02
                        offset = np.random.normal(0, spread, 2)
                    else:  # mixed
                        # Variable clustering
                        spread = np.random.choice([0.005, 0.015], p=[0.7, 0.3])
                        offset = np.random.normal(0, spread, 2)
                    
                    new_point = center + offset
                    
                    # Simple bounds check instead of expensive containment check
                    if (len(valid_points) > 0 and 
                        new_point[0] >= np.min(valid_points[:, 0]) and 
                        new_point[0] <= np.max(valid_points[:, 0]) and
                        new_point[1] >= np.min(valid_points[:, 1]) and 
                        new_point[1] <= np.max(valid_points[:, 1])):
                        locations.append(tuple(new_point))
                    
                except Exception as e:
                    logger.warning(f"Error generating crime point: {e}")
                    continue
                
                if len(locations) >= count:
                    break
            
            if len(locations) >= count:
                break
        
        return locations

    def _identify_crime_hotspots(self):
        """Identify crime hotspots using clustering analysis"""
        self.crime_hotspots = {}
        
        for district, data in self.districts.items():
            if 'crime_locations' not in data:
                continue
            
            all_locations = []
            crime_weights = []
            
            for crime_type, locations in data['crime_locations'].items():
                for loc in locations:
                    all_locations.append(loc)
                    crime_weights.append(self.crime_weights.get(crime_type, 1.0))
            
            if len(all_locations) < 5:
                continue
            
            # Apply DBSCAN clustering to identify hotspots
            locations_array = np.array(all_locations)
            scaler = StandardScaler()
            scaled_locations = scaler.fit_transform(locations_array)
            
            clustering = DBSCAN(eps=0.5, min_samples=3).fit(scaled_locations, sample_weight=crime_weights)
            
            hotspots = []
            for cluster_id in set(clustering.labels_):
                if cluster_id == -1:  # Noise points
                    continue
                
                cluster_mask = clustering.labels_ == cluster_id
                cluster_points = locations_array[cluster_mask]
                cluster_weights = np.array(crime_weights)[cluster_mask]
                
                # Calculate hotspot center (weighted centroid)
                center = np.average(cluster_points, axis=0, weights=cluster_weights)
                intensity = np.sum(cluster_weights)
                radius = np.max(cdist([center], cluster_points)[0])
                
                hotspots.append({
                    'center': tuple(center),
                    'intensity': intensity,
                    'radius': radius,
                    'crime_count': len(cluster_points)
                })
            
            self.crime_hotspots[district] = sorted(hotspots, key=lambda x: x['intensity'], reverse=True)

    def _get_time_period(self, hour: int) -> str:
        """Get more granular time period classification"""
        if 4 <= hour < 6:
            return 'early_morning'
        elif 6 <= hour < 10:
            return 'morning'
        elif 10 <= hour < 14:
            return 'midday'
        elif 14 <= hour < 18:
            return 'afternoon'
        elif 18 <= hour < 22:
            return 'evening'
        elif 22 <= hour < 2:
            return 'night'
        else:  # 2-4 AM
            return 'late_night'

    def _get_enhanced_location_risk_score(self, point: Tuple, datetime_obj: datetime) -> float:
        """Calculate comprehensive risk score with temporal and spatial factors"""
        point_geom = Point(point)
        total_risk = 0
        
        # Time-based factors
        time_period = self._get_time_period(datetime_obj.hour)
        is_weekend = datetime_obj.weekday() >= 5
        day_type = 'weekend' if is_weekend else 'weekday'
        
        # Find containing district
        containing_district = None
        for district, data in self.districts.items():
            if data['geometry'].contains(point_geom):
                containing_district = district
                break
        
        if not containing_district or containing_district not in self.crime_data:
            return 0
        
        district_data = self.districts[containing_district]
        
        # Base crime density score
        for crime_type, kde in district_data.get('crime_heatmaps', {}).items():
            try:
                density = np.exp(kde.score_samples([[point[1], point[0]]]))[0]  # lon, lat
                base_risk = density * self.crime_weights[crime_type]
                
                # Apply temporal multipliers
                time_multiplier = self.time_multipliers.get(time_period, {}).get(crime_type, 1.0)
                day_multiplier = self.day_multipliers.get(day_type, {}).get(crime_type, 1.0)
                
                total_risk += base_risk * time_multiplier * day_multiplier
            except:
                continue
        
        # Hotspot proximity penalty
        hotspots = self.crime_hotspots.get(containing_district, [])
        for hotspot in hotspots:
            distance = Point(point).distance(Point(hotspot['center']))
            if distance < hotspot['radius']:
                proximity_factor = 1 - (distance / hotspot['radius'])
                total_risk += hotspot['intensity'] * proximity_factor * 0.1
        
        # District-level risk factors
        district_stats = self.crime_stats.get(containing_district, {})
        district_risk_factor = 1 + (district_stats.get('violence_ratio', 0) * 0.5)
        
        if total_risk < 1e-4:
            fallback_noise = self._pseudo_spatial_noise(point) * 0.5 + 0.3  # range ~0.3 to 0.8
            total_risk = fallback_noise
        return total_risk * district_risk_factor * self._pseudo_spatial_noise(point)

    def get_enhanced_route_alternatives(self, origin: str, destination: str, 
                                      mode: str = "driving", max_routes: int = 5) -> List:
        """Get multiple route alternatives with different optimization preferences"""
        routes = []
        
        try:
            # Standard routes
            standard_routes = self.gmaps.directions(
                origin, destination, 
                mode=mode, 
                alternatives=True,
                departure_time=datetime.now()
            )
            routes.extend(standard_routes)
            
            # Try different route preferences
            preferences = ['avoid_highways', 'avoid_tolls']
            for avoid in preferences:
                try:
                    alt_routes = self.gmaps.directions(
                        origin, destination,
                        mode=mode,
                        alternatives=True,
                        avoid=[avoid],
                        departure_time=datetime.now()
                    )
                    for route in alt_routes:
                        # Check if this is a significantly different route
                        is_unique = True
                        for existing_route in routes:
                            if self._routes_similar(route, existing_route):
                                is_unique = False
                                break
                        if is_unique:
                            routes.append(route)
                except:
                    continue
            
            # Limit to max_routes to avoid excessive processing
            return routes[:max_routes]
            
        except Exception as e:
            logger.error(f"Error fetching routes: {e}")
            return []

    def _routes_similar(self, route1: Dict, route2: Dict, threshold: float = 0.8) -> bool:
        """Check if two routes are similar based on overlapping waypoints"""
        coords1 = self._decode_polyline(route1['overview_polyline']['points'])
        coords2 = self._decode_polyline(route2['overview_polyline']['points'])
        
        # Sample points from both routes
        sample_size = min(20, len(coords1), len(coords2))
        sampled1 = [coords1[i] for i in np.linspace(0, len(coords1)-1, sample_size, dtype=int)]
        sampled2 = [coords2[i] for i in np.linspace(0, len(coords2)-1, sample_size, dtype=int)]
        
        # Calculate similarity based on minimum distances
        distances = cdist(sampled1, sampled2)
        min_distances = np.min(distances, axis=1)
        similarity = np.mean(min_distances < 0.01)  # Within ~1km
        
        return similarity > threshold

    def score_route_enhanced(self, route: Dict, travel_datetime: datetime) -> Dict:
        """Enhanced route scoring with comprehensive risk analysis"""
        polyline = route['overview_polyline']['points']
        coords = self._decode_polyline(polyline)
        
        if len(coords) < 2:
            return {'total_risk': 0, 'segment_scores': [], 'normalized_risk': 0}
        
        segment_scores = []
        total_risk = 0
        total_distance = 0
        
        # Analyze route in segments
        for i in range(len(coords) - 1):
            start_coord = coords[i]
            end_coord = coords[i + 1]
            
            segment_line = LineString([start_coord, end_coord])
            segment_length = segment_line.length
            
            # Sample points along segment
            num_samples = max(3, int(segment_length * 1000))  # ~1 sample per km
            
            segment_risk = 0
            for j in range(num_samples):
                t = j / (num_samples - 1) if num_samples > 1 else 0
                sample_point = (
                    start_coord[0] + t * (end_coord[0] - start_coord[0]),
                    start_coord[1] + t * (end_coord[1] - start_coord[1])
                )
                
                point_risk = self._get_enhanced_location_risk_score(sample_point, travel_datetime)
                segment_risk += point_risk
            
            avg_segment_risk = segment_risk / num_samples
            weighted_risk = avg_segment_risk * segment_length
            
            segment_scores.append({
                'start': start_coord,
                'end': end_coord,
                'risk': avg_segment_risk,
                'distance': segment_length,
                'weighted_risk': weighted_risk
            })
            
            total_risk += weighted_risk
            total_distance += segment_length
        
        normalized_risk = total_risk / total_distance if total_distance > 0 else 0
        
        return {
            'total_risk': total_risk,
            'segment_scores': segment_scores,
            'normalized_risk': normalized_risk,
            'max_segment_risk': max([s['risk'] for s in segment_scores]) if segment_scores else 0,
            'risk_variance': np.var([s['risk'] for s in segment_scores]) if len(segment_scores) > 1 else 0
        }

    def recommend_safest_route(self, origin: str, destination: str, 
                             travel_datetime: Optional[datetime] = None) -> List[Dict]:
        """
        Comprehensive route recommendation with enhanced safety analysis
        
        Args:
            origin: Starting location
            destination: Target location  
            travel_datetime: Planned travel time (defaults to now)
            
        Returns:
            List of route options ranked by safety with detailed analysis
        """
        if travel_datetime is None:
            travel_datetime = datetime.now()
        
        # Get route alternatives
        routes = self.get_enhanced_route_alternatives(origin, destination)
        
        if not routes:
            logger.warning("No routes found")
            return []
        
        scored_routes = []
        
        # Score each route
        for idx, route in enumerate(routes):
            try:
                score_data = self.score_route_enhanced(route, travel_datetime)
                polyline = route['overview_polyline']['points']
                coordinates = self._decode_polyline(polyline)
                
                route_info = {
                    'route_id': idx,
                    'route': route,
                    'coordinates': coordinates,
                    'risk_score': score_data['normalized_risk'],
                    'total_risk': score_data['total_risk'],
                    'max_segment_risk': score_data['max_segment_risk'],
                    'risk_variance': score_data['risk_variance'],
                    'distance': route['legs'][0]['distance']['value'] / 1000,  # km
                    'duration': route['legs'][0]['duration']['value'] / 60,    # minutes
                    'segment_scores': score_data['segment_scores'],
                    'travel_datetime': travel_datetime,
                    'time_period': self._get_time_period(travel_datetime.hour),
                    'is_weekend': travel_datetime.weekday() >= 5
                }
                
                # Calculate safety grade
                route_info['safety_grade'] = self._calculate_safety_grade(route_info)
                
                scored_routes.append(route_info)
                
            except Exception as e:
                logger.error(f"Error scoring route {idx}: {e}")
                continue
        
        if not scored_routes:
            return []
        
        # Sort by safety (lower risk is better), then by total travel time
        scored_routes.sort(key=lambda x: (x['risk_score'], x['duration']))
        
        # Generate AI explanations
        for i, route_info in enumerate(scored_routes):
            route_info['ai_explanation'] = self._generate_enhanced_ai_explanation(
                route_info, 
                rank=i+1,
                total_routes=len(scored_routes)
            )
        
        return scored_routes

    def _calculate_safety_grade(self, route_info: Dict) -> str:
        """Calculate letter grade for route safety"""
        risk_score = route_info['risk_score']
        max_risk = route_info['max_segment_risk']
        risk_variance = route_info['risk_variance']
        
        # Composite safety score
        composite_score = max(5, (risk_score * 0.6 + max_risk * 0.3 + 
                          np.sqrt(risk_variance) * 0.1))
        
        if composite_score < 10:
            return 'A+'
        elif composite_score < 20:
            return 'A'
        elif composite_score < 35:
            return 'B+'
        elif composite_score < 50:
            return 'B'
        elif composite_score < 70:
            return 'C+'
        elif composite_score < 90:
            return 'C'
        elif composite_score < 120:
            return 'D'
        else:
            return 'F'

    def _generate_enhanced_ai_explanation(self, route_info: Dict, rank: int, total_routes: int) -> str:
        """Generate comprehensive AI explanation for route recommendation"""
        
        risk_level = "low" if route_info['risk_score'] < 30 else "moderate" if route_info['risk_score'] < 70 else "high"
        time_context = f"during {route_info['time_period'].replace('_', ' ')}"
        
        prompt = f"""You are a safety-focused navigation expert. Provide a clear, helpful explanation for this route recommendation:

ROUTE DETAILS:
- Rank: #{rank} of {total_routes} routes
- Safety Grade: {route_info['safety_grade']}
- Risk Level: {risk_level} ({route_info['risk_score']:.1f})
- Distance: {route_info['distance']:.1f} km
- Duration: {route_info['duration']:.0f} minutes
- Travel Time: {time_context}
- Weekend: {'Yes' if route_info['is_weekend'] else 'No'}

RISK ANALYSIS:
- Maximum segment risk: {route_info['max_segment_risk']:.1f}
- Risk consistency: {'High variance' if route_info['risk_variance'] > 100 else 'Consistent'}

Provide a 3-4 sentence explanation that:
1. {'Explains why this is the safest option' if rank == 1 else f'Compares this #{rank} route to safer alternatives'}
2. Mentions specific time-of-day safety considerations
3. Notes any significant risk areas or safety advantages
4. Gives actionable advice if needed

Use a helpful, conversational tone. Be specific but not alarming."""

        try:
            response = self.safety_model.generate_content(prompt)
            return response.text.strip()
        except Exception as e:
            logger.error(f"AI explanation generation failed: {e}")
            return self._generate_fallback_explanation(route_info, rank)

    def _generate_fallback_explanation(self, route_info: Dict, rank: int) -> str:
        """Generate fallback explanation if AI fails"""
        safety_desc = {
            'A+': 'excellent', 'A': 'very good', 'B+': 'good', 'B': 'acceptable',
            'C+': 'fair', 'C': 'concerning', 'D': 'poor', 'F': 'high risk'
        }
        
        grade_desc = safety_desc.get(route_info['safety_grade'], 'moderate')
        
        if rank == 1:
            return (f"This route offers {grade_desc} safety during {route_info['time_period'].replace('_', ' ')} "
                   f"with a risk score of {route_info['risk_score']:.1f}. "
                   f"The {route_info['distance']:.1f}km journey should take about {route_info['duration']:.0f} minutes.")
        else:
            return (f"Alternative #{rank} has {grade_desc} safety but higher risk than the recommended route. "
                   f"Consider the trade-off between the {route_info['duration']:.0f}-minute travel time and "
                   f"the {route_info['risk_score']:.1f} risk score for {route_info['time_period'].replace('_', ' ')} travel.")

    def create_enhanced_visualization(self, route_data: Dict, output_file: str = 'enhanced_route_map.html') -> folium.Map:
        """Create comprehensive interactive map visualization"""
        if not route_data['coordinates']:
            return None
            
        # Calculate map center
        coords = route_data['coordinates']
        center_lat = np.mean([coord[0] for coord in coords])
        center_lon = np.mean([coord[1] for coord in coords])
        
        # Create base map
        m = folium.Map(
            location=[center_lat, center_lon], 
            zoom_start=10,
            tiles='OpenStreetMap'
        )
        
        # Add district boundaries
        for district, data in self.districts.items():
            if hasattr(data['geometry'], '__geo_interface__'):
                crime_stats = self.crime_stats.get(district, {})
                violence_ratio = crime_stats.get('violence_ratio', 0)
                
                # Color districts by violence ratio
                if violence_ratio < 0.1:
                    color = 'green'
                    fillColor = 'lightgreen'
                elif violence_ratio < 0.2:
                    color = 'yellow'
                    fillColor = 'lightyellow'
                elif violence_ratio < 0.3:
                    color = 'orange'
                    fillColor = 'lightsalmon'
                else:
                    color = 'red'
                    fillColor = 'lightcoral'
                
                folium.GeoJson(
                    data['geometry'].__geo_interface__,
                    name=f"{district} (Violence Ratio: {violence_ratio:.2%})",
                    style_function=lambda x, color=color, fillColor=fillColor: {
                        'color': color,
                        'weight': 2,
                        'fillOpacity': 0.3,
                        'fillColor': fillColor
                    },
                    tooltip=f"{district}<br>Total Crimes: {crime_stats.get('total_crimes', 0)}<br>Violence Ratio: {violence_ratio:.2%}"
                ).add_to(m)
        
        # Add crime hotspots
        for district, hotspots in self.crime_hotspots.items():
            for i, hotspot in enumerate(hotspots[:5]):  # Top 5 hotspots per district
                folium.CircleMarker(
                    location=[hotspot['center'][1], hotspot['center'][0]],  # lat, lon
                    radius=min(20, hotspot['intensity'] / 10),
                    popup=f"Hotspot #{i+1} in {district}<br>Intensity: {hotspot['intensity']:.1f}<br>Crimes: {hotspot['crime_count']}",
                    color='red',
                    fillColor='red',
                    fillOpacity=0.6,
                    weight=2
                ).add_to(m)
        
        # Add route segments colored by risk
        for i, segment in enumerate(route_data['segment_scores']):
            risk = segment['risk']
            
            # Color coding based on risk level
            if risk < 20:
                color = '#00FF00'  # Green
                opacity = 0.6
            elif risk < 40:
                color = '#FFFF00'  # Yellow
                opacity = 0.7
            elif risk < 70:
                color = '#FF8000'  # Orange
                opacity = 0.8
            else:
                color = '#FF0000'  # Red
                opacity = 0.9
            
            folium.PolyLine(
                locations=[[segment['start'][0], segment['start'][1]], 
                          [segment['end'][0], segment['end'][1]]],
                color=color,
                weight=6,
                opacity=opacity,
                popup=f"Segment {i+1}<br>Risk Score: {risk:.1f}<br>Distance: {segment['distance']*111:.0f}m"
            ).add_to(m)
        
        # Add start and end markers
        start_coord = coords[0]
        end_coord = coords[-1]
        
        folium.Marker(
            location=[start_coord[0], start_coord[1]],
            popup="Start",
            icon=folium.Icon(color='green', icon='play')
        ).add_to(m)
        
        folium.Marker(
            location=[end_coord[0], end_coord[1]],
            popup="Destination",
            icon=folium.Icon(color='red', icon='stop')
        ).add_to(m)
        
        # Add route information panel
        route_info_html = f"""
        <div style="position: fixed; top: 10px; right: 10px; width: 300px; 
                    background-color: white; border: 2px solid grey; z-index: 9999; 
                    font-size: 14px; padding: 10px; border-radius: 5px;">
        <h4>Route Safety Analysis</h4>
        <p><strong>Safety Grade:</strong> {route_data['safety_grade']}</p>
        <p><strong>Risk Score:</strong> {route_data['risk_score']:.1f}</p>
        <p><strong>Distance:</strong> {route_data['distance']:.1f} km</p>
        <p><strong>Duration:</strong> {route_data['duration']:.0f} min</p>
        <p><strong>Travel Time:</strong> {route_data['time_period'].replace('_', ' ').title()}</p>
        <p><strong>Max Risk Segment:</strong> {route_data['max_segment_risk']:.1f}</p>
        
        <h5>Risk Level Legend:</h5>
        <p><span style="color: #00FF00;">●</span> Low Risk (< 20)</p>
        <p><span style="color: #FFFF00;">●</span> Moderate Risk (20-40)</p>
        <p><span style="color: #FF8000;">●</span> High Risk (40-70)</p>
        <p><span style="color: #FF0000;">●</span> Very High Risk (> 70)</p>
        </div>
        """
        
        m.get_root().html.add_child(folium.Element(route_info_html))
        
        # Add layer control
        folium.LayerControl().add_to(m)
        
        # Save map
        m.save(output_file)
        return m

    def generate_route_report(self, routes: List[Dict], output_file: str = 'route_safety_report.txt') -> str:
        """Generate comprehensive text report of route analysis"""
        if not routes:
            return "No routes to analyze."
        
        report = []
        report.append("=" * 60)
        report.append("COMPREHENSIVE ROUTE SAFETY ANALYSIS REPORT")
        report.append("=" * 60)
        report.append(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"Travel Time: {routes[0]['time_period'].replace('_', ' ').title()}")
        report.append(f"Weekend Travel: {'Yes' if routes[0]['is_weekend'] else 'No'}")
        report.append("")
        
        # Summary comparison
        report.append("ROUTE COMPARISON SUMMARY")
        report.append("-" * 25)
        for i, route in enumerate(routes):
            report.append(f"Route #{i+1}: Safety Grade {route['safety_grade']}, "
                         f"Risk Score {route['risk_score']:.1f}, "
                         f"{route['duration']:.0f} min, {route['distance']:.1f} km")
        report.append("")
        
        # Detailed analysis for each route
        for i, route in enumerate(routes):
            report.append(f"ROUTE #{i+1} DETAILED ANALYSIS")
            report.append("-" * 30)
            report.append(f"Safety Grade: {route['safety_grade']}")
            report.append(f"Overall Risk Score: {route['risk_score']:.1f}")
            report.append(f"Maximum Segment Risk: {route['max_segment_risk']:.1f}")
            report.append(f"Risk Variance: {route['risk_variance']:.1f}")
            report.append(f"Distance: {route['distance']:.1f} km")
            report.append(f"Estimated Duration: {route['duration']:.0f} minutes")
            report.append("")
            
            report.append("AI Safety Assessment:")
            report.append(route['ai_explanation'])
            report.append("")
            
            # High-risk segments
            high_risk_segments = [s for s in route['segment_scores'] if s['risk'] > 50]
            if high_risk_segments:
                report.append("High-Risk Segments (Risk > 50):")
                for j, segment in enumerate(high_risk_segments[:5]):  # Top 5
                    report.append(f"  {j+1}. Risk: {segment['risk']:.1f}, "
                                f"Distance: {segment['distance']*111:.0f}m")
            else:
                report.append("No high-risk segments identified.")
            
            report.append("")
            report.append("-" * 50)
            report.append("")
        
        # Recommendations
        report.append("SAFETY RECOMMENDATIONS")
        report.append("-" * 25)
        best_route = routes[0]
        
        if best_route['safety_grade'] in ['A+', 'A']:
            report.append("✓ The recommended route has excellent safety characteristics.")
        elif best_route['safety_grade'] in ['B+', 'B']:
            report.append("⚠ The recommended route has acceptable safety. Consider:")
        else:
            report.append("⚠ All available routes have elevated risk. Strong recommendations:")
        
        if best_route['max_segment_risk'] > 80:
            report.append("  - Exercise extra caution in high-risk segments")
            report.append("  - Consider traveling during daylight hours if possible")
        
        if best_route['time_period'] in ['night', 'late_night']:
            report.append("  - Night travel increases risk - consider delaying if possible")
            report.append("  - Stay alert and avoid stopping in isolated areas")
        
        if best_route['is_weekend']:
            report.append("  - Weekend travel may have different risk patterns")
        
        report.append("")
        report.append("=" * 60)
        
        report_text = "\n".join(report)
        
        # Save to file
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(report_text)
        
        return report_text

    @staticmethod
    def _decode_polyline(polyline_str: str) -> List[Tuple[float, float]]:
        """Decode Google Maps polyline string into coordinates"""
        index, lat, lng = 0, 0, 0
        coordinates = []
        changes = {'latitude': 0, 'longitude': 0}
        
        while index < len(polyline_str):
            for unit in ['latitude', 'longitude']:
                shift, result = 0, 0
                
                while True:
                    if index >= len(polyline_str):
                        break
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

# Example usage and testing
if __name__ == "__main__":
    # Initialize the enhanced router
    try:
        router = EnhancedCrimeAwareRouter(
            geojson_path="karnataka.geojson",
            crime_csv_path="ka_ipc_crimes_district_2024.csv",
            google_maps_api_key="AIzaSyCroP5ArTzF4g5GmZdr7ml9KDlRviEQfbE",
            gemini_api_key="AIzaSyDKAjZe7kDqEPoEpliD3lJ68TXas3iISCw"
        )
        
        print("Enhanced Crime-Aware Router initialized successfully!")
        print(f"Loaded {len(router.districts)} districts")
        print(f"Crime data available for {len(router.crime_data)} districts")
    except Exception as e:
        print(f"Error initializing EnhancedCrimeAwareRouter: {e}")
        
        
if __name__ == "__main__":
    import argparse
    import sys
    import hashlib

    parser = argparse.ArgumentParser(description="Crime-Aware Route Analyzer")
    parser.add_argument("--origin", required=True, help="Origin (e.g., 'Kolar, Karnataka')")
    parser.add_argument("--destination", required=True, help="Destination (e.g., 'Bengaluru')")
    parser.add_argument("--departure_in", type=int, default=2, help="Hours from now (default=2)")
    args = parser.parse_args()

    def _pseudo_spatial_noise(point: tuple) -> float:
        key = f"{round(point[0], 4)}_{round(point[1], 4)}"
        seed = int(hashlib.md5(key.encode()).hexdigest()[:8], 16)
        np.random.seed(seed)
        return np.random.uniform(0.8, 1.2)  # ±20% noise

    try:
        router = EnhancedCrimeAwareRouter(
            geojson_path="karnataka.geojson",
            crime_csv_path="ka_ipc_crimes_district_2024.csv",
            google_maps_api_key="AIzaSyCroP5ArTzF4g5GmZdr7ml9KDlRviEQfbE",
            gemini_api_key="AIzaSyDKAjZe7kDqEPoEpliD3lJ68TXas3iISCw"
        )

        travel_time = datetime.now() + timedelta(hours=args.departure_in)
        routes = router.recommend_safest_route(args.origin, args.destination, travel_time)

        if routes:
            print(f"Best route from {args.origin} to {args.destination}:")
            print(f"  Safety Grade: {routes[0]['safety_grade']}")
            print(f"  Risk Score: {routes[0]['risk_score']:.1f}")
            print(f"  Distance: {routes[0]['distance']:.1f} km")
            print(f"  Duration: {routes[0]['duration']:.0f} min")

            router.create_enhanced_visualization(routes[0], 'best_route_map.html')
            router.generate_route_report(routes, 'route_analysis_report.txt')

            print("✔ Analysis complete — check 'best_route_map.html' and 'route_analysis_report.txt'")
        else:
            print("❌ No routes found. Check API keys or network.")

    except Exception as e:
        print(f"Error: {e}")

        print("\nAnalyzing routes from Bengaluru to Mysuru...")
        routes = router.recommend_safest_route(
            origin="Bengaluru, Karnataka, India",
            destination="Mysuru, Karnataka, India",
            travel_datetime=datetime.now() + timedelta(hours=2)
        )
        
        if routes:
            print(f"\nFound {len(routes)} route alternatives:")
            for i, route in enumerate(routes[:3]):  # Show top 3
                print(f"\nRoute #{i+1}:")
                print(f"  Safety Grade: {route['safety_grade']}")
                print(f"  Risk Score: {route['risk_score']:.1f}")
                print(f"  Distance: {route['distance']:.1f} km")
                print(f"  Duration: {route['duration']:.0f} minutes")
                print(f"  AI Recommendation: {route['ai_explanation'][:100]}...")
            
            # Generate visualizations and reports
            print("\nGenerating visualization...")
            router.create_enhanced_visualization(routes[0], 'best_route_map.html')
            
            print("Generating safety report...")
            report = router.generate_route_report(routes, 'route_analysis_report.txt')
            
            print("\nAnalysis complete! Check generated files:")
            print("- best_route_map.html (Interactive map)")
            print("- route_analysis_report.txt (Detailed report)")
            
        else:
            print("No routes found. Please check your API keys and network connection.")
            
    except Exception as e:
        print(f"Error initializing router: {e}")
        print("\nPlease ensure you have:")
        print("1. Valid Google Maps API key")
        print("2. Valid Gemini API key") 
        print("3. Required data files (karnataka.geojson, ka_ipc_crimes_district_2024.csv)")
        print("4. All required Python packages installed")

# Additional utility functions for extended functionality

def batch_route_analysis(router: EnhancedCrimeAwareRouter, 
                        origin_destination_pairs: List[Tuple[str, str]],
                        travel_times: List[datetime] = None) -> Dict:
    """Analyze multiple routes in batch for comparison"""
    if travel_times is None:
        travel_times = [datetime.now()] * len(origin_destination_pairs)
    
    results = {}
    
    for i, (origin, dest) in enumerate(origin_destination_pairs):
        travel_time = travel_times[i] if i < len(travel_times) else datetime.now()
        
        try:
            routes = router.recommend_safest_route(origin, dest, travel_time)
            if routes:
                results[f"{origin} → {dest}"] = {
                    'best_route': routes[0],
                    'alternatives': routes[1:],
                    'analysis_time': travel_time
                }
        except Exception as e:
            logger.error(f"Error analyzing {origin} → {dest}: {e}")
            results[f"{origin} → {dest}"] = {'error': str(e)}
    
    return results

def compare_time_periods(router: EnhancedCrimeAwareRouter,
                        origin: str, destination: str) -> Dict:
    """Compare route safety across different time periods"""
    time_periods = ['morning', 'afternoon', 'evening', 'night']
    base_date = datetime.now().replace(hour=9, minute=0, second=0, microsecond=0)
    
    time_mappings = {
        'morning': base_date.replace(hour=9),
        'afternoon': base_date.replace(hour=15),
        'evening': base_date.replace(hour=19),
        'night': base_date.replace(hour=23)
    }
    
    comparison = {}
    
    for period in time_periods:
        travel_time = time_mappings[period]
        try:
            routes = router.recommend_safest_route(origin, destination, travel_time)
            if routes:
                comparison[period] = {
                    'safety_grade': routes[0]['safety_grade'],
                    'risk_score': routes[0]['risk_score'],
                    'duration': routes[0]['duration'],
                    'recommendation': routes[0]['ai_explanation']
                }
        except Exception as e:
            comparison[period] = {'error': str(e)}
    
    return comparison