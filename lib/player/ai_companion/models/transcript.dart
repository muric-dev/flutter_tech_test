import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:equatable/equatable.dart';

/// Where the transcript came from: the feed's own file or the transcribed
/// audio.
enum TranscriptSource { rss, audio }

/// A transcript before the debrief: what the transcript stage returns.
class Transcript extends Equatable {
  const Transcript({
    required this.source,
    required this.segments,
    required this.duration,
    this.language,
  });

  final TranscriptSource source;
  final List<TranscriptSegment> segments;

  /// Length of the transcribed audio, or the end of the last cue for
  /// [TranscriptSource.rss].
  final Duration duration;

  /// Language detected by the transcription provider, when it provides one.
  /// Feed-provided subtitles do not include this metadata.
  final String? language;

  @override
  List<Object?> get props => [source, segments, duration, language];
}
