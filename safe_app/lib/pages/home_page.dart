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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RouteController _routeController = RouteController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
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

  Future<void> _searchRoutes() async {
    final error = await _routeController.searchRoutes(
      _startController.text,
      _destinationController.text,
    );

    if (error != null) {
      _showSnackBar(error);
    } else {
      _showSnackBar('${_routeController.allRoutesData.length} routes found');
      Future.delayed(Duration(milliseconds: 500), () {
      });
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
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ), 
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildMapsPage();
      case 1:
        return const ChatbotPage();
      case 2:
        return const Center(child: Text('Resources Coming Soon'));
      case 3:
        return const Center(child: Text('Profile Coming Soon'));
      default:
        return _buildMapsPage();
    }
  }

  Widget _buildMapsPage() {
    return Column(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeSteps'),
        backgroundColor: const Color.fromRGBO(198, 142, 253, 1.0),
        foregroundColor: Colors.black,
        actions: [
          ListenableBuilder(
            listenable: _routeController,
            builder: (context, child) {
              if (_routeController.allRoutesData.isEmpty)
                return const SizedBox();

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
                    icon: const Icon(Icons.code),
                    onPressed: () => JsonDataDialog.show(
                      context,
                      _routeController.allRoutesData,
                      _routeController.mlSelectedRoute,
                    ),
                    tooltip: 'View JSON Data',
                  ),
                ],
              );
            },
          ),
        ],
      ),
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