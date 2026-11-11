import 'dart:convert';

import 'package:cabina/player/ai_companion/models/chapter.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:flutter_test/flutter_test.dart';

EpisodeCompanion _companion({
  TranscriptSource source = TranscriptSource.audio,
  Duration transcribedDuration = const Duration(minutes: 26),
}) => EpisodeCompanion(
  source: source,
  segments: const [
    TranscriptSegment(start: Duration(seconds: 4), text: 'Welcome back.'),
    TranscriptSegment(
      start: Duration(seconds: 9),
      text: 'Today we talk about lighthouses.',
    ),
    TranscriptSegment(start: Duration(seconds: 15), text: '♪', isMusic: true),
    TranscriptSegment(start: Duration(seconds: 47), text: 'We are back.'),
  ],
  transcribedDuration: transcribedDuration,
  summary: 'A short history of lighthouses.',
  chapters: const [
    Chapter(title: 'Intro', segmentIndex: 0),
    Chapter(title: 'After the break', segmentIndex: 3),
  ],
);

void main() {
  group('EpisodeCompanion', () {
    group('indexAt', () {
      test(
        'GIVEN positions before the first sentence, inside one and inside a '
        'music section THEN returns the first, that sentence and the music',
        () {
          final companion = _companion();

          expect(companion.indexAt(Duration.zero), 0);
          expect(companion.indexAt(const Duration(seconds: 12)), 1);
          expect(companion.indexAt(const Duration(seconds: 30)), 2);
        },
      );
    });

    group('isSyncApproximate', () {
      const total = Duration(minutes: 26);

      test(
        'GIVEN an audio source 5s off the total THEN is approximate, '
        'GIVEN 2s off THEN is not',
        () {
          expect(
            _companion(
              transcribedDuration: total - const Duration(seconds: 5),
            ).isSyncApproximate(total),
            isTrue,
          );
          expect(
            _companion(
              transcribedDuration: total + const Duration(seconds: 2),
            ).isSyncApproximate(total),
            isFalse,
          );
        },
      );

      test(
        'GIVEN an RSS source that ends 30 s before the total THEN is not '
        'approximate',
        () {
          final companion = _companion(
            source: TranscriptSource.rss,
            transcribedDuration: total - const Duration(seconds: 30),
          );

          expect(companion.isSyncApproximate(total), isFalse);
        },
      );
    });

    test('GIVEN a companion WHEN toJson then fromJson THEN it is equal', () {
      final companion = _companion();

      final decoded = EpisodeCompanion.fromJson(
        jsonDecode(jsonEncode(companion.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, companion);
    });
  });
}
