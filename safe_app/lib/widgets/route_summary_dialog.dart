import 'package:flutter/material.dart';
import '../models/route_model.dart';

class RouteSummaryDialog extends StatelessWidget {
  final List<RouteModel> routes;
  final RouteModel? selectedRoute;

  const RouteSummaryDialog({
    super.key,
    required this.routes,
    this.selectedRoute,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Routes Summary (${routes.length} routes)'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            final isSelected = route == selectedRoute;
            
            return Card(
              color: isSelected ? Colors.green.shade50 : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? Colors.green : Colors.blue,
                  child: Text('${index + 1}'),
                ),
                title: Text(route.summary),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Distance: ${route.distance}'),
                    Text('Duration: ${route.duration}'),
                    if (isSelected)
                      Text(
                        '✓ ML Selected',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        ),
      ),
      actions: [
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
      builder: (context) => RouteSummaryDialog(
        routes: routes,
        selectedRoute: selectedRoute,
      ),
    );
  }
}
