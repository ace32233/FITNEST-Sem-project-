import 'dart:convert';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NutritionData {
  final String foodName;
  final String servingSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionData({
    required this.foodName,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

class FatSecretNutritionService {
  static const String _tokenUrl = 'https://oauth.fatsecret.com/connect/token';
  static const String _apiUrl = 'https://platform.fatsecret.com/rest/server.api';

  final String _clientId;
  final String _clientSecret;
  final String _scope;

  String? _accessToken;
  DateTime? _tokenExpiry;

  FatSecretNutritionService()
      : _clientId = (dotenv.env['FATSECRET_CLIENT_ID'] ?? '').trim(),
        _clientSecret = (dotenv.env['FATSECRET_CLIENT_SECRET'] ?? '').trim(),
        _scope = (dotenv.env['FATSECRET_SCOPE'] ?? 'basic').trim() {
    if (_clientId.isEmpty || _clientSecret.isEmpty) {
      throw Exception('Missing FATSECRET credentials');
    }
  }

  Future<NutritionData?> getNutritionInfo(String input) async {
    final q = input.trim();
    if (q.isEmpty) return null;

    final grams = _extractGrams(q);
    final searchQuery = _cleanQueryForSearch(q);

    try {
      log('FatSecret: input="$q" grams=$grams search="$searchQuery"');

      final token = await _getAccessToken();
      if (token == null) {
        print('FatSecret: token is NULL');
        return null;
      }

      final foodId = await _searchFoodId(token, searchQuery);
      if (foodId == null) {
        print('FatSecret: foodId is NULL for "$searchQuery"');
        return null;
      }

      final details = await _getFoodDetails(token, foodId);
      if (details == null) {
        print('FatSecret: details is NULL for food_id=$foodId');
        return null;
      }

      final foodName = (details['food_name'] ?? '').toString().trim();
      final servingsRaw = details['servings']?['serving'];

      if (foodName.isEmpty || servingsRaw == null) {
        print('FatSecret: missing food_name or servings');
        return null;
      }

      final List<Map<String, dynamic>> servings = (servingsRaw is List)
          ? (servingsRaw as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [Map<String, dynamic>.from(servingsRaw as Map)];

      if (servings.isEmpty) {
        print('FatSecret: servings empty');
        return null;
      }

      final selected = _chooseBestServing(servings, grams);

      final cal = _toDouble(selected['calories']);
      final protein = _toDouble(selected['protein']);
      final carbs = _toDouble(selected['carbohydrate']);
      final fat = _toDouble(selected['fat']);

      final scaled = _scaleByGramsIfPossible(
        grams: grams,
        serving: selected,
        calories: cal,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );

      if (scaled.calories <= 0 &&
          scaled.protein <= 0 &&
          scaled.carbs <= 0 &&
          scaled.fat <= 0) {
        print('FatSecret: all macros zero');
        return null;
      }

      return NutritionData(
        foodName: foodName,
        servingSize: scaled.servingSizeLabel ??
            (selected['serving_description'] ?? '').toString(),
        calories: scaled.calories,
        protein: scaled.protein,
        carbs: scaled.carbs,
        fat: scaled.fat,
      );
    } catch (e, st) {
      log('FatSecret error: $e', stackTrace: st);
      return null;
    }
  }

  Future<String?> _getAccessToken() async {
    final now = DateTime.now();
    if (_accessToken != null &&
        _tokenExpiry != null &&
        now.isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    final basicAuth = base64Encode(utf8.encode('$_clientId:$_clientSecret'));

    final res = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Authorization': 'Basic $basicAuth',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials', 'scope': _scope},
    );

    print('FatSecret token status=${res.statusCode}');
    print('FatSecret token body=${res.body}');

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['access_token']?.toString();
    final expiresIn = (data['expires_in'] is num)
        ? (data['expires_in'] as num).toInt()
        : int.tryParse('${data['expires_in']}') ?? 3600;

    if (token == null || token.isEmpty) return null;

    _accessToken = token;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
    return token;
  }

  Future<String?> _searchFoodId(String token, String query) async {
    final res = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'method': 'foods.search',
        'search_expression': query,
        'page_number': '0',
        'max_results': '5',
        'format': 'json',
      },
    );

    print('FatSecret search status=${res.statusCode}');
    print('FatSecret search body=${res.body}');

    if (res.statusCode != 200) return null;

    final root = jsonDecode(res.body) as Map<String, dynamic>;
    if (root['error'] != null) {
      print('FatSecret search error=${root['error']}');
      return null;
    }

    final foods = root['foods']?['food'];
    if (foods == null) return null;

    final Map<String, dynamic> firstFood = (foods is List)
        ? Map<String, dynamic>.from(foods.first)
        : Map<String, dynamic>.from(foods);

    return firstFood['food_id']?.toString();
  }

  Future<Map<String, dynamic>?> _getFoodDetails(
      String token, String foodId) async {
    final res = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'method': 'food.get', 'food_id': foodId, 'format': 'json'},
    );

    print('FatSecret details status=${res.statusCode}');
    print('FatSecret details body=${res.body}');

    if (res.statusCode != 200) return null;

    final root = jsonDecode(res.body) as Map<String, dynamic>;
    if (root['error'] != null) {
      print('FatSecret details error=${root['error']}');
      return null;
    }

    final food = root['food'];
    if (food is Map<String, dynamic>) return food;

    return null;
  }

  int? _extractGrams(String s) {
    final m = RegExp(r'(\d+(\.\d+)?)\s*(g|gm)\b', caseSensitive: false)
        .firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(1) ?? '')?.round();
  }

  String _cleanQueryForSearch(String q) {
    var s = q.toLowerCase();
    s = s.replaceAll(RegExp(r'\b\d+(\.\d+)?\s*(g|gm)\b'), '');
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? q : s;
  }

  Map<String, dynamic> _chooseBestServing(
      List<Map<String, dynamic>> servings, int? grams) {
    if (grams == null) return servings.first;

    final gramsServings = servings.where((s) {
      final unit = (s['metric_serving_unit'] ?? '').toString().toLowerCase();
      return unit == 'g';
    }).toList();

    if (gramsServings.isEmpty) return servings.first;

    gramsServings.sort((a, b) {
      final da = (_toDouble(a['metric_serving_amount']) - grams).abs();
      final db = (_toDouble(b['metric_serving_amount']) - grams).abs();
      return da.compareTo(db);
    });

    return gramsServings.first;
  }

  _ScaledResult _scaleByGramsIfPossible({
    required int? grams,
    required Map<String, dynamic> serving,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    if (grams == null) {
      return _ScaledResult(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
    }

    final unit =
        (serving['metric_serving_unit'] ?? '').toString().toLowerCase();
    final amt = _toDouble(serving['metric_serving_amount']);

    if (unit != 'g' || amt <= 0) {
      return _ScaledResult(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
    }

    final factor = grams / amt;

    return _ScaledResult(
      servingSizeLabel: '${grams} g',
      calories: calories * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class _ScaledResult {
  final String? servingSizeLabel;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  _ScaledResult({
    this.servingSizeLabel,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}
