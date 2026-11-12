import 'package:cabina/common/extensions/duration_format.dart';
import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/models/chapter.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One chapter: its start time and title. A tap seeks to [start].
class ChapterRow extends StatelessWidget {
  const ChapterRow({required this.chapter, required this.start, super.key});

  final Chapter chapter;
  final Duration start;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return InkWell(
      onTap: () => context.read<PlayerBloc>().add(PlayerSeeked(start)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                start.clock,
                style: AppTextStyles.label.copyWith(color: theme.primary),
              ),
            ),
            Expanded(
              child: Text(
                chapter.title,
                style: AppTextStyles.body.copyWith(color: theme.foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
