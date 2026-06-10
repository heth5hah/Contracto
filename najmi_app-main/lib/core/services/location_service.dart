import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationResult {
  final String? street;
  final String? city;
  final String? state;
  final String? pincode;
  final String? locality;
  final String? subLocality;
  final double latitude;
  final double longitude;

  LocationResult({
    this.street,
    this.city,
    this.state,
    this.pincode,
    this.locality,
    this.subLocality,
    required this.latitude,
    required this.longitude,
  });

  String get formattedAddress {
    final parts = <String>[];
    if (subLocality != null && subLocality!.isNotEmpty) parts.add(subLocality!);
    if (locality != null && locality!.isNotEmpty) parts.add(locality!);
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (pincode != null && pincode!.isNotEmpty) parts.add(pincode!);
    return parts.join(', ');
  }
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Check & request location permission, then get current position
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permission permanently denied. Please enable it in Settings.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Reverse geocode coordinates to address components
  Future<LocationResult> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return LocationResult(
          street: place.street,
          city: place.locality ?? place.subAdministrativeArea,
          state: place.administrativeArea,
          pincode: place.postalCode,
          locality: place.subAdministrativeArea,
          subLocality: place.subLocality,
          latitude: lat,
          longitude: lng,
        );
      }
      return LocationResult(latitude: lat, longitude: lng);
    } catch (e) {
      return LocationResult(latitude: lat, longitude: lng);
    }
  }

  /// One-shot: get position + reverse geocode
  Future<LocationResult> detectCurrentLocation() async {
    final position = await getCurrentPosition();
    return await reverseGeocode(position.latitude, position.longitude);
  }
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}
