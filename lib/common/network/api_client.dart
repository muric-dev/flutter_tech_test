import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:http/http.dart' as http;

/// Thin wrapper over [http.Client] that applies a timeout and maps transport
/// and status failures onto the [CabinaException] hierarchy.
class ApiClient {
  ApiClient({http.Client? client, this.timeout = const Duration(seconds: 20)})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Used by every call that doesn't pass its own `timeout`.
  final Duration timeout;

  Future<String> getString(Uri uri, {Map<String, String>? headers}) =>
      _guard(uri, null, () async {
        final response = await _client.get(uri, headers: headers);
        return _bodyOf(uri, response);
      });

  /// Sends [body] encoded as JSON and returns the response body.
  Future<String> postJson(
    Uri uri, {
    required Object body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _guard(uri, timeout, () async {
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body),
    );
    return _bodyOf(uri, response);
  });

  /// Sends a `multipart/form-data` request with [fields] and one file, and
  /// returns the response body.
  Future<String> postMultipart(
    Uri uri, {
    required Map<String, String> fields,
    required String fileField,
    required String fileName,
    required Uint8List bytes,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _guard(uri, timeout, () async {
    final request = http.MultipartRequest('POST', uri)
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(fileField, bytes, filename: fileName),
      );
    if (headers != null) request.headers.addAll(headers);
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return _bodyOf(uri, response);
  });

  /// `null` when the body is larger than [maxBytes]; nothing past the limit is
  /// kept. The `Content-Length` is checked first, and the bytes read too,
  /// because some servers omit it. A timeout doesn't stop the download: it
  /// runs on until the end or the cap, and its bytes are dropped.
  Future<Uint8List?> getBytes(
    Uri uri, {
    required int maxBytes,
    Duration? timeout,
  }) => _guard(uri, timeout, () async {
    final response = await _client.send(http.Request('GET', uri));
    if (!_isSuccess(response.statusCode)) {
      await response.stream.drain<void>();
      throw _statusError(uri, response.statusCode);
    }
    final length = response.contentLength;
    if (length != null && length > maxBytes) {
      await response.stream.listen(null).cancel();
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (builder.length + chunk.length > maxBytes) return null;
      builder.add(chunk);
    }
    return builder.takeBytes();
  });

  /// Applies the timeout ([timeout] or the client's default) and maps
  /// transport failures to [NetworkException].
  Future<T> _guard<T>(
    Uri uri,
    Duration? timeout,
    Future<T> Function() request,
  ) async {
    try {
      return await request().timeout(timeout ?? this.timeout);
    } on TimeoutException catch (e) {
      throw NetworkException('Request to ${uri.host} timed out', cause: e);
    } on http.ClientException catch (e) {
      throw NetworkException('Could not reach ${uri.host}', cause: e);
    }
  }

  String _bodyOf(Uri uri, http.Response response) {
    if (_isSuccess(response.statusCode)) return response.body;
    throw _statusError(uri, response.statusCode);
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  ApiException _statusError(Uri uri, int statusCode) =>
      ApiException('Request to ${uri.host} failed', statusCode: statusCode);

  void dispose() => _client.close();
}
