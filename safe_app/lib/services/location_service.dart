import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  final Location _location = Location();

  Future<LatLng?> getCurrentLocation() async {
    final hasPermission = await _location.hasPermission();
    if (hasPermission == PermissionStatus.denied) {
      await _location.requestPermission();
    }

    try {
      final locData = await _location.getLocation();
      return LatLng(locData.latitude!, locData.longitude!);
    } catch (e) {
      return null;
    }
  }
}
