import 'dart:async';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/player/ai_companion/data/parsers/debrief_parser.dart';
import 'package:cabina/player/ai_companion/data/parsers/subtitle_parser.dart';
import 'package:cabina/player/ai_companion/data/parsers/whisper_transcript_parser.dart';
import 'package:cabina/player/ai_companion/data/services/ai_companion_cache_service.dart';
import 'package:cabina/player/ai_companion/data/services/episode_download_service.dart';
import 'package:cabina/player/ai_companion/data/services/open_ai_service.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:cabina/show_detail/models/episode.dart';

/// Prepares an episode for AI Companion (transcript, then debrief) and
/// caches the result on this device. Every failure reaches the caller as an
/// [AICompanionException] with a message safe to show.
class AICompanionRepository {
  AICompanionRepository({
    required AICompanionCacheService cacheService,
    required EpisodeDownloadService downloadService,
    required OpenAIService openAIService,
  }) : _cacheService = cacheService,
       _downloadService = downloadService,
       _openAIService = openAIService;

  final AICompanionCacheService _cacheService;
  final EpisodeDownloadService _downloadService;
  final OpenAIService _openAIService;

  static const _subtitleParser = SubtitleParser();
  static const _whisperParser = WhisperTranscriptParser();
  static const _debriefParser = DebriefParser();

  static const _notAvailable = AICompanionException(
    "AI Companion isn't available right now",
  );
  static const _tooLong = AICompanionException(
    'This episode is too long for AI Companion',
  );
  static const _notEnoughSpeech = AICompanionException(
    'Not enough spoken audio in this episode',
  );

  /// The episode cached on this device, or `null`. See
  /// [AICompanionCacheService.read].
  Future<EpisodeCompanion?> loadCached(PlayerArgs args) =>
      _cacheService.read(feedUrl: args.feedUrl, guid: args.episode.guid);

  /// The feed's transcript when [episode] has one, else the transcribed
  /// audio. No request is made without a key.
  Future<Transcript> transcript(Episode episode) => _guard(() async {
    if (!_openAIService.isConfigured) throw _notAvailable;

    final transcriptUrl = episode.transcriptUrl;
    final transcript = transcriptUrl != null
        ? _subtitleParser.parse(
            await _downloadService.fetchTranscript(transcriptUrl),
          )
        : await _transcribe(episode.audioUrl);

    if (transcript.segments.isEmpty) throw _notEnoughSpeech;
    return transcript;
  });

  /// The summary and chapters of [transcript].
  Future<EpisodeCompanion> debrief(Transcript transcript) => _guard(
    () async => _debriefParser.parse(
      await _openAIService.debrief(transcript.segments),
      transcript,
    ),
  );

  /// Caches [companion], which must be complete.
  Future<void> save(PlayerArgs args, EpisodeCompanion companion) =>
      _cacheService.write(
        feedUrl: args.feedUrl,
        guid: args.episode.guid,
        companion: companion,
      );

  Future<Transcript> _transcribe(String audioUrl) async {
    final bytes = await _downloadService.fetchAudio(audioUrl);
    if (bytes == null) throw _tooLong;
    return _whisperParser.parse(
      await _openAIService.transcribe(bytes, _fileNameOf(audioUrl)),
    );
  }

  /// The enclosure's file name without the query, `.mp3` added when it has
  /// no extension: the transcription reads the format from it.
  String _fileNameOf(String audioUrl) {
    final name = Uri.tryParse(audioUrl)?.pathSegments.lastOrNull ?? '';
    if (name.isEmpty) return 'episode.mp3';
    return name.contains('.') ? name : '$name.mp3';
  }

  /// Runs [stage] and maps any failure to the user-facing message table,
  /// with the original as `cause`.
  Future<T> _guard<T>(Future<T> Function() stage) async {
    try {
      return await stage();
    } on AICompanionException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_messageFor(error), stackTrace);
    }
  }

  AICompanionException _messageFor(Object error) => switch (error) {
    ApiException(statusCode: 401 || 403) => AICompanionException(
      _notAvailable.message,
      cause: error,
    ),
    ApiException(isRateLimited: true) => AICompanionException(
      'AI Companion is busy. Try again later',
      cause: error,
    ),
    NetworkException(cause: final cause) when cause is! TimeoutException =>
      AICompanionException(
        'No connection. Check your internet and try again',
        canRetry: true,
        cause: error,
      ),
    _ => AICompanionException(
      "Couldn't prepare AI Companion",
      canRetry: true,
      cause: error,
    ),
  };
}
