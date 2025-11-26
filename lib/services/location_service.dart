import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Байршлын үйлчилгээ идэвхгүй байна');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Байршлын зөвшөөрөл олгогдоогүй');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Байршлын зөвшөөрөл бүрмөсөн татгалзсан');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Location error: $e');
      return null;
    }
  }

  Future<double> getDistanceFromAccident(double lat1, double lon1, double lat2, double lon2) async {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
