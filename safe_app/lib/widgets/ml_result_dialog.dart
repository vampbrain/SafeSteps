import 'package:flutter/material.dart';

class MLResultDialog extends StatelessWidget {
  final Map<String, dynamic> result;

  const MLResultDialog({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🤖 ML Route Selection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confidence: ${(result['confidence'] * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text('Reasoning: ${result['reasoning']}'),
          const SizedBox(height: 10),
          const Text('Safety Factors:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...List<String>.from(result['safety_factors']).map(
            (factor) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text('• $factor'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }

  static void show(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => MLResultDialog(result: result),
    );
  }
}
