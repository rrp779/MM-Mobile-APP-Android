import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';

/// Resilient API Client that automatically switches between:
/// 1. https://mmapp.makeupmystery.in/api
/// 2. https://mm-backend-production-d3a3.up.railway.app/api
/// 3. Direct edge IP https://69.46.46.91/api (with SNI)
class ApiClient {
  static const String fallbackIp = "69.46.46.91";
  static const String railwayHost = "mm-backend-production-d3a3.up.railway.app";
  static const String customHost = "mmapp.makeupmystery.in";

  static final List<String> domains = [
    "https://mmapp.makeupmystery.in/api",
    "https://mm-backend-production-d3a3.up.railway.app/api",
  ];

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return _executeWithFailover(
      method: "POST",
      originalUri: uri,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  }

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return _executeWithFailover(
      method: "GET",
      originalUri: uri,
      headers: headers,
      timeout: timeout,
    );
  }

  static Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return _executeWithFailover(
      method: "DELETE",
      originalUri: uri,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  }

  static Future<http.Response> _executeWithFailover({
    required String method,
    required Uri originalUri,
    Map<String, String>? headers,
    Object? body,
    required Duration timeout,
  }) async {
    final effectiveHeaders = <String, String>{...?headers};

    // Prepare candidate URIs:
    // 1. originalUri
    // 2. alternate domain with same path & query
    final candidates = <Uri>[];
    candidates.add(originalUri);

    for (final domainBase in domains) {
      final baseUri = Uri.parse(domainBase);
      if (baseUri.host != originalUri.host) {
        final altUri = Uri(
          scheme: baseUri.scheme,
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : null,
          path: originalUri.path,
          query: originalUri.query.isNotEmpty ? originalUri.query : null,
        );
        candidates.add(altUri);
      }
    }

    dynamic lastError;

    for (final candidate in candidates) {
      try {
        late http.Response response;
        if (method == "POST") {
          response = await http.post(candidate, headers: effectiveHeaders, body: body).timeout(timeout);
        } else if (method == "DELETE") {
          response = await http.delete(candidate, headers: effectiveHeaders, body: body).timeout(timeout);
        } else {
          response = await http.get(candidate, headers: effectiveHeaders).timeout(timeout);
        }

        // If server responded, remember this domain
        if (response.statusCode < 500) {
          if (candidate.host != originalUri.host) {
            BackendConfig.setActiveDomain(candidate.host);
          }
          return response;
        } else if (response.statusCode == 500) {
          return response;
        }
      } catch (e) {
        lastError = e;
        debugPrint("[ApiClient] Host ${candidate.host} failed: $e. Trying next domain...");
      }
    }

    // Direct edge IP fallback (bypasses carrier DNS failure completely)
    debugPrint("[ApiClient] Both domains failed ($lastError). Attempting direct IP fallback...");
    try {
      return await _directIpRequest(
        method: method,
        path: originalUri.path,
        query: originalUri.query,
        headers: effectiveHeaders,
        body: body,
        timeout: timeout,
      );
    } catch (e) {
      debugPrint("[ApiClient] Direct IP fallback failed: $e");
      if (lastError != null) throw lastError;
      rethrow;
    }
  }

  static Future<http.Response> _directIpRequest({
    required String method,
    required String path,
    String? query,
    required Map<String, String> headers,
    Object? body,
    required Duration timeout,
  }) async {
    final fallbackUri = Uri(
      scheme: "https",
      host: fallbackIp,
      port: 443,
      path: path,
      query: query != null && query.isNotEmpty ? query : null,
    );

    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;

    late HttpClientRequest request;
    if (method == "POST") {
      request = await client.postUrl(fallbackUri).timeout(timeout);
    } else if (method == "DELETE") {
      request = await client.deleteUrl(fallbackUri).timeout(timeout);
    } else {
      request = await client.getUrl(fallbackUri).timeout(timeout);
    }

    headers['Host'] = railwayHost;
    headers.forEach((k, v) => request.headers.set(k, v));

    if (body is String) {
      request.write(body);
    } else if (body is List<int>) {
      request.add(body);
    }

    final ioResponse = await request.close().timeout(timeout);
    final respBody = await ioResponse.transform(utf8.decoder).join();
    final respHeaders = <String, String>{};
    ioResponse.headers.forEach((name, values) {
      respHeaders[name] = values.join(', ');
    });

    return http.Response(respBody, ioResponse.statusCode, headers: respHeaders);
  }
}
