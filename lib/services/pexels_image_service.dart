import 'dart:convert';
import 'package:http/http.dart' as http;

class PexelsImageService {
  final String apiKey;

  PexelsImageService(this.apiKey);

  Future<String?> searchFoodImage(String foodName) async {
    final q = foodName.trim();
    if (apiKey.trim().isEmpty || q.isEmpty) return null;

    final url = Uri.parse(
      "https://api.pexels.com/v1/search?query=${Uri.encodeComponent("$q food")}&per_page=3",
    );

    final res = await http.get(url, headers: {"Authorization": apiKey});

    if (res.statusCode != 200) return null;

    final data = json.decode(res.body);
    final photos = (data["photos"] as List?) ?? [];
    if (photos.isEmpty) return null;

    for (final p in photos) {
      final src = p is Map ? p["src"] : null;
      if (src is Map && src["medium"] is String) return src["medium"] as String;
    }
    return null;
  }
}
