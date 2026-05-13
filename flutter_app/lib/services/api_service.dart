import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String _baseUrl = '';
  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? '';
    _token = prefs.getString('admin_token');
  }

  static Future<void> setServerUrl(String url) async {
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _baseUrl);
  }

  static String get serverUrl => _baseUrl;
  static bool get isAdmin => _token != null;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // --- Auth ---

  static Future<bool> adminLogin(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'username=$username&password=$password',
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_token', _token!);
      return true;
    }
    return false;
  }

  static Future<void> adminLogout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
  }

  // --- Músicas ---

  static Future<List<Map<String, dynamic>>> getSongs({String? query}) async {
    final uri = Uri.parse('$_baseUrl/api/songs/').replace(
      queryParameters: query != null ? {'q': query} : null,
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Erro ao buscar músicas');
  }

  static String audioUrl(String songId) => '$_baseUrl/api/songs/$songId/audio';
  static String cdgUrl(String songId) => '$_baseUrl/api/songs/$songId/cdg';

  // --- Salas ---

  static Future<Map<String, dynamic>> joinRoom(String code) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/rooms/join'),
      headers: _headers,
      body: jsonEncode({'code': code}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Sala não encontrada');
  }

  static Future<Map<String, dynamic>> createRoom(String name) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/rooms/'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao criar sala');
  }

  static Future<List<Map<String, dynamic>>> getRooms() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/rooms/'), headers: _headers);
    if (response.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    throw Exception('Erro ao listar salas');
  }

  // --- Fila ---

  static Future<void> addToQueue(String roomId, String songId, String singerName) async {
    await http.post(
      Uri.parse('$_baseUrl/api/rooms/$roomId/queue'),
      headers: _headers,
      body: jsonEncode({'song_id': songId, 'singer_name': singerName}),
    );
  }

  static Future<List<Map<String, dynamic>>> getQueue(String roomId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/rooms/$roomId/queue'),
      headers: _headers,
    );
    if (response.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  // --- Score ---

  static Future<void> submitScore(String roomId, String singerName, int score, double accuracy) async {
    await http.post(
      Uri.parse('$_baseUrl/api/rooms/$roomId/score'),
      headers: _headers,
      body: jsonEncode({
        'singer_name': singerName,
        'score': score,
        'accuracy': accuracy,
      }),
    );
  }

  static Future<List<Map<String, dynamic>>> getScoreboard(String roomId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/rooms/$roomId/scoreboard'),
      headers: _headers,
    );
    if (response.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }
}
