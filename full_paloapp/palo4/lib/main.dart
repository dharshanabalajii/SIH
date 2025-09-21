import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import 'services/location_service.dart';

String sosStatus = "0"; // Global variable

void main() => runApp(const MyApp());

enum GeofenceMode { radius, polygon }

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geofence Sensor App',
      home: LiveDataScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LiveDataScreen extends StatefulWidget {
  const LiveDataScreen({super.key});
  @override
  _LiveDataScreenState createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  final LocationService _locationService = LocationService();
  Timer? _timer;
  GeofenceMode _mode = GeofenceMode.radius;
  bool _drawing = false;
  List<latlng.LatLng> _polygonPoints = [];
  final MapController _mapController = MapController();

  Map<String, String> _sensorData = {
    "HR": "-",
    "SpO2": "-",
    "Temp": "-",
    "Touch": "-",
    "Lat": "-",
    "Lng": "-",
    "HR_avg": "-",
    "SOS": "",
  };

  Position? _userPosition;
  String _geofenceStatus = "Waiting for data...";

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _fetchAll();
    _timer = Timer.periodic(Duration(seconds: 5), (_) => _fetchAll());
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage("Please enable location services.");
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMessage("Location permission denied.");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showMessage("Location permission permanently denied.");
      return;
    }
    await _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userPosition = pos;
      });
      _mapController.move(
        latlng.LatLng(pos.latitude, pos.longitude),
        16,
      );
    } catch (e) {
      _showMessage("Error getting user location: $e");
    }
  }

  Future<void> _fetchSensorData() async {
    try {
      final raw = await _locationService.fetchSensorData();
      final parsed = _parseSensorData(raw);
      setState(() {
        _sensorData = parsed;
      });
    } catch (e) {
      _showMessage("Error fetching sensor data: $e");
    }
  }

  Map<String, String> _parseSensorData(String data) {
    Map<String, String> map = {
      "HR": "-",
      "SpO2": "-",
      "Temp": "-",
      "Touch": "-",
      "Lat": "-",
      "Lng": "-",
      "HR_avg": "-",
      "SOS": "",
    };
    final parts = data.split(',');
    for (var part in parts) {
      final kv = part.split(':');
      // if (kv.length == 2) {
      //   map[kv[0].trim()] = kv[1].trim();
      // }
    if (kv.length == 2) {
      String key = kv[0].trim();
      String value = kv[1].trim();

      if (key == ".Lat") key = "Lat";
      if (key == "Sp02") key = "SpO2";

      map[key] = value;
    }
    }
    return map;
  }

  Future<void> _fetchAll() async {
    await _getUserLocation();
    await _fetchSensorData();
    _calculateGeofence();
  }

  void _calculateGeofence() {
    double? sensorLat = double.tryParse(_sensorData["Lat"] ?? "");
    double? sensorLng = double.tryParse(_sensorData["Lng"] ?? "");

    if (sensorLat == null || sensorLng == null) {
      setState(() {
        _geofenceStatus = "Invalid sensor coordinates.";
      });
      return;
    }

    if (_mode == GeofenceMode.radius) {
      if (_userPosition == null) {
        setState(() {
          _geofenceStatus = "User location not available.";
        });
        return;
      }
      double distanceMeters = _calculateDistance(
        _userPosition!.latitude, _userPosition!.longitude, sensorLat, sensorLng);
      const double geofenceRadius = 30; // meters
      bool inside = distanceMeters <= geofenceRadius;
      setState(() {
        _geofenceStatus = inside
            ? "user is INSIDE geofence (distance: ${distanceMeters.toStringAsFixed(1)} m)"
            : "user is OUTSIDE geofence (distance: ${distanceMeters.toStringAsFixed(1)} m)";
      });
    } else {
      if (_polygonPoints.length < 3) {
        setState(() {
          _geofenceStatus = "Draw a polygon to define geofence.";
        });
        return;
      }
      bool inside = _pointInPolygon(latlng.LatLng(sensorLat, sensorLng), _polygonPoints);
      setState(() {
        _geofenceStatus = inside
            ? "user is INSIDE the polygon geofence."
            : "user is OUTSIDE the polygon geofence.";
      });
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) *
            cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) /
            2;
    return 12742000 * asin(sqrt(a));
  }

  bool _pointInPolygon(latlng.LatLng point, List<latlng.LatLng> polygon) {
    int i, j = polygon.length - 1;
    bool inside = false;
    for (i = 0; i < polygon.length; i++) {
      if (((polygon[i].latitude > point.latitude) != (polygon[j].latitude > point.latitude)) &&
          (point.longitude < (polygon[j].longitude - polygon[i].longitude) * (point.latitude - polygon[i].latitude) /
              (polygon[j].latitude - polygon[i].latitude) + polygon[i].longitude)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  void _toggleDrawing() {
    setState(() {
      _drawing = !_drawing;
      if (!_drawing && _polygonPoints.length >= 3) {
        _calculateGeofence();
      }
    });
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
      _geofenceStatus = "Polygon cleared. Draw a new geofence.";
    });
  }

  void _onMapTap(latlng.LatLng point) {
    if (!_drawing || _mode != GeofenceMode.polygon) return;
    setState(() {
      _polygonPoints.add(point);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSensorDataRow(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    latlng.LatLng center = _userPosition != null
        ? latlng.LatLng(_userPosition!.latitude, _userPosition!.longitude)
        : latlng.LatLng(11.648493, 78.15091);

    double? sensorLat = double.tryParse(_sensorData["Lat"] ?? "");
    double? sensorLng = double.tryParse(_sensorData["Lng"] ?? "");
    latlng.LatLng? sensorPoint = (sensorLat != null && sensorLng != null)
        ? latlng.LatLng(sensorLat, sensorLng)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Palo Patch'),
        actions: [
          PopupMenuButton<GeofenceMode>(
            icon: const Icon(Icons.settings),
            onSelected: (val) {
              setState(() {
                _mode = val;
                _drawing = false;
                if (_mode == GeofenceMode.radius) {
                  _polygonPoints.clear();
                }
                _calculateGeofence();
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: GeofenceMode.radius, child: Text("Crowd")),
              const PopupMenuItem(value: GeofenceMode.polygon, child: Text("Route Fencing")),
            ],
          ),
          if (_mode == GeofenceMode.polygon)
            IconButton(
              icon: Icon(_drawing ? Icons.check : Icons.edit),
              onPressed: _toggleDrawing,
              tooltip: _drawing ? 'Finish Drawing' : 'Start Drawing',
            ),
          if (_mode == GeofenceMode.polygon)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearPolygon,
              tooltip: 'Clear Polygon',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAll,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                onMapReady: () {
                  if (_userPosition != null) {
                    _mapController.move(
                      latlng.LatLng(_userPosition!.latitude, _userPosition!.longitude),
                      16,
                    );
                  }
                },
                onTap: (tapPosition, latlng) => _onMapTap(latlng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.palo4',
                ),
                if (_mode == GeofenceMode.radius && _userPosition != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: center,
                        color: const Color.fromARGB(255, 85, 0, 89).withOpacity(0.2),
                        borderStrokeWidth: 2,
                        borderColor: const Color.fromARGB(255, 146, 114, 151),
                        radius: 3,
                        useRadiusInMeter: true,
                      ),
                    ],
                  ),
                if (_mode == GeofenceMode.polygon && _polygonPoints.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _polygonPoints,
                        color: const Color.fromARGB(255, 176, 131, 174).withOpacity(0.2),
                        borderStrokeWidth: 3,
                        borderColor: const Color.fromARGB(255, 187, 78, 156),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_userPosition != null)
                      Marker(
                        width: 40,
                        height: 40,
                        point: center,
                        child: const Icon(Icons.person_pin_circle, color: Color.fromARGB(255, 136, 35, 129), size: 40),
                      ),
                    if (sensorPoint != null)
                      Marker(
                        width: 40,
                        height: 40,
                        point: sensorPoint,
                        child: const Icon(Icons.sensors, color: Color.fromARGB(255, 251, 31, 123), size: 40),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: ListView(
              children: [
                const ListTile(title: Text('Sensor Data', style: TextStyle(fontWeight: FontWeight.bold))),
                _buildSensorDataRow('HR', _sensorData["HR"] ?? "-"),
                _buildSensorDataRow('HR (10s Avg)', _sensorData["HR_avg"] ?? "-"),
                _buildSensorDataRow('SpO2', _sensorData["SpO2"] ?? "-"),
                _buildSensorDataRow('Temp', _sensorData["Temp"] ?? "-"),
                _buildSensorDataRow('Touch', _sensorData["Touch"] ?? "-"),
                _buildSensorDataRow('Latitude', _sensorData["Lat"] ?? "-"),
                _buildSensorDataRow('Longitude', _sensorData["Lng"] ?? "-"),
                _buildSensorDataRow('SOS', _sensorData["SOS"] ?? "-"),
                //_buildSensorDataRow('SOS', (_sensorData["SOS"]?.isNotEmpty ?? false) ? "1" : "0"),
                //_buildSensorDataRow(
                //  'SOS',
                //  _sensorData["SOS"] == "ALERT: SOS Detected!" ? "1" : "0",
                //),
                //if (_sensorData["SOS"]?.isNotEmpty ?? false)
                //  ListTile(
                //    title: Text('SOS ALERT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                //    subtitle: Text(_sensorData["SOS"]!),
                //  ),
                const Divider(),
                ListTile(
                  title: const Text('Geofence Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_geofenceStatus),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _fetchAll,
                  child: const Text('Refresh Data & Map'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}