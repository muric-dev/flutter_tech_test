import 'package:json_annotation/json_annotation.dart';

part 'responses_envelope.g.dart';

/// The fields AI Companion reads from a Responses API body.
@JsonSerializable(createToJson: false, checked: true)
class ResponsesEnvelope {
  const ResponsesEnvelope({required this.status, required this.output});

  factory ResponsesEnvelope.fromJson(Map<String, dynamic> json) =>
      _$ResponsesEnvelopeFromJson(json);

  /// `completed`, or `incomplete` when the answer was cut short.
  final String status;
  final List<ResponsesOutput> output;
}

/// One `output[]` item of a [ResponsesEnvelope]: a `reasoning` item or the
/// `message`.
@JsonSerializable(createToJson: false, checked: true)
class ResponsesOutput {
  const ResponsesOutput({required this.type, this.content = const []});

  factory ResponsesOutput.fromJson(Map<String, dynamic> json) =>
      _$ResponsesOutputFromJson(json);

  final String type;

  /// Only a `message` has content.
  final List<ResponsesContent> content;
}

/// One `content[]` item of a message: `output_text` or `refusal`.
@JsonSerializable(createToJson: false, checked: true)
class ResponsesContent {
  const ResponsesContent({required this.type, this.text});

  factory ResponsesContent.fromJson(Map<String, dynamic> json) =>
      _$ResponsesContentFromJson(json);

  final String type;
  final String? text;
}
