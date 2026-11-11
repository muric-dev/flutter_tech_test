import 'dart:convert';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/common/storage/local_storage.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:json_annotation/json_annotation.dart';

/// AI Companion's local data source: the prepared episodes cached on this
/// device, one key per episode.
class AICompanionCacheService {
  AICompanionCacheService({required LocalStorage localStorage})
    : _localStorage = localStorage;

  final LocalStorage _localStorage;

  /// Bumped when the cached shape changes: older values read as no cache.
  static const _schemaVersion = 1;

  /// The episode cached for [guid] in [feedUrl], or `null`.
  ///
  /// A value that can't be read (storage failure, not JSON, another
  /// `schemaVersion` or an unknown shape) also returns `null`: it is only a
  /// cache, and the episode is prepared again.
  Future<EpisodeCompanion?> read({
    required String feedUrl,
    required String guid,
  }) async {
    try {
      final raw = await _localStorage.read(_keyOf(feedUrl, guid));
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          json['schemaVersion'] != _schemaVersion) {
        return null;
      }
      return EpisodeCompanion.fromJson(json);
    } on StorageException {
      return null;
    } on FormatException {
      return null;
    } on CheckedFromJsonException {
      return null;
    }
  }

  /// Caches [companion], which must be complete.
  Future<void> write({
    required String feedUrl,
    required String guid,
    required EpisodeCompanion companion,
  }) => _localStorage.write(
    _keyOf(feedUrl, guid),
    jsonEncode({'schemaVersion': _schemaVersion, ...companion.toJson()}),
  );

  /// The guid alone can repeat across podcasts, so the feed is part of the
  /// key. Base64 keeps the key free of the URL's characters.
  String _keyOf(String feedUrl, String guid) =>
      'ai_companion_${base64Url.encode(utf8.encode('$feedUrl\n$guid'))}';
}
