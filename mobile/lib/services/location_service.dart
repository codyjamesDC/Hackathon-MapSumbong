import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Returns the current GPS position, or null if permission is denied
  /// or location services are off. Never throws — always fails gracefully.
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled at all
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Fetch position with a 10-second timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return position;
    } catch (e) {
      return null;
    }
  }

  /// Quick check — returns true only if we already have permission
  /// and location services are on. Does NOT prompt the user.
  static Future<bool> hasPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}