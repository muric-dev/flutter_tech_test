import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:flutter/material.dart';

/// The top of the AI Companion sheet at full height: a button that brings
/// it back to half height and the episode and podcast titles, centered.
class EpisodeInfoBar extends StatelessWidget {
  const EpisodeInfoBar({
    required this.args,
    required this.onCollapse,
    super.key,
  });

  final PlayerArgs args;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Collapse',
            color: theme.foregroundSoft,
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: onCollapse,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  args.episode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: theme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  args.podcastTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: theme.foregroundSoft,
                  ),
                ),
              ],
            ),
          ),
          // Same width as the collapse button, so the titles stay centered.
          const SizedBox(width: kMinInteractiveDimension),
        ],
      ),
    );
  }
}
