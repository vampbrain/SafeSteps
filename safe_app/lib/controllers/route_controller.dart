import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/maps_service.dart';
import '../services/ml_service.dart';
import '../models/route_model.dart';

class RouteController extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final MapsService _mapsService = MapsService();
  final MLService _mlService = MLService();

  // State variables
  LatLng? userLocation;
  LatLng? startLocation;
  LatLng? destination;
  List<RouteModel> allRoutesData = [];
  RouteModel? mlSelectedRoute;
  bool isProcessingML = false;
  Set<Polyline> polylines = {};
  Set<Marker> markers = {};

  // Initialize location
  Future<void> initializeLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      userLocation = location;
      startLocation = location;
      notifyListeners();
    }
  }

  // Search for routes
  Future<String?> searchRoutes(String startText, String destinationText) async {
    if (startText.isEmpty || destinationText.isEmpty) {
      return 'Please enter both start and destination locations';
    }

    // Get start location
    LatLng? start = startLocation;
    if (startText.toLowerCase() != 'current location') {
      start = await _mapsService.getCoordinatesFromAddress(startText);
      if (start == null) {
        return 'Could not find start location';
      }
    }

    // Get destination
    LatLng? dest = await _mapsService.getCoordinatesFromAddress(destinationText);
    if (dest == null) {
      return 'Could not find destination';
    }


    // Fetch routes
    final routes = await _mapsService.fetchRoutes(start!, dest);
    if (routes.isEmpty) {
      return 'No routes found';
    }

    allRoutesData = routes;
    startLocation = start;
    destination = dest;
    mlSelectedRoute = null;
    updateMapWithRoutes();
    notifyListeners();

    return null; // Success
  }

  // Process with ML
  Future<Map<String, dynamic>?> processWithML() async {
    if (allRoutesData.isEmpty) return null;

    isProcessingML = true;
    notifyListeners();

    try {
      final result = await _mlService.processRoutes(allRoutesData);
      
      if (result != null && result['selected_route'] != null) {
        final selectedRouteData = result['selected_route'];
        mlSelectedRoute = allRoutesData.firstWhere(
          (route) => route.routeId == selectedRouteData['route_id'],
        );
        updateMapWithMLSelection();
        notifyListeners();
        return result;
      }
    } catch (e) {
      // Handle error
    } finally {
      isProcessingML = false;
      notifyListeners();
    }
    return null;
  }

  void updateMapWithRoutes() {
    polylines.clear();
    markers.clear();

    // Add markers
    if (startLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: startLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Start'),
        ),
      );
    }

    if (destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination'),
        ),
      );
    }

    // Add polylines
    for (int i = 0; i < allRoutesData.length; i++) {
      final route = allRoutesData[i];
      polylines.add(
        Polyline(
          polylineId: PolylineId(route.routeId),
          points: route.polylinePoints,
          color: Colors.grey,
          width: 4,
        ),
      );
    }
    notifyListeners();
  }

  void updateMapWithMLSelection() {
    if (mlSelectedRoute == null) return;

    polylines.clear();
    for (final route in allRoutesData) {
      polylines.add(
        Polyline(
          polylineId: PolylineId(route.routeId),
          points: route.polylinePoints,
          color: route == mlSelectedRoute ? Colors.green : Colors.grey,
          width: route == mlSelectedRoute ? 6 : 3,
        ),
      );
    }
  }

  // Add method to calculate bounds for all routes
LatLngBounds? getRouteBounds() {
  if (allRoutesData.isEmpty || startLocation == null || destination == null) {
    return null;
  }

  double minLat = startLocation!.latitude;
  double maxLat = startLocation!.latitude;
  double minLng = startLocation!.longitude;
  double maxLng = startLocation!.longitude;

  // Include destination
  minLat = minLat < destination!.latitude ? minLat : destination!.latitude;
  maxLat = maxLat > destination!.latitude ? maxLat : destination!.latitude;
  minLng = minLng < destination!.longitude ? minLng : destination!.longitude;
  maxLng = maxLng > destination!.longitude ? maxLng : destination!.longitude;

  // Include all route points for better bounds calculation
  for (final route in allRoutesData) {
    for (final point in route.polylinePoints) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }
  }

  // Add padding to bounds
  const double padding = 0.01;
  return LatLngBounds(
    southwest: LatLng(minLat - padding, minLng - padding),
    northeast: LatLng(maxLat + padding, maxLng + padding),
  );
}

}
