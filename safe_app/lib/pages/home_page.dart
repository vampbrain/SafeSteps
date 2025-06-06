import 'package:flutter/material.dart';
import '../controllers/route_controller.dart';
import '../widgets/route_input_section.dart';
import '../widgets/map_widget.dart';
import '../widgets/route_summary_dialog.dart';
import '../widgets/json_data_dialog.dart';
import '../widgets/ml_result_dialog.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/constants.dart';
import 'chatbot_page.dart';
import 'resources_page.dart';
import 'profile_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';
import 'dart:convert';
import '../pages/api_test_screen.dart'; // Adjust path as needed

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RouteController _routeController = RouteController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final Location _location = Location();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _requestLocationPermission();
    _configureLocation();
  }

  Future<void> _configureLocation() async {
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 5,
    );
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }
  }

  Future<LocationData?> _getCurrentLocation() async {
    try {
      await _requestLocationPermission();
      return await _location.getLocation();
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<void> _initializeApp() async {
    await _routeController.initializeLocation();
    if (_routeController.userLocation != null) {
      _startController.text = 'Current Location';
    } else {
      // Default to Electronic City if GPS not available
      _routeController.startLocation = AppConstants.electronicCityCenter;
      _startController.text = 'Electronic City, Bangalore';
    }
  }

  Future<void> _sendSOSMessage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getString('emergency_contacts');
      final userName = prefs.getString('user_name') ?? '';

      if (contactsJson == null || contactsJson.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Please add emergency contacts in your profile first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current location with high accuracy
      final LocationData? currentLocation = await _getCurrentLocation();

      // Hide loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      final List<dynamic> contacts = json.decode(contactsJson);
      final List<String> recipients =
          contacts.map((contact) => contact['phone'] as String).toList();

      // Create the base message
      String message =
          'EMERGENCY: ${userName.isNotEmpty ? "$userName needs" : "Someone needs"} help!\n\n';

      if (currentLocation != null &&
          currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        // Add location details
        message += 'Current Location:\n';
        message +=
            'https://www.google.com/maps/search/?api=1&query=${currentLocation.latitude},${currentLocation.longitude}\n\n';
        message += 'Coordinates:\n';
        message += 'Latitude: ${currentLocation.latitude}\n';
        message += 'Longitude: ${currentLocation.longitude}\n\n';
      } else {
        message += 'Location information not available\n\n';
      }

      // Add timestamp in a readable format
      final now = DateTime.now();
      message +=
          'Sent on: ${now.day}/${now.month}/${now.year} at ${now.hour}:${now.minute}';

      // Create direct SMS URI for each recipient
      for (final recipient in recipients) {
        final Uri smsUri =
            Uri.parse('sms:$recipient?body=${Uri.encodeComponent(message)}');

        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening SMS app with emergency message'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error sending SOS messages: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send emergency messages'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchRoutes() async {
    final error = await _routeController.searchRoutes(
      _startController.text,
      _destinationController.text,
    );

    if (error != null) {
      _showSnackBar(error);
    } else {
      _showSnackBar('${_routeController.allRoutesData.length} routes found');
      Future.delayed(Duration(milliseconds: 500), () {});
    }
  }

  Future<void> _processWithML() async {
    final result = await _routeController.processWithML();
    if (result != null) {
      MLResultDialog.show(context, result);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildMapsPage();
      case 1:
        return const ChatbotPage();
      case 2:
        return const ResourcesPage();
      case 3:
        return const ProfilePage();
      default:
        return _buildMapsPage();
    }
  }

  Widget _buildMapsPage() {
    return Stack(
      children: [
        Column(
          children: [
            ListenableBuilder(
              listenable: _routeController,
              builder: (context, child) {
                return RouteInputSection(
                  startController: _startController,
                  destinationController: _destinationController,
                  onSearchRoutes: _searchRoutes,
                  onMLProcess: _routeController.allRoutesData.isNotEmpty
                      ? _processWithML
                      : null,
                  isProcessingML: _routeController.isProcessingML,
                  routeCount: _routeController.allRoutesData.length,
                  hasMLSelection: _routeController.mlSelectedRoute != null,
                );
              },
            ),
            Expanded(child: MapWidget(controller: _routeController)),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _sendSOSMessage,
            backgroundColor: Colors.red,
            child: const Icon(Icons.sos, color: Colors.white),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_currentIndex != 0) return null;

    return AppBar(
      title: const Text('SafeSteps'),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      foregroundColor: Colors.black,
      actions: [
        ListenableBuilder(
          listenable: _routeController,
          builder: (context, child) {
            if (_routeController.allRoutesData.isEmpty) return const SizedBox();

            return Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.list),
                  onPressed: () => RouteSummaryDialog.show(
                    context,
                    _routeController.allRoutesData,
                    _routeController.mlSelectedRoute,
                  ),
                  tooltip: 'View Routes Summary',
                ),
                IconButton(
                  icon: Icon(Icons.bug_report),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => APIConnectionTest()),
                    );
                  },
                  tooltip: 'View JSON Data',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _destinationController.dispose();
    _routeController.dispose();
    super.dispose();
  }
}
