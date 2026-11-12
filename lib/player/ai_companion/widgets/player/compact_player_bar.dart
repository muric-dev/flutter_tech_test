import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/common/widgets/poster_image.dart';
import 'package:cabina/player/ai_companion/widgets/player/play_pause_circle_button.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:cabina/player/widgets/seek_bar.dart';
import 'package:flutter/material.dart';

/// The player as a card on top of the AI Companion sheet at full height:
/// artwork, episode and podcast titles, play/pause, close and the
/// player's [SeekBar].
class CompactPlayerBar extends StatelessWidget {
  const CompactPlayerBar({required this.args, super.key});

  final PlayerArgs args;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
          child: Column(
            children: [
              Row(
                children: [
                  PosterImage(url: args.artworkUrl, size: 40, borderRadius: 6),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          args.episode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            color: theme.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          args.podcastTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: theme.foregroundSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PlayPauseCircleButton(),
                  IconButton(
                    tooltip: 'Close',
                    color: theme.foregroundSoft,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SeekBar(),
            ],
          ),
        ),
      ),
    );
  }
}
