import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_model.dart';
import '../utils/constants.dart';
import '../utils/polyline_decoder.dart';

class MapsService {
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&region=in&key=${AppConstants.googleMapsApiKey}');
    
    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final loc = data['results'][0]['geometry']['location'];
        return LatLng(loc['lat'], loc['lng']);
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  Future<List<RouteModel>> fetchRoutes(LatLng origin, LatLng destination) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&alternatives=true&key=${AppConstants.googleMapsApiKey}');

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['routes'] != null) {
        List<RouteModel> routes = [];
        
        for (int i = 0; i < data['routes'].length; i++) {
          final route = data['routes'][i];
          final points = route['overview_polyline']['points'];
          final decoded = PolylineDecoder.decodePolyline(points);

          routes.add(RouteModel(
            routeId: 'route_$i',
            routeIndex: i,
            summary: route['summary'] ?? 'Route ${i + 1}',
            distance: route['legs'][0]['distance']['text'] ?? 'Unknown',
            duration: route['legs'][0]['duration']['text'] ?? 'Unknown',
            distanceValue: route['legs'][0]['distance']['value'] ?? 0,
            durationValue: route['legs'][0]['duration']['value'] ?? 0,
            coordinates: decoded.map((latLng) => {
              'latitude': latLng.latitude,
              'longitude': latLng.longitude
            }).toList(),
            startAddress: route['legs'][0]['start_address'] ?? 'Unknown',
            endAddress: route['legs'][0]['end_address'] ?? 'Unknown',
            polylinePoints: decoded,
          ));
        }
        return routes;
      }
    } catch (e) {
      print('Routes fetch error: $e');
    }
    return [];
  }
}
