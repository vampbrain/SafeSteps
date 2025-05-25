import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class APIConnectionTest extends StatefulWidget {
  @override
  _APIConnectionTestState createState() => _APIConnectionTestState();
}

class _APIConnectionTestState extends State<APIConnectionTest> {
  String _connectionStatus = 'Not tested';
  String _apiResponse = '';
  bool _isLoading = false;

  Future<void> testConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Testing...';
      _apiResponse = '';
    });

    try {
      print('Testing connection to: http://192.168.6.15:5000/health');
      
      final response = await http.get(
        Uri.parse('http://192.168.6.15:5000/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _connectionStatus = '✅ Connected Successfully!';
          _apiResponse = 'Status: ${data['status']}\n'
                        'Service: ${data['service']}\n'
                        'ML Available: ${data['ml_available']}\n'
                        'Timestamp: ${data['timestamp']}';
        });
      } else {
        setState(() {
          _connectionStatus = '❌ Connection Failed';
          _apiResponse = 'Status Code: ${response.statusCode}\n'
                        'Response: ${response.body}';
        });
      }
    } catch (e) {
      print('Connection test failed: $e');
      setState(() {
        _connectionStatus = '❌ Connection Error';
        _apiResponse = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> testAnalyzeRoutes() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Testing analyze_routes...';
      _apiResponse = '';
    });

    try {
      // Sample route data for testing
      final testData = {
        "timestamp": DateTime.now().toIso8601String(),
        "total_routes": 2,
        "travel_hour": DateTime.now().hour,
        "routes": [
          {
            "route_index": 0,
            "summary": "Test Route 1",
            "distance": "5.2 km",
            "duration": "12 mins",
            "distance_value": 5200,
            "duration_value": 720,
            "coordinates": [
              {"latitude": 12.9716, "longitude": 77.5946},
              {"latitude": 12.9516, "longitude": 77.6047}
            ],
            "start_address": "Test Start",
            "end_address": "Test End"
          },
          {
            "route_index": 1,
            "summary": "Test Route 2",
            "distance": "6.1 km",
            "duration": "15 mins",
            "distance_value": 6100,
            "duration_value": 900,
            "coordinates": [
              {"latitude": 12.9716, "longitude": 77.5946},
              {"latitude": 12.9416, "longitude": 77.6147}
            ],
            "start_address": "Test Start",
            "end_address": "Test End"
          }
        ]
      };

      print('Testing analyze_routes endpoint...');
      
      final response = await http.post(
        Uri.parse('http://192.168.6.15:5000/analyze_routes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(testData),
      ).timeout(const Duration(seconds: 30));
      
      print('Analyze routes response status: ${response.statusCode}');
      print('Analyze routes response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _connectionStatus = '✅ Analyze Routes Works!';
          _apiResponse = 'Status: ${data['status']}\n'
                        'Total Routes: ${data['total_routes']}\n'
                        'Recommended Route: ${data['recommended_route']['summary']}\n'
                        'Safety Score: ${data['recommended_route']['safety_score']}\n'
                        'Crime Risk: ${data['recommended_route']['crime_risk_level']}';
        });
      } else {
        setState(() {
          _connectionStatus = '❌ Analyze Routes Failed';
          _apiResponse = 'Status Code: ${response.statusCode}\n'
                        'Response: ${response.body}';
        });
      }
    } catch (e) {
      print('Analyze routes test failed: $e');
      setState(() {
        _connectionStatus = '❌ Analyze Routes Error';
        _apiResponse = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Connection Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Endpoint: http://192.168.6.15:5000',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _isLoading ? null : testConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: Size(double.infinity, 50),
              ),
              child: _isLoading 
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Test Health Endpoint', style: TextStyle(color: Colors.white)),
            ),
            
            SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _isLoading ? null : testAnalyzeRoutes,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
              ),
              child: _isLoading 
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Test Analyze Routes', style: TextStyle(color: Colors.white)),
            ),
            
            SizedBox(height: 20),
            
            Text(
              'Connection Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _connectionStatus.contains('✅') 
                    ? Colors.green.withOpacity(0.1)
                    : _connectionStatus.contains('❌')
                        ? Colors.red.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                border: Border.all(
                  color: _connectionStatus.contains('✅') 
                      ? Colors.green
                      : _connectionStatus.contains('❌')
                          ? Colors.red
                          : Colors.grey,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _connectionStatus,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _connectionStatus.contains('✅') 
                      ? Colors.green
                      : _connectionStatus.contains('❌')
                          ? Colors.red
                          : Colors.black,
                ),
              ),
            ),
            
            if (_apiResponse.isNotEmpty) ...[
              SizedBox(height: 20),
              Text(
                'API Response:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _apiResponse,
                      style: TextStyle(fontSize: 14, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}