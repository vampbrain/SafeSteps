import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppConstants {
  static const String googleMapsApiKey = 'AIzaSyCroP5ArTzF4g5GmZdr7ml9KDlRviEQfbE';
  
  static final LatLngBounds chennaiBounds = LatLngBounds(
    southwest: LatLng(12.95, 80.18),
    northeast: LatLng(13.15, 80.32),
  );
}
