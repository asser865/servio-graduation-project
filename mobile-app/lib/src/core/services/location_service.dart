import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._();
  LocationService._();
  factory LocationService() => _instance;

  Future<LatLng?> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final status = await Permission.location.request();
    if (!status.isGranted) return null;
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 30),
    );
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  Future<LatLng?> geocodeAddress(String address) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': address,
        'format': 'json',
        'limit': '1',
      });
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'ServioApp/1.0 (gradproject096@gmail.com)'},
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as List<dynamic>;
      if (data.isEmpty) return null;
      final lat = double.tryParse(data[0]['lat'] as String? ?? '');
      final lon = double.tryParse(data[0]['lon'] as String? ?? '');
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }
}
