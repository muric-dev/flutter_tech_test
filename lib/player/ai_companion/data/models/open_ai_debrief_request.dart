import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'open_ai_debrief_request.g.dart';

/// The body of the debrief call to `POST /v1/responses`. Typed so a field
/// can't be misspelled or dropped without the compiler noticing.
@JsonSerializable(createFactory: false, explicitToJson: true)
class OpenAIDebriefRequest {
  const OpenAIDebriefRequest({
    required this.model,
    required this.reasoning,
    required this.instructions,
    required this.segments,
    required this.text,
  });

  final String model;
  final ResponsesReasoning reasoning;

  /// The developer message.
  final String instructions;

  /// Sent as `input`: the segments encoded as one JSON string.
  @JsonKey(name: 'input', toJson: _encodeSegments)
  final List<DebriefInputSegment> segments;

  final ResponsesText text;

  Map<String, dynamic> toJson() => _$OpenAIDebriefRequestToJson(this);

  static String _encodeSegments(List<DebriefInputSegment> segments) =>
      jsonEncode([for (final segment in segments) segment.toJson()]);
}

/// One spoken segment as the model reads it: its index in the transcript
/// and its text.
@JsonSerializable(createFactory: false)
class DebriefInputSegment {
  const DebriefInputSegment({required this.id, required this.text});

  final int id;
  final String text;

  Map<String, dynamic> toJson() => _$DebriefInputSegmentToJson(this);
}

/// The `reasoning` field of a Responses API request.
@JsonSerializable(createFactory: false)
class ResponsesReasoning {
  const ResponsesReasoning({required this.effort});

  final ResponsesEffort effort;

  Map<String, dynamic> toJson() => _$ResponsesReasoningToJson(this);
}

/// How much the model reasons before it answers: more costs more tokens and
/// time.
enum ResponsesEffort { low, medium, high }

/// The `text` field of a Responses API request: the answer's format.
@JsonSerializable(createFactory: false, explicitToJson: true)
class ResponsesText {
  const ResponsesText({required this.format});

  final ResponsesJsonSchema format;

  Map<String, dynamic> toJson() => _$ResponsesTextToJson(this);
}

/// A Structured Outputs format: the answer must follow [schema].
@JsonSerializable(createFactory: false)
class ResponsesJsonSchema {
  const ResponsesJsonSchema({
    required this.name,
    required this.strict,
    required this.schema,
  });

  @JsonKey(includeToJson: true)
  String get type => 'json_schema';

  final String name;
  final bool strict;
  final Map<String, Object> schema;

  Map<String, dynamic> toJson() => _$ResponsesJsonSchemaToJson(this);
}
