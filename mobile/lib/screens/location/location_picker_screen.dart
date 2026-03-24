import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// Default center: Los Baños, Laguna, Philippines
const _defaultCenter = LatLng(14.1698, 121.2430);

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();

  LatLng _pickedLocation = _defaultCenter;
  bool _locationLoading = false;
  bool _hasMovedPin = false;

  @override
  void initState() {
    super.initState();
    // Immediately request permission and fly to device location
    // WidgetsBinding.instance.addPostFrameCallback((_) => _goToMyLocation());
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _goToMyLocation() async {
    setState(() => _locationLoading = true);

    try {
      // Always request permission — never skip
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showSnack('Please enable location services on your device.');
        }
        setState(() => _locationLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionDialog();
        }
        setState(() => _locationLoading = false);
        return;
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showSnack('Location permission denied. Please pick manually.');
        }
        setState(() => _locationLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final myLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _pickedLocation = myLocation;
          _locationLoading = false;
        });
        _mapController.move(myLocation, 16);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationLoading = false);
        _showSnack('Could not get location. Please pick manually on the map.');
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'MapSumbong needs your location to accurately log the incident. '
          'Please enable it in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Pick manually'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  void _confirmLocation() {
    // Return the picked LatLng to the caller (ReportsListScreen / HomeScreen)
    Navigator.of(context).pop(_pickedLocation);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin Your Location'),
        actions: [
          if (_locationLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 14,
              onTap: (_, point) {
                setState(() {
                  _pickedLocation = point;
                  _hasMovedPin = true;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mapsumbong',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _pickedLocation,
                    width: 48,
                    height: 48,
                    child: const _PinMarker(),
                  ),
                ],
              ),
            ],
          ),

          // Instruction card at top
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _hasMovedPin
                            ? 'Pin placed. Move it or tap Confirm.'
                            : 'Tap the map to place a pin on the incident location.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // My location FAB
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              onPressed: _locationLoading ? null : _goToMyLocation,
              tooltip: 'Go to my location',
              child: _locationLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),

          // Coordinates display
          Positioned(
            bottom: 90,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ],
              ),
              child: Text(
                '${_pickedLocation.latitude.toStringAsFixed(5)}, '
                '${_pickedLocation.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),

      // Confirm button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton.icon(
            onPressed: _confirmLocation,
            icon: const Icon(Icons.check),
            label: const Text('Confirm Location',
                style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pin marker ────────────────────────────────────────────────────────────────

class _PinMarker extends StatelessWidget {
  const _PinMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.location_on,
              color: Colors.white, size: 16),
        ),
        // Pin stem
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}