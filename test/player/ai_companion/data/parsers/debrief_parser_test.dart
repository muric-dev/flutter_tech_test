import 'dart:convert';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/player/ai_companion/data/parsers/debrief_parser.dart';
import 'package:cabina/player/ai_companion/models/chapter.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:flutter_test/flutter_test.dart';

const _transcript = Transcript(
  source: TranscriptSource.audio,
  segments: [
    TranscriptSegment(start: Duration(seconds: 4), text: 'Welcome back.'),
    TranscriptSegment(start: Duration(seconds: 8), text: 'Lighthouses.'),
    TranscriptSegment(start: Duration(seconds: 12), text: '♪', isMusic: true),
    TranscriptSegment(start: Duration(seconds: 44), text: 'We are back.'),
  ],
  duration: Duration(seconds: 56),
);

const Map<String, Object> _reasoning = {
  'id': 'rs_68f1a2',
  'type': 'reasoning',
  'summary': <Object>[],
};

/// A Responses API body around [output], as `POST /v1/responses` returns it.
String _envelope(
  List<Map<String, Object>> output, {
  String status = 'completed',
}) => jsonEncode({
  'id': 'resp_68f1a2',
  'object': 'response',
  'created_at': 1762790400,
  'status': status,
  'model': 'gpt-5.6-luna',
  'output': output,
  'usage': {'input_tokens': 812, 'output_tokens': 230, 'total_tokens': 1042},
});

Map<String, Object> _message(Map<String, Object> content) => {
  'id': 'msg_68f1a2',
  'type': 'message',
  'status': 'completed',
  'role': 'assistant',
  'content': [content],
};

Map<String, Object> _outputText(Object answer) => {
  'type': 'output_text',
  'annotations': <Object>[],
  'text': jsonEncode(answer),
};

void main() {
  const parser = DebriefParser();

  group('DebriefParser', () {
    test(
      'GIVEN a reasoning item before the message, and chapters out of order '
      'with unknown and repeated ids THEN returns the summary and the known '
      'chapters sorted',
      () {
        final body = _envelope([
          _reasoning,
          _message(
            _outputText({
              'summary': 'A short history of lighthouses.',
              'chapters': [
                {'title': 'After the break', 'segmentId': 3},
                {'title': 'Intro', 'segmentId': 0},
                {'title': 'Made up', 'segmentId': 42},
                {'title': 'The music', 'segmentId': 2},
                {'title': 'Again', 'segmentId': 3},
              ],
            }),
          ),
        ]);

        expect(
          parser.parse(body, _transcript),
          EpisodeCompanion(
            source: TranscriptSource.audio,
            segments: _transcript.segments,
            transcribedDuration: _transcript.duration,
            summary: 'A short history of lighthouses.',
            chapters: const [
              Chapter(title: 'Intro', segmentIndex: 0),
              Chapter(title: 'After the break', segmentIndex: 3),
            ],
          ),
        );
      },
    );

    test(
      'GIVEN a refusal or an incomplete response THEN throws '
      'FeedParseException',
      () {
        final refusal = _envelope([
          _reasoning,
          _message({
            'type': 'refusal',
            'refusal': "I'm sorry, I can't help with that.",
          }),
        ]);
        final incomplete = _envelope([_reasoning], status: 'incomplete');

        expect(
          () => parser.parse(refusal, _transcript),
          throwsA(isA<FeedParseException>()),
        );
        expect(
          () => parser.parse(incomplete, _transcript),
          throwsA(isA<FeedParseException>()),
        );
      },
    );
  });
}
