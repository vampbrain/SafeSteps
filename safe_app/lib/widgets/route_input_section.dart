import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['place_id'],
      description: json['description'],
      mainText: json['structured_formatting']['main_text'],
      secondaryText: json['structured_formatting']['secondary_text'] ?? '',
    );
  }
}

class RouteInputSection extends StatefulWidget {
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
  State<RouteInputSection> createState() => _RouteInputSectionState();
}

class _RouteInputSectionState extends State<RouteInputSection> {
  List<PlaceSuggestion> _startSuggestions = [];
  List<PlaceSuggestion> _destinationSuggestions = [];
  bool _showStartSuggestions = false;
  bool _showDestinationSuggestions = false;
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startFocusNode.addListener(() {
      if (!_startFocusNode.hasFocus) {
        setState(() => _showStartSuggestions = false);
      }
    });
    _destinationFocusNode.addListener(() {
      if (!_destinationFocusNode.hasFocus) {
        setState(() => _showDestinationSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _startFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  Future<List<PlaceSuggestion>> _getPlaceSuggestions(String input) async {
    if (input.length < 3) return [];

    try {
      final String url = 
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(input)}'
          '&components=country:in'
          '&location=12.9716,77.5946' // Bangalore coordinates
          '&radius=50000'
          '&key=${AppConstants.googleMapsApiKey}';

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['predictions'] as List)
              .map((prediction) => PlaceSuggestion.fromJson(prediction))
              .toList();
        }
      }
    } catch (e) {
      print('Error fetching place suggestions: $e');
    }
    return [];
  }

  void _onStartTextChanged(String value) {
    if (value.length >= 3) {
      _getPlaceSuggestions(value).then((suggestions) {
        setState(() {
          _startSuggestions = suggestions;
          _showStartSuggestions = suggestions.isNotEmpty;
        });
      });
    } else {
      setState(() {
        _startSuggestions = [];
        _showStartSuggestions = false;
      });
    }
  }

  void _onDestinationTextChanged(String value) {
    if (value.length >= 3) {
      _getPlaceSuggestions(value).then((suggestions) {
        setState(() {
          _destinationSuggestions = suggestions;
          _showDestinationSuggestions = suggestions.isNotEmpty;
        });
      });
    } else {
      setState(() {
        _destinationSuggestions = [];
        _showDestinationSuggestions = false;
      });
    }
  }

  void _selectStartSuggestion(PlaceSuggestion suggestion) {
    widget.startController.text = suggestion.description;
    setState(() {
      _showStartSuggestions = false;
      _startSuggestions = [];
    });
    _startFocusNode.unfocus();
  }

  void _selectDestinationSuggestion(PlaceSuggestion suggestion) {
    widget.destinationController.text = suggestion.description;
    setState(() {
      _showDestinationSuggestions = false;
      _destinationSuggestions = [];
    });
    _destinationFocusNode.unfocus();
  }

  Widget _buildSuggestionsList(List<PlaceSuggestion> suggestions, Function(PlaceSuggestion) onSelect) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ListTile(
            dense: true,
            leading: Icon(Icons.location_on, color: Colors.grey.shade600, size: 20),
            title: Text(
              suggestion.mainText,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: suggestion.secondaryText.isNotEmpty 
                ? Text(suggestion.secondaryText, style: TextStyle(fontSize: 12))
                : null,
            onTap: () => onSelect(suggestion),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Start Location Field with Suggestions
          Column(
            children: [
              TextField(
                controller: widget.startController,
                focusNode: _startFocusNode,
                onChanged: _onStartTextChanged,
                decoration: InputDecoration(
                  labelText: 'Start Location',
                  hintText: 'Enter start location or type "Current Location"',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.my_location),
                ),
              ),
              if (_showStartSuggestions && _startSuggestions.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 4),
                  constraints: BoxConstraints(maxHeight: 200),
                  child: _buildSuggestionsList(_startSuggestions, _selectStartSuggestion),
                ),
            ],
          ),
          
          SizedBox(height: 10),
          
          // Destination Field with Suggestions
          Column(
            children: [
              TextField(
                controller: widget.destinationController,
                focusNode: _destinationFocusNode,
                onChanged: _onDestinationTextChanged,
                decoration: InputDecoration(
                  labelText: 'Destination',
                  hintText: 'Enter destination',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              if (_showDestinationSuggestions && _destinationSuggestions.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 4),
                  constraints: BoxConstraints(maxHeight: 200),
                  child: _buildSuggestionsList(_destinationSuggestions, _selectDestinationSuggestion),
                ),
            ],
          ),
          
          SizedBox(height: 10),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onSearchRoutes,
                  child: Text('Show Routes'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onMLProcess,
                  child: widget.isProcessingML 
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('🤖 ML Select'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.hasMLSelection 
                        ? Colors.green.shade600 
                        : Colors.blue.shade600,
                  ),
                ),
              ),
            ],
          ),
          
          // Route Count and ML Status
          if (widget.routeCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.routeCount} routes found',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.hasMLSelection)
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