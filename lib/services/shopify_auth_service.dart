import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'pkce_service.dart';

class ShopifyAuthService {

  static const String clientId = "YOUR_CLIENT_ID";

  static const String redirectUri =
      "shop.makeupmystery.mobile://callback";

  static const String authorizationEndpoint =
      "https://account.makeupmysteryindia.in/oauth/authorize";

  static const String tokenEndpoint =
      "https://account.makeupmysteryindia.in/oauth/token";

  static final storage = FlutterSecureStorage();

  static Future<void> login() async {

    final verifier = PKCE.generateCodeVerifier();
    final challenge = PKCE.generateCodeChallenge(verifier);

    await storage.write(key: "pkce_verifier", value: verifier);

    final url = Uri.parse(
        "$authorizationEndpoint"
            "?client_id=$clientId"
            "&scope=openid%20email%20customer-account-api%3Afull"
            "&redirect_uri=$redirectUri"
            "&response_type=code"
            "&code_challenge=$challenge"
            "&code_challenge_method=S256"
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  static Future<void> exchangeCode(String code) async {

    final verifier = await storage.read(key: "pkce_verifier");

    final response = await http.post(
      Uri.parse(tokenEndpoint),
      body: {
        "grant_type": "authorization_code",
        "client_id": clientId,
        "code": code,
        "redirect_uri": redirectUri,
        "code_verifier": verifier
      },
    );

    final data = jsonDecode(response.body);

    await storage.write(
      key: "access_token",
      value: data["access_token"],
    );
  }
}