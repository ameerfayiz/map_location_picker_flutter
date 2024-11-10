import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_location_picker_flutter/map_location_picker_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Picker Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LocationResult? _selectedLocation;

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPickerV2(
          // Basic configuration
          initialLocation: LatLng(37.7749, -122.4194),
          initialZoom: 12,
          mapTileUrl: "https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",

          // UI customization
          primaryColor: Colors.blue,
          secondaryColor: Colors.white,
          markerColor: Colors.red,
          markerSize: 80,
          buttonSize: 50,
          labelHeight: 60,
          labelRoundness: 50,

          // Text customization
          searchHintText: "Search location...",
          labelTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),

          // Animation customization
          mapMoveDuration: Duration(milliseconds: 800),
          zoomDuration: Duration(milliseconds: 300),
          rotationResetDuration: Duration(milliseconds: 400),
          animationCurve: Curves.easeInOutCubic,

          // Callbacks
          onLocationSelected: (result) {
            print("Selected: ${result.coordinates}");
            print("Location: ${result.nearBy?.name}");
          },
          onMapMove: (location) {
            print("Map moved to: $location");
          },
          onSearchTextChanged: (text) {
            print("Searching for: $text");
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result as LocationResult;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Picker Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Location selection button
            ElevatedButton.icon(
              onPressed: _openLocationPicker,
              icon: const Icon(Icons.location_on),
              label: const Text('Choose Location'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 24),

            // Selected location display
            if (_selectedLocation != null) ...[
              const Text(
                'Selected Location:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Location details card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location name/address
                      if (_selectedLocation?.nearBy != null) ...[
                        Text(
                          _selectedLocation?.nearBy?.name ?? 'Unknown Location',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Additional address components
                        if (_selectedLocation?.nearBy?.street != null) Text('Street: ${_selectedLocation?.nearBy?.street}'),
                        if (_selectedLocation?.nearBy?.city != null) Text('City: ${_selectedLocation?.nearBy?.city}'),
                        if (_selectedLocation?.nearBy?.state != null) Text('State: ${_selectedLocation?.nearBy?.state}'),
                        const SizedBox(height: 12),
                      ],

                      // Coordinates
                      Text(
                        'Coordinates: ${_selectedLocation?.coordinates?.latitude.toStringAsFixed(6)}, '
                        '${_selectedLocation?.coordinates?.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Clear selection button
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedLocation = null;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Selection'),
              ),
            ] else ...[
              // No location selected state
              const Center(
                child: Text(
                  'No location selected',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Optional: Custom location result display widget
class LocationResultCard extends StatelessWidget {
  final LocationResult location;
  final VoidCallback onClear;

  const LocationResultCard({
    Key? key,
    required this.location,
    required this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Selected Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                ),
              ],
            ),
            const Divider(),
            if (location.nearBy != null) ...[
              ListTile(
                leading: const Icon(Icons.place),
                title: Text(location.nearBy?.name ?? 'Unknown Location'),
                subtitle: Text([
                  location.nearBy?.street,
                  location.nearBy?.city,
                  location.nearBy?.state,
                ].where((e) => e != null).join(', ')),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.gps_fixed),
              title: Text(
                'Lat: ${location.coordinates?.latitude.toStringAsFixed(6)}\n'
                'Lng: ${location.coordinates?.longitude.toStringAsFixed(6)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
