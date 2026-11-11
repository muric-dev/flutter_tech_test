import 'dart:convert';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/common/storage/local_storage.dart';
import 'package:cabina/player/ai_companion/data/services/ai_companion_cache_service.dart';
import 'package:cabina/player/ai_companion/models/chapter.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalStorage extends Mock implements LocalStorage {}

const _feedUrl = 'https://feeds.example.com/night-shift.xml';
const _guid = 'night-shift-42';

const _companion = EpisodeCompanion(
  source: TranscriptSource.audio,
  segments: [
    TranscriptSegment(start: Duration(seconds: 4), text: 'Welcome back.'),
    TranscriptSegment(start: Duration(seconds: 8), text: 'Lighthouses.'),
  ],
  transcribedDuration: Duration(seconds: 56),
  summary: 'A night with the last lighthouse keepers.',
  chapters: [Chapter(title: 'Lighthouses', segmentIndex: 1)],
);

void main() {
  late _MockLocalStorage storage;
  late AICompanionCacheService service;

  /// What `write` stored, by key.
  late Map<String, String> stored;

  setUp(() {
    storage = _MockLocalStorage();
    service = AICompanionCacheService(localStorage: storage);
    stored = {};
    when(() => storage.write(any(), any())).thenAnswer((invocation) async {
      final [key as String, value as String] = invocation.positionalArguments;
      stored[key] = value;
    });
    when(() => storage.read(any())).thenAnswer(
      (invocation) async => stored[invocation.positionalArguments.single],
    );
  });

  Future<void> write() =>
      service.write(feedUrl: _feedUrl, guid: _guid, companion: _companion);

  Future<EpisodeCompanion?> read({String feedUrl = _feedUrl}) =>
      service.read(feedUrl: feedUrl, guid: _guid);

  group('AICompanionCacheService', () {
    test('GIVEN a written episode WHEN read THEN returns it', () async {
      await write();

      expect(await read(), _companion);
    });

    test('GIVEN a value written with another schemaVersion '
        'WHEN read THEN returns null', () async {
      await write();
      final key = stored.keys.single;
      stored[key] = jsonEncode({
        ...jsonDecode(stored[key]!) as Map<String, dynamic>,
        'schemaVersion': 0,
      });

      expect(await read(), isNull);
    });

    test('GIVEN the same guid under two feed URLs '
        'WHEN read THEN each reads its own key', () async {
      await write();

      expect(
        await read(feedUrl: 'https://feeds.example.com/day-shift.xml'),
        isNull,
      );
      expect(await read(), _companion);
    });

    test('GIVEN a corrupt value or a storage failure '
        'WHEN read THEN returns null', () async {
      await write();
      stored[stored.keys.single] = '{"schemaVersion": 1, "segments": 3}';
      expect(await read(), isNull);

      when(
        () => storage.read(any()),
      ).thenThrow(const StorageException('Could not load your saved data'));
      expect(await read(), isNull);
    });
  });
}
