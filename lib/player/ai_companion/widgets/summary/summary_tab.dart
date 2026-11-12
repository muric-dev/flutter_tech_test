import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/widgets/summary/chapter_row.dart';
import 'package:flutter/material.dart';

/// The episode's summary and its chapters. A tap on a chapter seeks to the
/// start of its sentence.
class SummaryTab extends StatelessWidget {
  const SummaryTab({required this.companion, super.key});

  final EpisodeCompanion companion;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(
          companion.summary,
          style: AppTextStyles.body.copyWith(color: theme.foreground),
        ),
        if (companion.chapters.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Chapters',
            style: AppTextStyles.headline.copyWith(color: theme.foreground),
          ),
          const SizedBox(height: 8),
          for (final chapter in companion.chapters)
            ChapterRow(
              chapter: chapter,
              start: companion.segments[chapter.segmentIndex].start,
            ),
        ],
      ],
    );
  }
}
