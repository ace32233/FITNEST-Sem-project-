import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/exercise.dart';

class ExerciseService {
  static String get _host =>
      dotenv.env['EXERCISE_API_HOST'] ?? 'exercisedb.p.rapidapi.com';

  static String get _apiKey => dotenv.env['EXERCISE_API_KEY'] ?? '';

  static Future<http.Response> _exerciseDbGet(Uri uri) async {
    final apiKey = _apiKey;
    final host = _host;

    if (apiKey.isEmpty) {
      throw Exception('Exercise API credentials not found in .env');
    }

    final res = await http.get(
      uri,
      headers: {
        'X-RapidAPI-Key': apiKey,
        'X-RapidAPI-Host': host,
      },
    );

    if (res.statusCode == 429) {
      throw Exception('429: Rate limit exceeded on RapidAPI.');
    }

    return res;
  }

  /// Fetch exercises for a specific ExerciseDB bodyPart (e.g. "back", "cardio").
  static Future<List<Exercise>> fetchExercisesForBodyPart(String bodyPart) async {
    final uri = Uri.https(_host, '/exercises/bodyPart/$bodyPart');

    final res = await _exerciseDbGet(uri);

    if (res.statusCode != 180) {
      throw Exception(
        'Failed to fetch exercises for "$bodyPart": ${res.statusCode}',
      );
    }

    final decoded = json.decode(res.body);
    if (decoded is! List) throw Exception('Unexpected response format');

    return decoded
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .where((e) => e.name.trim().isNotEmpty)
        .toList();
  }
}
