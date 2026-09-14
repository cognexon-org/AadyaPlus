import 'dart:convert';

import 'package:http/http.dart' as native_http;
import 'package:aadya_plus/services/secure_storage_service.dart';
import 'package:aadya_plus/utils/constants.dart';

/// Authenticated HTTP facade used throughout the patient app.
///
/// It deliberately mirrors the common top-level methods from package:http so
/// older providers/screens can move to the centralized client without a large
/// rewrite. JWT attachment is handled here instead of in each screen.
final native_http.Client _client = native_http.Client();

typedef UnauthorizedHandler = Future<void> Function();
UnauthorizedHandler? _unauthorizedHandler;

void setUnauthorizedHandler(UnauthorizedHandler? handler) {
  _unauthorizedHandler = handler;
}

bool _isBackendRequest(Uri url) {
  final apiBase = Uri.parse(AppConstants.baseUrl);
  return url.scheme == apiBase.scheme &&
      url.host == apiBase.host &&
      url.port == apiBase.port;
}

Future<Map<String, String>> _buildHeaders(
  Uri url,
  Map<String, String>? headers,
) async {
  final merged = <String, String>{
    'Accept': 'application/json',
    ...?headers,
  };

  if (_isBackendRequest(url)) {
    final token = await SecureStorageService.instance.readToken();
    if (token != null && token.isNotEmpty) {
      // Never trust a stale/hand-built Authorization value from a caller.
      merged['Authorization'] = 'Bearer $token';
    } else {
      merged.remove('Authorization');
    }
  } else {
    // Never leak the Aadya JWT to third-party URLs (e.g. reverse geocoding).
    merged.remove('Authorization');
  }

  return merged;
}

Future<native_http.Response> _finish(
  Uri url,
  Future<native_http.Response> request,
) async {
  final response = await request;
  if (_isBackendRequest(url) && response.statusCode == 401) {
    final handler = _unauthorizedHandler;
    if (handler != null) await handler();
  }
  return response;
}

Future<native_http.Response> get(
  Uri url, {
  Map<String, String>? headers,
}) async {
  return _finish(
    url,
    _client.get(url, headers: await _buildHeaders(url, headers)),
  );
}

Future<native_http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  return _finish(
    url,
    _client.post(
      url,
      headers: await _buildHeaders(url, headers),
      body: body,
      encoding: encoding,
    ),
  );
}

Future<native_http.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  return _finish(
    url,
    _client.put(
      url,
      headers: await _buildHeaders(url, headers),
      body: body,
      encoding: encoding,
    ),
  );
}

Future<native_http.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  return _finish(
    url,
    _client.patch(
      url,
      headers: await _buildHeaders(url, headers),
      body: body,
      encoding: encoding,
    ),
  );
}

Future<native_http.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  return _finish(
    url,
    _client.delete(
      url,
      headers: await _buildHeaders(url, headers),
      body: body,
      encoding: encoding,
    ),
  );
}

/// Resolve a relative API path against the compile-time configured API base.
Uri apiUri(String path, {Map<String, dynamic>? queryParameters}) {
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  final uri = Uri.parse('${AppConstants.baseUrl}$normalizedPath');

  if (queryParameters == null || queryParameters.isEmpty) return uri;

  return uri.replace(
    queryParameters: queryParameters.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    ),
  );
}
