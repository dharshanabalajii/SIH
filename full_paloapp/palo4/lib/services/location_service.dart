import 'package:http/http.dart' as http;

class LocationService {
  // Set your backend IP and port here
  static const String backendBaseUrl = 'http://192.168.1.9:5000';

  Future<String> fetchSensorData() async {
    final url = Uri.parse('$backendBaseUrl/location');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to fetch sensor data');
    }
  }
}