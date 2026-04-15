import 'dart:convert';
import 'package:http/http.dart' as http;

class ReviewService {

  static const String shopDomain = "makeup-mystery-india.myshopify.com";
  static const String apiToken = "zdFpBFwjumc10sCGRWqY-CyonNA";

  static Future<List> fetchProductReviews(String productId) async {

    final url =
        "https://judge.me/api/v1/reviews?shop=$shopDomain&api_token=$apiToken&product_id=$productId";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["reviews"] ?? [];
    }

    return [];
  }

}