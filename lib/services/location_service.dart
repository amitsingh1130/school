import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class LocationService {
  // --- SWARAJ CONVENT SCHOOL COORDINATES ---
  static const double schoolLat = 25.2795468;
  static const double schoolLng = 83.0424826;
  static const double allowedRadius = 200.0; // 200 meters radius

  static Future<bool> checkLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable Location Services (GPS) on your phone.")),
        );
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied. Cannot mark attendance.")),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permissions are permanently denied. Please enable them in settings.")),
        );
      }
      return false;
    }

    // Get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        schoolLat,
        schoolLng,
      );

      if (distanceInMeters <= allowedRadius) {
        return true;
      } else {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Out of Range"),
              content: Text(
                "Aap school campus se ${(distanceInMeters - allowedRadius).toStringAsFixed(0)}m bahar hain. Attendance sirf school ke andar hi lag sakti hai."
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
              ],
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting location: $e")),
        );
      }
      return false;
    }
  }
}
