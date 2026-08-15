import 'package:flutter_dotenv/flutter_dotenv.dart';

class ShopifyConfig {
  static String get storeDomain =>
      dotenv.env['PERMANENT_DOMAIN'] ?? "makeup-mystery-india.myshopify.com";

  static String get storefrontAccessToken =>
      dotenv.env['API_KEY'] ?? "96a8a304c6865dbb9cd20edac41e275d";

  static const String customerAccessToken = "102df7f8b715b094ccc7b03465048d6a";
}
