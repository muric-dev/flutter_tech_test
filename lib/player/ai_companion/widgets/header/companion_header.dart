import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/cubit/ai_companion_cubit.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/widgets/header/ai_label_chip.dart';
import 'package:cabina/player/ai_companion/widgets/header/companion_tab_bar.dart';
import 'package:cabina/player/ai_companion/widgets/header/sheet_handle.dart';
import 'package:cabina/player/ai_companion/widgets/header/sync_notice.dart';
import 'package:cabina/player/ai_companion/widgets/player/compact_player_bar.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The top of the AI Companion sheet: the handle, or the compact player
/// when [expanded]; the title with the AI chip; and, once ready, the sync
/// notice and the tabs.
class CompanionHeader extends StatelessWidget {
  const CompanionHeader({
    required this.args,
    required this.expanded,
    super.key,
  });

  final PlayerArgs args;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final companion = context.select<AICompanionCubit, EpisodeCompanion?>(
      (cubit) => cubit.state.status == AICompanionStatus.ready
          ? cubit.state.companion
          : null,
    );
    return Column(
      children: [
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: child,
            ),
          ),
          child: expanded
              ? CompactPlayerBar(key: const ValueKey('player'), args: args)
              : const SheetHandle(key: ValueKey('handle')),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primary.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.auto_awesome, color: theme.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Companion',
                  style: AppTextStyles.headline.copyWith(
                    color: theme.foreground,
                  ),
                ),
              ),
              if (companion != null) const AILabelChip(),
            ],
          ),
        ),
        if (companion != null) ...[
          SyncNotice(companion: companion),
          const CompanionTabBar(),
        ],
      ],
    );
  }
}
