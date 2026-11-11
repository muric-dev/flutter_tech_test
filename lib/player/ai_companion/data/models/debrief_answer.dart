import 'package:json_annotation/json_annotation.dart';

part 'debrief_answer.g.dart';

/// The debrief JSON the strict schema asks the model for.
@JsonSerializable(createToJson: false, checked: true)
class DebriefAnswer {
  const DebriefAnswer({required this.summary, required this.chapters});

  factory DebriefAnswer.fromJson(Map<String, dynamic> json) =>
      _$DebriefAnswerFromJson(json);

  final String summary;
  final List<DebriefAnswerChapter> chapters;
}

/// A chapter of a [DebriefAnswer]: its title and the id of its first
/// segment.
@JsonSerializable(createToJson: false, checked: true)
class DebriefAnswerChapter {
  const DebriefAnswerChapter({required this.title, required this.segmentId});

  factory DebriefAnswerChapter.fromJson(Map<String, dynamic> json) =>
      _$DebriefAnswerChapterFromJson(json);

  final String title;
  final int segmentId;
}
