import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transcript_segment.g.dart';

/// One line of the transcript: a spoken sentence, or a music section (♪)
/// when [isMusic].
@JsonSerializable(checked: true)
class TranscriptSegment extends Equatable {
  const TranscriptSegment({
    required this.start,
    required this.text,
    this.isMusic = false,
  });

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) =>
      _$TranscriptSegmentFromJson(json);

  final Duration start;
  final String text;
  final bool isMusic;

  Map<String, dynamic> toJson() => _$TranscriptSegmentToJson(this);

  @override
  List<Object?> get props => [start, text, isMusic];
}
