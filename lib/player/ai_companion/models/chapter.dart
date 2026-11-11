import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chapter.g.dart';

/// A chapter of the episode. It starts at the segment at [segmentIndex], so
/// its time always comes from the transcript, never from the AI model.
@JsonSerializable(checked: true)
class Chapter extends Equatable {
  const Chapter({required this.title, required this.segmentIndex});

  factory Chapter.fromJson(Map<String, dynamic> json) =>
      _$ChapterFromJson(json);

  final String title;
  final int segmentIndex;

  Map<String, dynamic> toJson() => _$ChapterToJson(this);

  @override
  List<Object?> get props => [title, segmentIndex];
}
