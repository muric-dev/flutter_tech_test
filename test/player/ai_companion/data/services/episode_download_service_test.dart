import 'dart:typed_data';

import 'package:cabina/common/network/api_client.dart';
import 'package:cabina/player/ai_companion/data/services/episode_download_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient apiClient;
  late EpisodeDownloadService service;

  const audioUrl = 'https://cdn.example.com/night-shift/ep42.mp3';

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    apiClient = _MockApiClient();
    service = EpisodeDownloadService(apiClient: apiClient);
  });

  group('EpisodeDownloadService.fetchAudio', () {
    test('WHEN the audio is fetched '
        'THEN it downloads with the 25 MB cap and the audio timeout', () async {
      final bytes = Uint8List.fromList([0x49, 0x44, 0x33]);
      when(
        () => apiClient.getBytes(
          any(),
          maxBytes: any(named: 'maxBytes'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => bytes);

      expect(await service.fetchAudio(audioUrl), same(bytes));
      verify(
        () => apiClient.getBytes(
          Uri.parse(audioUrl),
          maxBytes: 25 * 1024 * 1024,
          timeout: EpisodeDownloadService.audioDownloadTimeout,
        ),
      ).called(1);
    });
  });
}
