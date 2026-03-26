import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/game.dart';
import '../app_constants.dart';

class GameService {
  static const String baseUrl = '${AppConstants.apiBaseUrl}/games';

  /// Fetch all available games from the backend
  static Future<List<Game>> fetchGames() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/list'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] is List) {
          final games = (json['data'] as List).map((gameData) {
            try {
              return Game.fromJson(gameData as Map<String, dynamic>);
            } catch (e) {
              throw Exception('Error parsing game: $e, data: $gameData');
            }
          }).toList();
          return games;
        }
        return [];
      } else {
        throw Exception('Failed to fetch games: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching games: $e');
    }
  }
}
