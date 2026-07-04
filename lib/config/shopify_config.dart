import 'package:flutter_dotenv/flutter_dotenv.dart';

class ShopifyConfig {
  static String get storeDomain =>
      dotenv.env['PERMANENT_DOMAIN'] ?? "makeup-mystery-india.myshopify.com";

  static String get storefrontAccessToken =>
      dotenv.env['API_KEY'] ?? "6d1ee35c574a5b42ea8abafcb1e8f3e5";

  static const String customerAccessToken = "102df7f8b715b094ccc7b03465048d6a";
}
