import 'package:json_annotation/json_annotation.dart';

part 'whisper_response.g.dart';

/// The fields AI Companion reads from a Whisper `verbose_json` response.
@JsonSerializable(createToJson: false, checked: true)
class WhisperResponse {
  const WhisperResponse({
    required this.duration,
    required this.segments,
    this.language,
  });

  factory WhisperResponse.fromJson(Map<String, dynamic> json) =>
      _$WhisperResponseFromJson(json);

  /// Seconds of audio.
  final double duration;
  final List<WhisperSegment> segments;

  /// The language Whisper detected. Optional: without it the debrief still
  /// runs and the model detects the language from the transcript.
  final String? language;
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
