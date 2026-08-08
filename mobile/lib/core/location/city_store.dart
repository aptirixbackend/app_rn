import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cities the app serves (must match the cities present in the DB seed).
const kCities = ['Bengaluru', 'Chennai', 'Hyderabad', 'Mumbai'];

/// Approximate city centres — used to snap a GPS fix to the nearest served city.
const _cityCenters = <String, (double, double)>{
  'Bengaluru': (12.9716, 77.5946),
  'Chennai': (13.0827, 80.2707),
  'Hyderabad': (17.4401, 78.3489),
  'Mumbai': (19.0760, 72.8777),
};

/// Approx centre `(lat, lng)` of a served city — used to seed the posting
/// map pin. Falls back to the first city for anything unknown.
(double, double) cityCenter(String city) =>
    _cityCenters[city] ?? _cityCenters[kCities.first]!;

const _kCity = 'selected_city';

/// The city selected in the top bar — drives every city-scoped listing feed.
class SelectedCity extends Notifier<String> {
  @override
  String build() {
    _load();
    return kCities.first;
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final c = p.getString(_kCity);
    if (c != null && c.isNotEmpty) {
      state = c; // returning user — keep their last city
    } else {
      // First launch → auto-detect the nearest city from GPS. Once set, it's
      // persisted, so later launches use the saved city (and it survives
      // navigation via this app-scoped provider).
      await detectNearestCity();
    }
  }

  Future<void> set(String city) async {
    state = city;
    (await SharedPreferences.getInstance()).setString(_kCity, city);
  }

  /// Detect the device's GPS location and switch to the nearest served city.
  /// Returns the city on success, or null if location is denied/unavailable.
  Future<String?> detectNearestCity() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final city = _nearest(pos.latitude, pos.longitude);
      await set(city);
      return city;
    } catch (_) {
      return null;
    }
  }

  String _nearest(double lat, double lng) {
    var best = kCities.first;
    var bestD = double.infinity;
    _cityCenters.forEach((city, c) {
      final dLat = lat - c.$1;
      final dLng = lng - c.$2;
      final d = dLat * dLat + dLng * dLng;
      if (d < bestD) {
        bestD = d;
        best = city;
      }
    });
    return best;
  }
}

final selectedCityProvider =
    NotifierProvider<SelectedCity, String>(SelectedCity.new);
