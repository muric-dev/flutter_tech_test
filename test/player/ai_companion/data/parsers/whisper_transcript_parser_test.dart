import 'dart:convert';

import 'package:cabina/player/ai_companion/data/parsers/whisper_transcript_parser.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Whisper `verbose_json` segment, with the scores of a clear sentence by
/// default.
Map<String, Object> _segment(
  int id,
  double start,
  double end,
  String text, {
  double avgLogprob = -0.21,
  double compressionRatio = 1.32,
  double noSpeechProb = 0.02,
}) => {
  'id': id,
  'seek': 0,
  'start': start,
  'end': end,
  'text': text,
  'tokens': [50364, 2421, 646],
  'temperature': 0.0,
  'avg_logprob': avgLogprob,
  'compression_ratio': compressionRatio,
  'no_speech_prob': noSpeechProb,
};

String _response(List<Map<String, Object>> segments) => jsonEncode({
  'task': 'transcribe',
  'language': 'english',
  'duration': 96.0,
  'text': segments.map((s) => s['text']).join(),
  'segments': segments,
});

void main() {
  const parser = WhisperTranscriptParser();

  group('WhisperTranscriptParser', () {
    test(
      'GIVEN a 20 s silent intro, a looped hallucination, a repeated line, a '
      '30 s gap and a 24 s outro THEN keeps the spoken segments with a music '
      'segment only in the gap',
      () {
        final body = _response([
          _segment(0, 0, 20, ' ', avgLogprob: -1.3, noSpeechProb: 0.92),
          _segment(1, 20, 24, ' Welcome back to Night Shift.'),
          _segment(2, 24, 28, ' Today we talk about lighthouses.'),
          _segment(3, 28, 30, ' Today we talk about lighthouses.'),
          _segment(4, 60, 63.5, ' We are back.'),
          _segment(
            5,
            63.5,
            68,
            ' and and and and and and and and and and and and',
            compressionRatio: 3.1,
          ),
          _segment(6, 68, 72, ' Thanks for listening.'),
        ]);

        expect(
          parser.parse(body),
          const Transcript(
            source: TranscriptSource.audio,
            segments: [
              TranscriptSegment(
                start: Duration(seconds: 20),
                text: 'Welcome back to Night Shift.',
              ),
              TranscriptSegment(
                start: Duration(seconds: 24),
                text: 'Today we talk about lighthouses.',
              ),
              TranscriptSegment(
                start: Duration(seconds: 28),
                text: '♪',
                isMusic: true,
              ),
              TranscriptSegment(
                start: Duration(seconds: 60),
                text: 'We are back.',
              ),
              TranscriptSegment(
                start: Duration(seconds: 68),
                text: 'Thanks for listening.',
              ),
            ],
            duration: Duration(seconds: 96),
          ),
        );
      },
    );

    test(
      'GIVEN a response where every segment is filtered THEN returns no '
      'spoken segment',
      () {
        final body = _response([
          _segment(0, 0, 30, ' Music', avgLogprob: -1.1, noSpeechProb: 0.81),
          _segment(1, 30, 56, ' ♪', avgLogprob: -1.6, noSpeechProb: 0.97),
        ]);

        expect(
          parser.parse(body).segments.where((segment) => !segment.isMusic),
          isEmpty,
        );
      },
    );
  });
}
