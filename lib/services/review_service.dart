import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';

class ReviewService {

  static Future<List> fetchProductReviews(String productId) async {

    final url = "${BackendConfig.baseUrl}/review/$productId";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) return data;
      if (data is Map && data["reviews"] is List) return data["reviews"];

      return [];
    }

    return [];
  }

  static Future<void> submitReview({
    required String productId,
    required int rating,
    required String body,
    required String reviewerName,
    required String reviewerEmail,
  }) async {
    final url = "${BackendConfig.baseUrl}/review";

    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "productId": productId,
        "rating": rating,
        "body": body,
        "reviewer": {
          "name": reviewerName,
          "email": reviewerEmail,
        }
      }),
    );

    if (response.statusCode == 200) return;

    if (response.statusCode == 404) {
      throw Exception(
        "Review API not found (404). If you use Railway, redeploy the latest "
        "mm-backend (it must register POST /api/review). For the Android emulator, "
        "set BACKEND_API_BASE_URL=http://10.0.2.2:5500 and run mm-backend with npm run dev.",
      );
    }

    String message = "Failed to submit review (${response.statusCode})";
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded["error"] != null) {
        message = decoded["error"].toString();
      }
    } catch (_) {}

    throw Exception(message);
  }

}
