import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteModel {
  final String routeId;
  final int routeIndex;
  final String summary;
  final String distance;
  final String duration;
  final int distanceValue;
  final int durationValue;
  final List<Map<String, double>> coordinates;
  final String startAddress;
  final String endAddress;
  final List<LatLng> polylinePoints;

  RouteModel({
    required this.routeId,
    required this.routeIndex,
    required this.summary,
    required this.distance,
    required this.duration,
    required this.distanceValue,
    required this.durationValue,
    required this.coordinates,
    required this.startAddress,
    required this.endAddress,
    required this.polylinePoints,
  });

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'route_index': routeIndex,
      'summary': summary,
      'distance': distance,
      'duration': duration,
      'distance_value': distanceValue,
      'duration_value': durationValue,
      'coordinates': coordinates,
      'start_address': startAddress,
      'end_address': endAddress,
    };
  }
}
