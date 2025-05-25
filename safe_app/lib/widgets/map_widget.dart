import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
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
  Completer<GoogleMapController> _mapController = Completer();
  GoogleMapController? mapController;

  @override
  void initState() {
    super.initState();
    // Listen for route updates to adjust camera
    widget.controller.addListener(_onRouteUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onRouteUpdate);
    super.dispose();
  }

  void _onRouteUpdate() {
    // Automatically fit camera when routes are updated
    if (widget.controller.allRoutesData.isNotEmpty) {
      _fitCameraToRoutes();
    }
  }

  Future<void> _fitCameraToRoutes() async {
    if (!_mapController.isCompleted) return;
    
    final GoogleMapController controller = await _mapController.future;
    final bounds = widget.controller.getRouteBounds();
    
    if (bounds != null) {
      // Animate camera to fit the route bounds
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0), // 100.0 is padding
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        return GoogleMap(
          onMapCreated: (GoogleMapController controller) async {
            _mapController.complete(controller);
            mapController = controller;
            
            if (widget.controller.userLocation != null) {
              await controller.animateCamera(
                CameraUpdate.newLatLng(widget.controller.userLocation!),
              );
            }
          },
          initialCameraPosition: CameraPosition(
            target: widget.controller.userLocation ?? const LatLng(12.8487599, 77.6482529),
            zoom: 10,
          ),
          polylines: widget.controller.polylines,
          markers: widget.controller.markers,
          minMaxZoomPreference: const MinMaxZoomPreference(2, 20),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
        );
      },
    );
  }

  // Public method to manually fit camera (can be called from parent)
  Future<void> fitCameraToRoutes() async {
    await _fitCameraToRoutes();
  }
}
