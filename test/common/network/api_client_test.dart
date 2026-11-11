import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/common/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final uri = Uri.parse('https://api.example.com/v1/resource');

  group('ApiClient', () {
    test(
      'GIVEN a 2xx WHEN postJson THEN sends the encoded body and headers and '
      'returns the body',
      () async {
        late http.Request sent;
        final client = ApiClient(
          client: MockClient((request) async {
            sent = request;
            return http.Response('{"ok":true}', 200);
          }),
        );

        final body = await client.postJson(
          uri,
          body: {
            'model': 'm',
            'input': [1, 2],
          },
          headers: {'Authorization': 'Bearer k'},
        );

        expect(body, '{"ok":true}');
        expect(sent.method, 'POST');
        expect(sent.headers['Authorization'], 'Bearer k');
        expect(sent.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(sent.body), {
          'model': 'm',
          'input': [1, 2],
        });
      },
    );

    test(
      'WHEN postMultipart THEN the request carries the fields and the file '
      'under its file name',
      () async {
        late http.Request sent;
        final client = ApiClient(
          client: MockClient((request) async {
            sent = request;
            return http.Response('{"text":"hi"}', 200);
          }),
        );

        final body = await client.postMultipart(
          uri,
          fields: {'model': 'whisper-1'},
          fileField: 'file',
          fileName: 'ep.m4a',
          bytes: Uint8List.fromList([1, 2, 3]),
          headers: {'Authorization': 'Bearer k'},
        );

        expect(body, '{"text":"hi"}');
        expect(sent.method, 'POST');
        expect(sent.headers['Authorization'], 'Bearer k');
        expect(sent.headers['content-type'], startsWith('multipart/form-data'));
        final payload = latin1.decode(sent.bodyBytes);
        expect(payload, contains('name="model"\r\n\r\nwhisper-1'));
        expect(payload, contains('name="file"; filename="ep.m4a"'));
      },
    );

    test(
      'GIVEN a body under maxBytes WHEN getBytes THEN returns it',
      () async {
        final client = ApiClient(
          client: MockClient(
            (_) async => http.Response.bytes([1, 2, 3, 4], 200),
          ),
        );

        final bytes = await client.getBytes(uri, maxBytes: 10);

        expect(bytes, [1, 2, 3, 4]);
      },
    );

    test(
      'GIVEN a Content-Length over maxBytes WHEN getBytes THEN returns null',
      () async {
        final client = ApiClient(
          client: MockClient.streaming(
            (_, _) async => http.StreamedResponse(
              Stream.value([1, 2]),
              200,
              contentLength: 30 * 1024 * 1024,
            ),
          ),
        );

        final bytes = await client.getBytes(uri, maxBytes: 25 * 1024 * 1024);

        expect(bytes, isNull);
      },
    );

    test(
      'GIVEN no Content-Length and a body over maxBytes WHEN getBytes THEN '
      'returns null',
      () async {
        final client = ApiClient(
          client: MockClient.streaming(
            (_, _) async => http.StreamedResponse(
              Stream.fromIterable([
                [1, 2, 3],
                [4, 5, 6],
              ]),
              200,
            ),
          ),
        );

        final bytes = await client.getBytes(uri, maxBytes: 5);

        expect(bytes, isNull);
      },
    );

    group('every request', () {
      Map<String, Future<Object?> Function(ApiClient, Duration?)> calls() => {
        'getString': (c, _) => c.getString(uri),
        'postJson': (c, t) => c.postJson(uri, body: const {}, timeout: t),
        'postMultipart': (c, t) => c.postMultipart(
          uri,
          fields: const {},
          fileField: 'file',
          fileName: 'ep.mp3',
          bytes: Uint8List(0),
          timeout: t,
        ),
        'getBytes': (c, t) => c.getBytes(uri, maxBytes: 10, timeout: t),
      };

      for (final MapEntry(key: name, value: call) in calls().entries) {
        for (final status in [401, 429]) {
          test(
            'GIVEN a $status WHEN $name THEN throws ApiException with that '
            'statusCode',
            () async {
              final client = ApiClient(
                client: MockClient((_) async => http.Response('{}', status)),
              );

              await expectLater(
                call(client, null),
                throwsA(
                  isA<ApiException>().having(
                    (e) => e.statusCode,
                    'statusCode',
                    status,
                  ),
                ),
              );
            },
          );
        }
      }

      for (final MapEntry(key: name, value: call) in calls().entries) {
        if (name == 'getString') continue;
        test(
          'GIVEN a server slower than the timeout passed WHEN $name THEN '
          'throws NetworkException',
          () async {
            // A default far past the test's own timeout: only the one passed
            // to the call can end it.
            final client = ApiClient(
              client: MockClient((_) => Completer<http.Response>().future),
              timeout: const Duration(hours: 1),
            );

            await expectLater(
              call(client, const Duration(milliseconds: 10)),
              throwsA(isA<NetworkException>()),
            );
          },
        );
      }
    });
  });
}
