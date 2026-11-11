import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/player/ai_companion/data/ai_companion_repository.dart';
import 'package:cabina/player/ai_companion/data/services/ai_companion_cache_service.dart';
import 'package:cabina/player/ai_companion/data/services/episode_download_service.dart';
import 'package:cabina/player/ai_companion/data/services/open_ai_service.dart';
import 'package:cabina/player/ai_companion/models/chapter.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:cabina/show_detail/models/episode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockAICompanionCacheService extends Mock
    implements AICompanionCacheService {}

class _MockEpisodeDownloadService extends Mock
    implements EpisodeDownloadService {}

class _MockOpenAIService extends Mock implements OpenAIService {}

const _episode = Episode(
  guid: 'night-shift-42',
  title: 'The last lighthouse keepers',
  audioUrl: 'https://cdn.example.com/night-shift/ep.m4a?updated=123',
);

const _args = PlayerArgs(
  episode: _episode,
  podcastTitle: 'Night Shift',
  feedUrl: 'https://feeds.example.com/night-shift.xml',
);

const _srt = '''
1
00:00:04,000 --> 00:00:08,000
Welcome back to Night Shift.

2
00:00:08,000 --> 00:00:56,000
Today we talk about lighthouses.
''';

/// A Whisper `verbose_json` body with two clear sentences.
final String _whisper = jsonEncode({
  'task': 'transcribe',
  'language': 'english',
  'duration': 56.0,
  'text': ' Welcome back. Lighthouses.',
  'segments': [
    for (final (id, start, end, text) in [
      (0, 4.0, 8.0, ' Welcome back.'),
      (1, 8.0, 56.0, ' Lighthouses.'),
    ])
      {
        'id': id,
        'seek': 0,
        'start': start,
        'end': end,
        'text': text,
        'tokens': [50364, 2421],
        'temperature': 0.0,
        'avg_logprob': -0.21,
        'compression_ratio': 1.32,
        'no_speech_prob': 0.02,
      },
  ],
});

/// A Whisper body where every segment is silence.
final String _silentWhisper = jsonEncode({
  'task': 'transcribe',
  'language': 'english',
  'duration': 30.0,
  'text': ' ',
  'segments': [
    {
      'id': 0,
      'seek': 0,
      'start': 0.0,
      'end': 30.0,
      'text': ' ',
      'tokens': [50364],
      'temperature': 0.0,
      'avg_logprob': -1.4,
      'compression_ratio': 0.6,
      'no_speech_prob': 0.95,
    },
  ],
});

const _transcript = Transcript(
  source: TranscriptSource.audio,
  segments: [
    TranscriptSegment(start: Duration(seconds: 4), text: 'Welcome back.'),
    TranscriptSegment(start: Duration(seconds: 8), text: 'Lighthouses.'),
  ],
  duration: Duration(seconds: 56),
);

/// A Responses API body whose answer is the debrief JSON.
final String _responses = jsonEncode({
  'id': 'resp_68f1a2',
  'object': 'response',
  'status': 'completed',
  'model': 'gpt-5.6-luna',
  'output': [
    {'id': 'rs_68f1a2', 'type': 'reasoning', 'summary': <Object>[]},
    {
      'id': 'msg_68f1a2',
      'type': 'message',
      'status': 'completed',
      'role': 'assistant',
      'content': [
        {
          'type': 'output_text',
          'annotations': <Object>[],
          'text': jsonEncode({
            'summary': 'A night with the last lighthouse keepers.',
            'chapters': [
              {'title': 'Welcome', 'segmentId': 0},
              {'title': 'Lighthouses', 'segmentId': 1},
            ],
          }),
        },
      ],
    },
  ],
});

const _companion = EpisodeCompanion(
  source: TranscriptSource.audio,
  segments: [
    TranscriptSegment(start: Duration(seconds: 4), text: 'Welcome back.'),
    TranscriptSegment(start: Duration(seconds: 8), text: 'Lighthouses.'),
  ],
  transcribedDuration: Duration(seconds: 56),
  summary: 'A night with the last lighthouse keepers.',
  chapters: [
    Chapter(title: 'Welcome', segmentIndex: 0),
    Chapter(title: 'Lighthouses', segmentIndex: 1),
  ],
);

Matcher _throwsCompanion(String message, {required bool canRetry}) => throwsA(
  isA<AICompanionException>()
      .having((e) => e.message, 'message', message)
      .having((e) => e.canRetry, 'canRetry', canRetry),
);

void main() {
  late _MockAICompanionCacheService cache;
  late _MockEpisodeDownloadService downloads;
  late _MockOpenAIService openAI;
  late AICompanionRepository repository;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(<TranscriptSegment>[]);
  });

  setUp(() {
    cache = _MockAICompanionCacheService();
    downloads = _MockEpisodeDownloadService();
    openAI = _MockOpenAIService();
    repository = AICompanionRepository(
      cacheService: cache,
      downloadService: downloads,
      openAIService: openAI,
    );
    when(() => openAI.isConfigured).thenReturn(true);
  });

  void stubAudio(Uint8List? bytes) =>
      when(() => downloads.fetchAudio(any())).thenAnswer((_) async => bytes);

  group('AICompanionRepository.loadCached', () {
    test(
      'GIVEN a cached episode '
      'THEN returns it by feed URL and guid, and no remote is called',
      () async {
        when(
          () => cache.read(
            feedUrl: any(named: 'feedUrl'),
            guid: any(named: 'guid'),
          ),
        ).thenAnswer((_) async => _companion);

        expect(await repository.loadCached(_args), _companion);
        verify(
          () => cache.read(feedUrl: _args.feedUrl, guid: _episode.guid),
        ).called(1);
        verifyZeroInteractions(downloads);
        verifyZeroInteractions(openAI);
      },
    );
  });

  group('AICompanionRepository.transcript', () {
    test(
      'GIVEN an episode with a transcript URL '
      'THEN returns the RSS transcript and never downloads the audio',
      () async {
        const episode = Episode(
          guid: 'night-shift-42',
          title: 'The last lighthouse keepers',
          audioUrl: 'https://cdn.example.com/night-shift/ep.m4a',
          transcriptUrl: 'https://cdn.example.com/night-shift/ep.srt',
        );
        when(
          () => downloads.fetchTranscript(any()),
        ).thenAnswer((_) async => _srt);

        final transcript = await repository.transcript(episode);

        expect(transcript.source, TranscriptSource.rss);
        expect(transcript.segments, hasLength(2));
        verify(
          () => downloads.fetchTranscript(
            'https://cdn.example.com/night-shift/ep.srt',
          ),
        ).called(1);
        verifyNever(() => downloads.fetchAudio(any()));
        verifyNever(() => openAI.transcribe(any(), any()));
      },
    );

    test(
      'GIVEN no transcript URL and an enclosure under the cap '
      'THEN uploads it once as ep.m4a and returns the audio transcript',
      () async {
        final bytes = Uint8List.fromList([0x49, 0x44, 0x33]);
        stubAudio(bytes);
        when(
          () => openAI.transcribe(any(), any()),
        ).thenAnswer((_) async => _whisper);

        expect(await repository.transcript(_episode), _transcript);
        verify(() => openAI.transcribe(bytes, 'ep.m4a')).called(1);
      },
    );

    test('GIVEN audio over the cap '
        'THEN throws "too long" and uploads nothing', () async {
      stubAudio(null);

      await expectLater(
        repository.transcript(_episode),
        _throwsCompanion(
          'This episode is too long for AI Companion',
          canRetry: false,
        ),
      );
      verifyNever(() => openAI.transcribe(any(), any()));
    });

    test('GIVEN no key '
        'THEN throws "not available" and makes no request', () async {
      when(() => openAI.isConfigured).thenReturn(false);

      await expectLater(
        repository.transcript(_episode),
        _throwsCompanion(
          "AI Companion isn't available right now",
          canRetry: false,
        ),
      );
      verifyZeroInteractions(downloads);
      verifyNever(() => openAI.transcribe(any(), any()));
    });

    test('GIVEN no spoken segment '
        'THEN throws "not enough spoken audio"', () async {
      stubAudio(Uint8List(1));
      when(
        () => openAI.transcribe(any(), any()),
      ).thenAnswer((_) async => _silentWhisper);

      await expectLater(
        repository.transcript(_episode),
        _throwsCompanion(
          'Not enough spoken audio in this episode',
          canRetry: false,
        ),
      );
    });

    final failures = <String, (Object, String, bool)>{
      '401': (
        const ApiException('failed', statusCode: 401),
        "AI Companion isn't available right now",
        false,
      ),
      '403': (
        const ApiException('failed', statusCode: 403),
        "AI Companion isn't available right now",
        false,
      ),
      '429': (
        const ApiException('failed', statusCode: 429),
        'AI Companion is busy. Try again later',
        false,
      ),
      'NetworkException': (
        NetworkException('offline', cause: http.ClientException('no route')),
        'No connection. Check your internet and try again',
        true,
      ),
      'timeout': (
        NetworkException('timed out', cause: TimeoutException('5 min')),
        "Couldn't prepare AI Companion",
        true,
      ),
    };
    for (final MapEntry(key: name, value: (failure, message, canRetry))
        in failures.entries) {
      test(
        'GIVEN a $name '
        'THEN throws "$message" with canRetry $canRetry and the cause',
        () async {
          stubAudio(Uint8List(1));
          when(() => openAI.transcribe(any(), any())).thenThrow(failure);

          await expectLater(
            repository.transcript(_episode),
            throwsA(
              isA<AICompanionException>()
                  .having((e) => e.message, 'message', message)
                  .having((e) => e.canRetry, 'canRetry', canRetry)
                  .having((e) => e.cause, 'cause', same(failure)),
            ),
          );
        },
      );
    }
  });

  group('AICompanionRepository.debrief', () {
    test('GIVEN a transcript '
        'THEN returns the companion with its summary and chapters', () async {
      when(() => openAI.debrief(any())).thenAnswer((_) async => _responses);

      expect(await repository.debrief(_transcript), _companion);
      verify(() => openAI.debrief(_transcript.segments)).called(1);
    });
  });
}
