import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/route_model.dart';

class JsonDataDialog extends StatelessWidget {
  final List<RouteModel> routes;
  final RouteModel? selectedRoute;

  const JsonDataDialog({
    super.key,
    required this.routes,
    this.selectedRoute,
  });

  @override
  Widget build(BuildContext context) {
    final jsonData = {
      'total_routes': routes.length,
      'ml_selected_route': selectedRoute?.toJson(),
      'all_routes': routes.map((route) => route.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

    return AlertDialog(
      title: const Text('Route Data (JSON)'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: SingleChildScrollView(
          child: SelectableText(
            jsonString,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: jsonString));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('JSON data copied to clipboard')),
            );
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  static void show(BuildContext context, List<RouteModel> routes, RouteModel? selectedRoute) {
    showDialog(
      context: context,
      builder: (context) => JsonDataDialog(
        routes: routes,
        selectedRoute: selectedRoute,
      ),
    );
  }
}
