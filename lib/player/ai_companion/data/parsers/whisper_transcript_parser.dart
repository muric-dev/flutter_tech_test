import 'dart:convert';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:json_annotation/json_annotation.dart';

part 'whisper_transcript_parser.g.dart';

/// Turns a Whisper `verbose_json` transcription into a [Transcript], without
/// the silence and music Whisper tends to hallucinate over.
class WhisperTranscriptParser {
  const WhisperTranscriptParser();

  /// Open-source Whisper's defaults: above it, a segment is probably silence
  /// (with [_silentLogprob]).
  static const _noSpeechProb = 0.6;
  static const _silentLogprob = -1.0;

  /// Open-source Whisper's default: above it, the text loops on itself.
  static const _loopCompressionRatio = 2.4;

  /// A gap this long between kept segments is shown as a music section.
  static const _musicGap = Duration(seconds: 10);

  /// Parses [body] and keeps the spoken segments.
  ///
  /// Drops a segment that is probably silence (`no_speech_prob` above 0.6
  /// and `avg_logprob` below -1), that loops (`compression_ratio` above 2.4),
  /// that is empty or that repeats the previous kept text: in silence and
  /// music Whisper makes those up. A gap of 10 s or more between kept
  /// segments becomes a music segment; one before the first or after the
  /// last does not, so the list starts and ends on a sentence.
  ///
  /// Throws a [FeedParseException] when [body] is not a Whisper response.
  Transcript parse(String body) {
    final WhisperResponse response;
    try {
      response = WhisperResponse.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } on FormatException catch (e) {
      throw FeedParseException('Transcription is not JSON', cause: e);
    } on CheckedFromJsonException catch (e) {
      throw FeedParseException('Transcription has an unknown shape', cause: e);
    }

    final segments = <TranscriptSegment>[];
    WhisperSegment? previous;
    for (final segment in response.segments) {
      final text = segment.text.trim();
      final isSilence =
          segment.noSpeechProb > _noSpeechProb &&
          segment.avgLogprob < _silentLogprob;
      if (text.isEmpty ||
          isSilence ||
          segment.compressionRatio > _loopCompressionRatio ||
          text == previous?.text.trim()) {
        continue;
      }

      if (previous != null &&
          _seconds(segment.start) - _seconds(previous.end) >= _musicGap) {
        segments.add(
          TranscriptSegment(
            start: _seconds(previous.end),
            text: '♪',
            isMusic: true,
          ),
        );
      }
      segments.add(
        TranscriptSegment(start: _seconds(segment.start), text: text),
      );
      previous = segment;
    }

    return Transcript(
      source: TranscriptSource.audio,
      segments: segments,
      duration: _seconds(response.duration),
    );
  }

  Duration _seconds(double value) =>
      Duration(microseconds: (value * Duration.microsecondsPerSecond).round());
}

/// The fields AI Companion reads from a Whisper `verbose_json` response.
@JsonSerializable(createToJson: false, checked: true)
class WhisperResponse {
  const WhisperResponse({required this.duration, required this.segments});

  factory WhisperResponse.fromJson(Map<String, dynamic> json) =>
      _$WhisperResponseFromJson(json);

  /// Seconds of audio.
  final double duration;
  final List<WhisperSegment> segments;
}

/// One segment of a [WhisperResponse], times in seconds.
@JsonSerializable(
  createToJson: false,
  checked: true,
  fieldRename: FieldRename.snake,
)
class WhisperSegment {
  const WhisperSegment({
    required this.start,
    required this.end,
    required this.text,
    required this.avgLogprob,
    required this.compressionRatio,
    required this.noSpeechProb,
  });

  factory WhisperSegment.fromJson(Map<String, dynamic> json) =>
      _$WhisperSegmentFromJson(json);

  final double start;
  final double end;
  final String text;
  final double avgLogprob;
  final double compressionRatio;
  final double noSpeechProb;
}
