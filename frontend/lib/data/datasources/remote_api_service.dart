import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

class RemoteApiService {
  final http.Client client;

  RemoteApiService({http.Client? client}) : client = client ?? http.Client();

  Future<bool> syncCheckInLogs(List<Map<String, dynamic>> logs) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.logsEndpoint}/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'logs': logs}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> login(String id, String password) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.authEndpoint}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'studentId': id, 'id': id, 'password': password}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> fetchLogs() async {
    try {
      final response = await client.get(Uri.parse(AppConstants.logsEndpoint));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> fetchConfigs() async {
    try {
      final response = await client.get(Uri.parse(AppConstants.configEndpoint));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
