import 'package:flutter/material.dart';

class RouteInputSection extends StatelessWidget {
  final TextEditingController startController;
  final TextEditingController destinationController;
  final VoidCallback onSearchRoutes;
  final VoidCallback? onMLProcess;
  final bool isProcessingML;
  final int routeCount;
  final bool hasMLSelection;

  const RouteInputSection({
    Key? key,
    required this.startController,
    required this.destinationController,
    required this.onSearchRoutes,
    this.onMLProcess,
    required this.isProcessingML,
    required this.routeCount,
    required this.hasMLSelection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: startController,
            decoration: InputDecoration(
              labelText: 'Start Location',
              hintText: 'Enter start location or type "Current Location"',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: destinationController,
            decoration: InputDecoration(
              labelText: 'Destination',
              hintText: 'Enter destination',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onSearchRoutes,
                  child: Text('Show Routes'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onMLProcess,
                  // ignore: sort_child_properties_last
                  child: isProcessingML 
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('🤖 ML Select'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasMLSelection 
                        ? Colors.green.shade600 
                        : Colors.blue.shade600,
                  ),
                ),
              ),
            ],
          ),
          if (routeCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$routeCount routes found',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasMLSelection)
                    Text(
                      '✓ ML Route Selected',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
