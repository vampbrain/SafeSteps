# SafeSteps 🛡️
### AI-Powered Safety Navigation for Female Solo Travelers

> **Transforming urban mobility through intelligent crime-aware routing**

SafeSteps leverages spatial crime analysis and risk modeling to provide safety-first navigation recommendations, specifically designed to empower female solo travelers with confidence and security.

---

## 🎯 **Problem Statement**

**60% of women** avoid certain routes due to safety concerns, limiting their mobility and independence. Traditional navigation apps prioritize speed and distance but ignore critical safety factors, leaving vulnerable travelers without essential risk information.

**The Challenge**: How can we provide intelligent route recommendations that balance efficiency with personal safety?

---

## 💡 **Our Solution**

SafeSteps analyzes crime patterns and risk factors to deliver **safety-scored route alternatives** with intelligent recommendations that prioritize user security without sacrificing convenience.

### **Core Innovation**
- **Crime-Aware Routing**: Spatial risk assessment using real crime statistics
- **Multi-Route Analysis**: Compares all Google Maps alternatives with safety scores
- **Emergency Integration**: SOS functionality with auto-contact alerts
- **Time-Sensitive Intelligence**: Adjusts risk based on travel timing

---

## 🚀 **How It Works**

### **Phase 1: App Initialization & Route Discovery**
```
App Launch → Get User Location → Set Current Location as Start Point
User Input → Geocoding → Route Fetching → Data Extraction → Visual Display
```

1. **Location Setup**: App requests permissions and gets user's current GPS coordinates
2. **Destination Input**: User enters target address in search field
3. **Address Geocoding**: Google Geocoding API converts addresses to coordinates and validates locations within city bounds
4. **Route Fetching**: Google Directions API returns multiple route alternatives with polylines, distances, and durations
5. **Initial Display**: All routes displayed in **blue color** with start (green) and end (red) markers

### **Phase 2: Spatial Risk Analysis**
```
Route Data → Crime Pattern Analysis → Risk Calculation → Safety Scoring
```

1. **Data Preparation**: Structures route coordinates, distances, and metadata for analysis
```json
{
    "timestamp": "2025-05-23T...",
    "total_routes": 3,
    "routes": [
        {
            "route_id": "route_0",
            "summary": "NH 4",
            "distance_value": 15200,
            "duration_value": 1380,
            "coordinates": [
                {"latitude": 13.0827, "longitude": 80.2707}
            ]
        }
    ]
}
```

2. **Spatial Risk Calculation**: Analyzes each route coordinate against crime hotspot database using distance-weighted scoring
3. **Time-Based Adjustment**: Applies temporal multipliers based on travel timing
4. **Route Scoring**: Assigns safety scores (0-10 scale) with risk categories: LOW → MEDIUM → MEDIUM-HIGH → HIGH

### **Phase 3: Visual Route Highlighting**
```
Risk Analysis → Route Ranking → Color Update → User Feedback
```

- **Selected Route**: **Green color**, thicker line (width: 6)
- **Alternative Routes**: **Blue color**, thinner lines (width: 4)
- **Status Updates**: "✓ Safest Route Selected" with route summary showing distance and duration

---

## 🏗️ **Technical Architecture**

### **Technology Stack**
- **Mobile**: Flutter cross-platform application
- **Backend**: Flask API with spatial analysis algorithms
- **Data**: Karnataka crime statistics with synthetic modeling
- **Integration**: Google Maps API (Geocoding, Directions, Maps SDK)
- **Analysis**: Distance-based spatial risk modeling with temporal patterns

### **Key Components**
1. **Spatial Risk Engine**: Processes synthetic crime data from official statistics using distance-weighted algorithms
2. **Route Safety Scorer**: 0-10 scale with percentile-based risk categories
3. **Emergency Response System**: One-tap SOS with contact automation
4. **Mobile-First Interface**: Intuitive design for quick decision-making

### **Risk Calculation Method**
```python
def calculate_route_safety(route_coordinates, travel_time):
    route_risks = []
    for point in route_coordinates:
        # Distance-weighted crime impact
        base_risk = calculate_spatial_risk(lat, lon, crime_hotspots)
        # Time-based adjustment
        adjusted_risk = apply_temporal_multiplier(base_risk, travel_time)
        route_risks.append(adjusted_risk)
    
    # Conservative approach: use maximum risk point
    max_risk = max(route_risks)
    safety_category = categorize_risk(max_risk)  # Percentile-based
    return safety_score, safety_category
```

---

## 📊 **Data Foundation**

### **Crime Analysis Approach**
- **Source**: Karnataka IPC aggregate crime statistics (2024)
- **Methodology**: Synthetic crime modeling from official data using spatial distribution patterns
- **Coverage**: Bengaluru city comprehensive analysis
- **Categories**: 15 crime types including theft, harassment, cyber crimes
- **Validation**: Cross-referenced with news articles for pattern accuracy

### **Spatial Risk Modeling**
- **Distance-Based Scoring**: Exponential decay model where nearby crimes have higher impact
- **Crime Weighting**: Violent crimes (murder, robbery) weighted higher than property crimes
- **Hotspot Patterns**: Realistic geographic clustering based on area characteristics
- **Temporal Adjustments**: Morning (0.7x), Evening (1.0x), Night (1.3x) risk multipliers

### **Performance**
- **Response Time**: Sub-second analysis for real-time usage
- **Mobile Optimization**: Efficient algorithms designed for mobile connectivity
- **Cross-Platform**: Native performance on Android and iOS

---

## 🎯 **Key Features**

### **🧠 Intelligent Safety Analysis**
- **Spatial Risk Modeling**: Distance-weighted crime impact scoring using exponential decay
- **Temporal Adjustments**: Time-based risk multipliers based on criminology research
- **Area Classification**: Different risk profiles for commercial vs residential zones
- **Conservative Assessment**: Uses maximum risk point along route for safety scoring

### **📱 Emergency Response**
- **SOS Functionality**: One-tap emergency alert system
- **Auto-Contact Alerts**: Instantly notifies pre-configured emergency contacts
- **Location Sharing**: Real-time position broadcasting to trusted contacts
- **Resource Library**: Self-defense guides and safety articles

### **🗺️ Smart Navigation**
- **Multi-Route Comparison**: Analyzes all available route alternatives
- **Safety-Time Trade-offs**: Shows time vs security comparisons
- **Visual Risk Indicators**: Color-coded route safety visualization
- **Boundary Validation**: Restricted to supported city areas

---

## 🛠️ **Technical Implementation**


### **Mobile App Features**
- **Flutter Framework**: Cross-platform native performance
- **Offline Capability**: Core safety features work without internet
- **Real-time Updates**: Live risk assessment and route monitoring
- **Data Export**: JSON export for verification and debugging

---

## 🏆 **Competitive Advantages**

- **First-to-Market**: Safety-first navigation specifically for women
- **Data-Driven**: Spatial risk assessment using real crime statistics
- **Comprehensive Solution**: Navigation + Emergency response + Safety resources
- **Privacy-Preserving**: Synthetic data approach protects individual privacy
- **Production-Ready**: Robust algorithms optimized for mobile performance
- **Interpretable**: Clear, understandable safety reasoning for users




**SafeSteps - Empowering Safe Journeys Through Intelligent Technology** 🛡️

*Built at Buildverse 2025, designed for real-world impact*
