import 'dart:typed_data';

import 'package:cabina/common/network/api_client.dart';
import 'package:cabina/player/ai_companion/data/prompts/debrief_prompt.dart';
import 'package:cabina/player/ai_companion/data/services/open_ai_service.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient apiClient;
  late OpenAIService service;

  const auth = {'Authorization': 'Bearer sk-test'};

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    apiClient = _MockApiClient();
    service = OpenAIService(apiClient: apiClient, apiKey: 'sk-test');
  });

  group('OpenAIService', () {
    test('WHEN transcribe '
        'THEN posts the file as multipart to Whisper with the bearer key, '
        'verbose_json and the 5 min timeout', () async {
      final bytes = Uint8List.fromList([0x49, 0x44, 0x33]);
      when(
        () => apiClient.postMultipart(
          any(),
          fields: any(named: 'fields'),
          fileField: any(named: 'fileField'),
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          headers: any(named: 'headers'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => '{}');

      expect(await service.transcribe(bytes, 'ep42.m4a'), '{}');
      verify(
        () => apiClient.postMultipart(
          Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
          fields: {'model': 'whisper-1', 'response_format': 'verbose_json'},
          fileField: 'file',
          fileName: 'ep42.m4a',
          bytes: bytes,
          headers: auth,
          timeout: const Duration(minutes: 5),
        ),
      ).called(1);
    });

    test('WHEN debrief '
        'THEN posts the documented Responses API body (model, low effort, '
        'strict schema, only the spoken segments as {id, text}) with the '
        'bearer key and the 2 min timeout', () async {
      when(
        () => apiClient.postJson(
          any(),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => '{}');

      expect(
        await service.debrief(const [
          TranscriptSegment(start: Duration(seconds: 4), text: 'Welcome.'),
          TranscriptSegment(
            start: Duration(seconds: 8),
            text: '♪',
            isMusic: true,
          ),
          TranscriptSegment(start: Duration(seconds: 40), text: 'We are back.'),
        ]),
        '{}',
      );

      final captured = verify(
        () => apiClient.postJson(
          Uri.parse('https://api.openai.com/v1/responses'),
          body: captureAny(named: 'body'),
          headers: auth,
          timeout: const Duration(minutes: 2),
        ),
      ).captured;
      expect(captured.single, {
        'model': 'gpt-5.6-luna',
        'reasoning': {'effort': 'low'},
        'instructions': DebriefPrompt.instructions,
        'input': '[{"id":0,"text":"Welcome."},{"id":2,"text":"We are back."}]',
        'text': {
          'format': {
            'type': 'json_schema',
            'name': 'debrief',
            'strict': true,
            'schema': {
              'type': 'object',
              'additionalProperties': false,
              'required': ['summary', 'chapters'],
              'properties': {
                'summary': {'type': 'string'},
                'chapters': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'additionalProperties': false,
                    'required': ['title', 'segmentId'],
                    'properties': {
                      'title': {'type': 'string'},
                      'segmentId': {'type': 'integer'},
                    },
                  },
                },
              },
            },
          },
        },
      });
    });
  });
}
