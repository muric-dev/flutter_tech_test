import 'dart:convert';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/player/ai_companion/data/models/debrief_answer.dart';
import 'package:cabina/player/ai_companion/data/models/responses_envelope.dart';
import 'package:cabina/player/ai_companion/models/chapter.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:json_annotation/json_annotation.dart';

/// Turns the AI model's debrief of a [Transcript] into an
/// [EpisodeCompanion].
///
/// The model receives the spoken segments as `{id, text}`, where `id` is the
/// segment's index in [Transcript.segments], and answers with the summary
/// and the `segmentId` where each chapter starts.
class DebriefParser {
  const DebriefParser();

  /// Parses [body], a Responses API envelope, against [transcript].
  ///
  /// Drops a chapter whose `segmentId` is not a spoken segment, or repeats
  /// an earlier one: its time can only come from a real sentence. The rest
  /// are sorted by segment.
  ///
  /// Throws a [FeedParseException] when the response is incomplete, is a
  /// refusal or has no answer in the expected shape.
  EpisodeCompanion parse(String body, Transcript transcript) {
    final answer = _decode(
      _answerText(_decode(body, ResponsesEnvelope.fromJson)),
      DebriefAnswer.fromJson,
    );

    final segments = transcript.segments;
    final seen = <int>{};
    final chapters =
        answer.chapters
            .where(
              (chapter) =>
                  chapter.segmentId >= 0 &&
                  chapter.segmentId < segments.length &&
                  !segments[chapter.segmentId].isMusic,
            )
            .map(
              (chapter) => Chapter(
                title: chapter.title.trim(),
                segmentIndex: chapter.segmentId,
              ),
            )
            .toList()
          ..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex))
          ..retainWhere((chapter) => seen.add(chapter.segmentIndex));

    return EpisodeCompanion(
      source: transcript.source,
      segments: segments,
      transcribedDuration: transcript.duration,
      summary: answer.summary.trim(),
      chapters: chapters,
    );
  }

  /// The `output_text` of the envelope's message: the debrief JSON.
  String _answerText(ResponsesEnvelope envelope) {
    if (envelope.status != 'completed') {
      throw FeedParseException('Debrief is ${envelope.status}');
    }
    final content = envelope.output
        .where((output) => output.type == 'message')
        .expand((output) => output.content)
        .toList();
    if (content.any((item) => item.type == 'refusal')) {
      throw const FeedParseException('Debrief was refused');
    }
    final text = content
        .where((item) => item.type == 'output_text')
        .firstOrNull
        ?.text;
    if (text == null) {
      throw const FeedParseException('Debrief has no answer');
    }
    return text;
  }

  T _decode<T>(String json, T Function(Map<String, dynamic>) fromJson) {
    try {
      return fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on FormatException catch (e) {
      throw FeedParseException('Debrief is not JSON', cause: e);
    } on CheckedFromJsonException catch (e) {
      throw FeedParseException('Debrief has an unknown shape', cause: e);
    }
  }
}
