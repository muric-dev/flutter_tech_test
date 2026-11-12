import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/player/ai_companion/cubit/ai_companion_cubit.dart';
import 'package:cabina/player/ai_companion/data/ai_companion_repository.dart';
import 'package:cabina/player/ai_companion/models/chapter.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:cabina/show_detail/models/episode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAICompanionRepository extends Mock
    implements AICompanionRepository {}

const _episode = Episode(
  guid: 'night-shift-42',
  title: 'The last lighthouse keepers',
  audioUrl: 'https://cdn.example.com/night-shift/ep.m4a',
);

const _args = PlayerArgs(
  episode: _episode,
  podcastTitle: 'Night Shift',
  feedUrl: 'https://feeds.example.com/night-shift.xml',
);

const _segments = [
  TranscriptSegment(start: Duration(seconds: 4), text: 'Welcome back.'),
  TranscriptSegment(start: Duration(seconds: 8), text: 'Lighthouses.'),
];

const _transcript = Transcript(
  source: TranscriptSource.audio,
  segments: _segments,
  duration: Duration(seconds: 56),
);

const _companion = EpisodeCompanion(
  source: TranscriptSource.audio,
  segments: _segments,
  transcribedDuration: Duration(seconds: 56),
  summary: 'Two keepers remember the last manned lighthouse.',
  chapters: [Chapter(title: 'Welcome', segmentIndex: 0)],
);

const _loading = AICompanionState(status: AICompanionStatus.loading);
const _ready = AICompanionState(
  status: AICompanionStatus.ready,
  companion: _companion,
);

void main() {
  late _MockAICompanionRepository repository;

  setUp(() {
    repository = _MockAICompanionRepository();
    when(() => repository.loadCached(_args)).thenAnswer((_) async => null);
    when(
      () => repository.transcript(_episode),
    ).thenAnswer((_) async => _transcript);
    when(
      () => repository.debrief(_transcript),
    ).thenAnswer((_) async => _companion);
    when(() => repository.save(_args, _companion)).thenAnswer((_) async {});
  });

  AICompanionCubit buildCubit() =>
      AICompanionCubit(repository: repository, args: _args);

  group('AICompanionCubit', () {
    group('start', () {
      blocTest<AICompanionCubit, AICompanionState>(
        'GIVEN a cached episode '
        'WHEN start '
        'THEN emits loading, ready, and prepares or saves nothing',
        setUp: () => when(
          () => repository.loadCached(_args),
        ).thenAnswer((_) async => _companion),
        build: buildCubit,
        act: (cubit) => cubit.start(),
        expect: () => const [_loading, _ready],
        verify: (_) {
          verifyNever(() => repository.transcript(_episode));
          verifyNever(() => repository.save(_args, _companion));
        },
      );

      blocTest<AICompanionCubit, AICompanionState>(
        'GIVEN no cache '
        'WHEN start '
        'THEN emits loading, ready, then saves once',
        build: buildCubit,
        act: (cubit) => cubit.start(),
        expect: () => const [_loading, _ready],
        verify: (_) =>
            verify(() => repository.save(_args, _companion)).called(1),
      );

      blocTest<AICompanionCubit, AICompanionState>(
        'GIVEN start running '
        'WHEN start again (double tap, sheet reopened) '
        'THEN the repository runs once',
        build: buildCubit,
        act: (cubit) => Future.wait([cubit.start(), cubit.start()]),
        expect: () => const [_loading, _ready],
        verify: (_) {
          verify(() => repository.loadCached(_args)).called(1);
          verify(() => repository.transcript(_episode)).called(1);
        },
      );

      test('GIVEN the cubit closes during the transcript stage '
          'WHEN the transcript arrives '
          'THEN debrief and save are never called', () async {
        final transcript = Completer<Transcript>();
        when(
          () => repository.transcript(_episode),
        ).thenAnswer((_) => transcript.future);
        final cubit = buildCubit();

        final preparing = cubit.start();
        await pumpEventQueue();
        await cubit.close();
        transcript.complete(_transcript);
        await preparing;

        verifyNever(() => repository.debrief(_transcript));
        verifyNever(() => repository.save(_args, _companion));
      });

      test('GIVEN the cubit closes during the cache lookup '
          'WHEN no cache is found '
          'THEN the transcript is never requested', () async {
        final cached = Completer<EpisodeCompanion?>();
        when(
          () => repository.loadCached(_args),
        ).thenAnswer((_) => cached.future);
        final cubit = buildCubit();

        final preparing = cubit.start();
        await pumpEventQueue();
        await cubit.close();
        cached.complete();
        await preparing;

        verifyNever(() => repository.transcript(_episode));
      });

      blocTest<AICompanionCubit, AICompanionState>(
        'GIVEN the cubit closes during the debrief '
        'WHEN the debrief fails '
        'THEN the failure is dropped: no error state, nothing reported',
        build: buildCubit,
        act: (cubit) async {
          // Created inside `act`: a future's error doesn't cross into
          // blocTest's guarded zone, it would escape as uncaught.
          final debrief = Completer<EpisodeCompanion>();
          when(
            () => repository.debrief(_transcript),
          ).thenAnswer((_) => debrief.future);
          final preparing = cubit.start();
          await pumpEventQueue();
          await cubit.close();
          debrief.completeError(
            const AICompanionException("Couldn't prepare AI Companion"),
          );
          await preparing;
        },
        expect: () => const [_loading],
        errors: () => const <Object>[],
      );

      blocTest<AICompanionCubit, AICompanionState>(
        'GIVEN the save fails '
        'WHEN start '
        'THEN the state stays ready and the error is reported',
        setUp: () => when(
          () => repository.save(_args, _companion),
        ).thenThrow(const StorageException('Could not save your changes')),
        build: buildCubit,
        act: (cubit) => cubit.start(),
        expect: () => const [_loading, _ready],
        errors: () => [isA<StorageException>()],
      );
    });

    group('retry', () {
      blocTest<AICompanionCubit, AICompanionState>(
        'GIVEN start failed with a retryable error '
        'WHEN retry '
        'THEN emits loading without the error, then ready',
        setUp: () {
          var calls = 0;
          when(() => repository.transcript(_episode)).thenAnswer((_) async {
            if (calls++ == 0) {
              throw const AICompanionException(
                'No connection. Check your internet and try again',
                canRetry: true,
              );
            }
            return _transcript;
          });
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await cubit.retry();
        },
        expect: () => const [
          _loading,
          AICompanionState(
            status: AICompanionStatus.error,
            errorMessage: 'No connection. Check your internet and try again',
            canRetry: true,
          ),
          _loading,
          _ready,
        ],
        errors: () => [isA<AICompanionException>()],
      );
    });
  });
}
