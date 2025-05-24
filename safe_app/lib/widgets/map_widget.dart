import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/route_controller.dart';

class MapWidget extends StatefulWidget {
  final RouteController controller;
  
  const MapWidget({
    super.key,
    required this.controller,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? mapController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        return GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            mapController = controller;
            if (widget.controller.userLocation != null) {
              controller.animateCamera(
                CameraUpdate.newLatLng(widget.controller.userLocation!),
              );
            }
          },
          initialCameraPosition: CameraPosition(
            target: widget.controller.userLocation ?? const LatLng(13.0827, 80.2707),
            zoom: 12,
          ),
          polylines: widget.controller.polylines,
          markers: widget.controller.markers,
          minMaxZoomPreference: const MinMaxZoomPreference(12, 17),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
        );
      },
    );
  }

  void fitMapToRoutes() {
    if (mapController == null) return;
    
    final bounds = widget.controller.getRouteBounds();
    if (bounds != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }
}
