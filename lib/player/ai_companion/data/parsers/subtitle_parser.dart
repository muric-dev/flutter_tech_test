import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';

/// Turns a feed's SRT or VTT transcript into a [Transcript].
///
/// Both formats share the cue shape: an optional identifier, a
/// `start --> end` line and the text. VTT uses `.` before the milliseconds
/// and may leave out the hours; SRT uses `,`.
class SubtitleParser {
  const SubtitleParser();

  static final _blankLine = RegExp(r'\n[ \t]*\n');
  static final _timing = RegExp(
    r'^((?:\d+:)?\d{2}:\d{2}[.,]\d{3})\s+-->\s+((?:\d+:)?\d{2}:\d{2}[.,]\d{3})',
  );
  static final _tag = RegExp('<[^>]*>');
  static final _whitespace = RegExp(r'\s+');
  static final _musicOnly = RegExp(r'^[♪\s]+$');

  /// Parses [text] into its cues, in file order. A cue that is only `♪` or
  /// `[Music]` becomes a music segment, but only between spoken cues: the
  /// list starts and ends on a sentence.
  ///
  /// Blocks with no timing line (the VTT header, `NOTE` and `STYLE` blocks)
  /// and cues with no text are skipped: they have nothing to show.
  ///
  /// Throws a [FeedParseException] when [text] has no cue, as when the URL
  /// serves an HTML page.
  Transcript parse(String text) {
    final segments = <TranscriptSegment>[];
    var end = Duration.zero;
    for (final block in text.replaceAll('\r', '').split(_blankLine)) {
      final lines = block.trim().split('\n');
      final timingLine = lines.indexWhere(_timing.hasMatch);
      if (timingLine == -1) continue;

      final timing = _timing.firstMatch(lines[timingLine])!;
      final cue = lines
          .skip(timingLine + 1)
          .join(' ')
          .replaceAll(_tag, '')
          .replaceAll(_whitespace, ' ')
          .trim();
      if (cue.isEmpty) continue;

      final isMusic =
          _musicOnly.hasMatch(cue) || cue.toLowerCase() == '[music]';
      segments.add(
        TranscriptSegment(
          start: _timestamp(timing.group(1)!),
          text: isMusic ? '♪' : cue,
          isMusic: isMusic,
        ),
      );
      end = _timestamp(timing.group(2)!);
    }

    if (segments.isEmpty) {
      throw const FeedParseException('Transcript has no cues');
    }
    final first = segments.indexWhere((segment) => !segment.isMusic);
    final last = segments.lastIndexWhere((segment) => !segment.isMusic);
    return Transcript(
      source: TranscriptSource.rss,
      segments: first == -1 ? const [] : segments.sublist(first, last + 1),
      duration: end,
    );
  }

  /// `hh:mm:ss,mmm`, `hh:mm:ss.mmm` or `mm:ss.mmm`, already matched by
  /// [_timing].
  Duration _timestamp(String value) {
    final [seconds, millis] = value.split(RegExp('[.,]'));
    final parts = seconds.split(':').map(int.parse).toList().reversed.toList();
    return Duration(
      hours: parts.length > 2 ? parts[2] : 0,
      minutes: parts[1],
      seconds: parts[0],
      milliseconds: int.parse(millis),
    );
  }
}
