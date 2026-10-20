import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'errors.dart';

/// Client REST cho MockAPI. Mọi lỗi mạng/HTTP đều quy về [ApiException].
class ApiClient {
  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 12);
  static const Map<String, String> _json = {'Content-Type': 'application/json'};

  Uri _uri(String resource, [String? id]) =>
      Uri.parse('$kApiBaseUrl/$resource${id == null ? '' : '/$id'}');

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('Timeout');
    } on SocketException catch (e) {
      throw ApiException('No connection: ${e.message}');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  void _ensureOk(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ApiException('HTTP ${r.statusCode}', r.statusCode);
    }
  }

  Future<List<Map<String, dynamic>>> list(String resource) async {
    final r = await _send(() => _client.get(_uri(resource)));
    _ensureOk(r);
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (body is! List) throw const ApiException('Invalid response');
    return body.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> create(
      String resource, Map<String, Object?> data) async {
    final r = await _send(
        () => _client.post(_uri(resource), headers: _json, body: jsonEncode(data)));
    _ensureOk(r);
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (body is! Map<String, dynamic> || body['id'] == null) {
      throw const ApiException('Invalid response');
    }
    return body;
  }

  Future<void> update(
      String resource, String id, Map<String, Object?> data) async {
    final r = await _send(() =>
        _client.put(_uri(resource, id), headers: _json, body: jsonEncode(data)));
    _ensureOk(r);
  }

  /// 404 được xem là đã xóa rồi -> thành công.
  Future<void> delete(String resource, String id) async {
    final r = await _send(() => _client.delete(_uri(resource, id)));
    if (r.statusCode == 404) return;
    _ensureOk(r);
  }
}
