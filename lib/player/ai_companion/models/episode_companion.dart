import 'package:cabina/player/ai_companion/models/chapter.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'episode_companion.g.dart';

/// An episode prepared by AI Companion: transcript, summary and chapters.
/// It is cached only when complete.
@JsonSerializable(checked: true, explicitToJson: true)
class EpisodeCompanion extends Equatable {
  const EpisodeCompanion({
    required this.source,
    required this.segments,
    required this.transcribedDuration,
    required this.summary,
    required this.chapters,
  });

  factory EpisodeCompanion.fromJson(Map<String, dynamic> json) =>
      _$EpisodeCompanionFromJson(json);

  /// How far the transcript and the player's duration can drift before the
  /// sheet warns that sync is approximate.
  static const syncTolerance = Duration(seconds: 3);

  final TranscriptSource source;
  final List<TranscriptSegment> segments;

  /// See [Transcript.duration].
  final Duration transcribedDuration;
  final String summary;

  /// Sorted by [Chapter.segmentIndex], one per segment at most.
  final List<Chapter> chapters;

  /// The segment playing at [position]: the last one whose start is at or
  /// before it, or the first one before the transcript starts.
  int indexAt(Duration position) {
    var low = 0;
    var high = segments.length - 1;
    var index = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (segments[mid].start <= position) {
        index = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return index;
  }

  /// Whether the transcript's times may be off for a file [total] long.
  ///
  /// An RSS transcript says nothing about the file's length, and an outro
  /// with no cues is normal, so it only drifts when it ends after the file.
  bool isSyncApproximate(Duration total) => switch (source) {
    TranscriptSource.audio =>
      (transcribedDuration - total).abs() > syncTolerance,
    TranscriptSource.rss => transcribedDuration - total > syncTolerance,
  };

  Map<String, dynamic> toJson() => _$EpisodeCompanionToJson(this);

  @override
  List<Object?> get props => [
    source,
    segments,
    transcribedDuration,
    summary,
    chapters,
  ];
}
