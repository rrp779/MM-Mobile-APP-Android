import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/shopify_client.dart';

class AuthProvider extends ChangeNotifier {
  String? _accessToken;
  DateTime? _expiresAt;
  Map<String, dynamic>? _customer;

  bool get isLoggedIn =>
      _accessToken != null &&
          _expiresAt != null &&
          _expiresAt!.isAfter(DateTime.now());

  String? get accessToken => _accessToken;
  Map<String, dynamic>? get customer => _customer;

  /// 🔐 LOGIN
  Future<String?> login(String email, String password) async {
    final client = getShopifyClient();

    final result = await client.mutate(
      MutationOptions(
        document: gql(_loginMutation),
        variables: {
          "input": {
            "email": email,
            "password": password,
          }
        },
      ),
    );

    if (result.hasException) {
      return result.exception.toString();
    }

    final data = result.data?['customerAccessTokenCreate'];

    if (data == null || data['customerAccessToken'] == null) {
      return data?['customerUserErrors']?[0]?['message'] ??
          "Login failed";
    }

    _accessToken = data['customerAccessToken']['accessToken'];
    _expiresAt =
        DateTime.parse(data['customerAccessToken']['expiresAt']);

    await _saveSession();
    await fetchCustomer();

    notifyListeners();
    return null;
  }

  /// 🆕 REGISTER
  Future<String?> register(
      String firstName,
      String lastName,
      String email,
      String password,
      ) async {
    final client = getShopifyClient();

    final result = await client.mutate(
      MutationOptions(
        document: gql(_registerMutation),
        variables: {
          "input": {
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "password": password,
          }
        },
      ),
    );

    if (result.hasException) {
      return result.exception.toString();
    }

    final errors =
    result.data?['customerCreate']?['customerUserErrors'];

    if (errors != null && errors.isNotEmpty) {
      return errors[0]['message'];
    }

    // Auto login after register
    return await login(email, password);
  }

  /// 👤 FETCH CUSTOMER PROFILE
  Future<void> fetchCustomer() async {
    if (_accessToken == null) return;

    final client = getShopifyClient();

    final result = await client.query(
      QueryOptions(
        document: gql(_customerQuery),
        variables: {
          "accessToken": _accessToken,
        },
      ),
    );

    if (result.hasException) return;

    _customer = result.data?['customer'];
    notifyListeners();
  }

  /// 💾 SAVE SESSION
  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("accessToken", _accessToken!);
    await prefs.setString("expiresAt", _expiresAt!.toIso8601String());
  }

  /// 🔄 RESTORE SESSION
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString("accessToken");
    final expiry = prefs.getString("expiresAt");

    if (token != null && expiry != null) {
      _accessToken = token;
      _expiresAt = DateTime.parse(expiry);

      if (isLoggedIn) {
        await fetchCustomer();
      } else {
        logout();
      }
    }
  }

  /// 🚪 LOGOUT
  Future<void> logout() async {
    _accessToken = null;
    _expiresAt = null;
    _customer = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }
}

const String _loginMutation = r'''
mutation customerAccessTokenCreate($input: CustomerAccessTokenCreateInput!) {
  customerAccessTokenCreate(input: $input) {
    customerAccessToken {
      accessToken
      expiresAt
    }
    customerUserErrors {
      message
    }
  }
}
''';

const String _registerMutation = r'''
mutation customerCreate($input: CustomerCreateInput!) {
  customerCreate(input: $input) {
    customer {
      id
    }
    customerUserErrors {
      message
    }
  }
}
''';

const String _customerQuery = r'''
query getCustomer($accessToken: String!) {
  customer(customerAccessToken: $accessToken) {
    id
    firstName
    lastName
    email
    orders(first: 10) {
      edges {
        node {
          id
          orderNumber
          totalPrice {
            amount
          }
        }
      }
    }
  }
}
''';