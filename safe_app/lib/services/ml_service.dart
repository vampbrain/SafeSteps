import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';

class MLService {
  // Updated to use your computer's IP address for physical device
  static const String _baseUrl = 'http://192.168.6.15:5000';
  
  // Test connection method
  Future<bool> testConnection() async {
    try {
      print('Testing connection to: $_baseUrl/health');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> processRoutes(List<RouteModel> routes) async {
    if (routes.isEmpty) return null;

    try {
      // First test connection
      bool isConnected = await testConnection();
      if (!isConnected) {
        print('API connection failed, using fallback');
        return _fallbackProcessing(routes);
      }

      // Convert routes to the format expected by your Python API
      final requestData = _convertRoutesToMLFormat(routes);
      
      print('Sending request to: $_baseUrl/analyze_routes');
      print('Request data: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/analyze_routes'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return _processMLResponse(result, routes);
      } else {
        print('ML API Error: ${response.statusCode} - ${response.body}');
        return _fallbackProcessing(routes);
      }
    } catch (e) {
      print('ML Service Error: $e');
      // Fallback to original logic if API fails
      return _fallbackProcessing(routes);
    }
  }

  Map<String, dynamic> _convertRoutesToMLFormat(List<RouteModel> routes) {
    // Convert your RouteModel list to the format your Python API expects
    final now = DateTime.now();
    
    return {
      "timestamp": now.toIso8601String(),
      "total_routes": routes.length,
      "travel_hour": now.hour, // Current hour for time-based analysis
      "routes": routes.map((route) => {
        "route_index": route.routeIndex,
        "summary": route.summary,
        "distance": route.distance,
        "duration": route.duration,
        "distance_value": route.distanceValue,
        "duration_value": route.durationValue,
        "coordinates": route.coordinates.map((coord) => {
          "latitude": coord['latitude'],
          "longitude": coord['longitude'],
        }).toList(),
        "start_address": route.startAddress,
        "end_address": route.endAddress,
      }).toList(),
    };
  }

  Map<String, dynamic> _processMLResponse(Map<String, dynamic> mlResult, List<RouteModel> routes) {
    // Extract the recommended route from ML response
    final recommendedRouteData = mlResult['recommended_route'];
    final recommendedIndex = recommendedRouteData['route_index'];
    
    // Find the corresponding RouteModel
    RouteModel? selectedRoute;
    try {
      selectedRoute = routes.firstWhere((route) => route.routeIndex == recommendedIndex);
    } catch (e) {
      selectedRoute = routes.first; // Fallback to first route
    }

    return {
      'status': 'success',
      'confidence': (mlResult['recommended_route']['safety_score'] ?? 7.0) / 10.0, // Convert to 0-1 scale with null safety
      'selected_route': selectedRoute?.toJson(),
      'ml_analysis': {
        'safety_score': mlResult['recommended_route']['safety_score'] ?? 7.0,
        'crime_risk_level': mlResult['recommended_route']['crime_risk_level'] ?? 'Medium',
        'total_routes_analyzed': mlResult['total_routes'] ?? routes.length,
        'analysis_factors': mlResult['analysis_summary']?['factors_considered'] ?? ['Route analysis completed'],
      },
      'reasoning': _generateReasoning(mlResult['recommended_route']),
      'safety_factors': _extractSafetyFactors(mlResult),
      'raw_ml_data': mlResult, // Keep full ML response for debugging
    };
  }

  String _generateReasoning(Map<String, dynamic> recommendedRoute) {
    final score = recommendedRoute['safety_score'] ?? 7.0;
    final riskLevel = recommendedRoute['crime_risk_level'] ?? 'Medium';
    
    if (score >= 8.0) {
      return 'Highly recommended route with excellent safety score (${score.toStringAsFixed(1)}/10) and $riskLevel crime risk.';
    } else if (score >= 6.0) {
      return 'Good route option with decent safety score (${score.toStringAsFixed(1)}/10) and $riskLevel crime risk.';
    } else {
      return 'Acceptable route with moderate safety score (${score.toStringAsFixed(1)}/10) and $riskLevel crime risk.';
    }
  }

  List<String> _extractSafetyFactors(Map<String, dynamic> mlResult) {
    List<String> factors = [];
    
    final recommendedRoute = mlResult['recommended_route'];
    final score = recommendedRoute['safety_score'] ?? 7.0;
    final riskLevel = recommendedRoute['crime_risk_level'] ?? 'Medium';
    
    // Add factors based on ML analysis
    factors.add('Crime risk level: $riskLevel');
    factors.add('Safety score: ${score.toStringAsFixed(1)}/10');
    
    if (score >= 7.0) {
      factors.add('Low crime density area');
    }
    
    if (mlResult['analysis_summary'] != null) {
      final analysisFactors = mlResult['analysis_summary']['factors_considered'] as List?;
      if (analysisFactors != null) {
        factors.addAll(analysisFactors.cast<String>());
      }
    }
    
    return factors;
  }

  // Fallback processing when ML API is unavailable
  Future<Map<String, dynamic>?> _fallbackProcessing(List<RouteModel> routes) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate processing time

    RouteModel? bestRoute;
    double bestScore = double.infinity;

    for (final route in routes) {
      final score = (route.distanceValue * 0.6) + (route.durationValue * 0.4);
      
      if (score < bestScore) {
        bestScore = score;
        bestRoute = route;
      }
    }

    return {
      'status': 'fallback',
      'confidence': 0.75,
      'selected_route': bestRoute?.toJson(),
      'reasoning': 'Selected using fallback algorithm (ML service unavailable)',
      'safety_factors': [
        'Optimal distance-time balance',
        'ML analysis temporarily unavailable',
        'Using basic route optimization'
      ]
    };
  }

  // Method to check if ML API is available
  Future<bool> isMLServiceAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}