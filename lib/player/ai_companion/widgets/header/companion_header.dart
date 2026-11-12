import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/cubit/ai_companion_cubit.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/widgets/header/companion_tab_bar.dart';
import 'package:cabina/player/ai_companion/widgets/header/episode_info_bar.dart';
import 'package:cabina/player/ai_companion/widgets/header/sheet_handle.dart';
import 'package:cabina/player/ai_companion/widgets/header/sync_notice.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The top of the AI Companion sheet. At half height: the handle and the
/// title, with a button that calls [onExpand]. When [expanded]: the
/// [EpisodeInfoBar], whose button calls [onCollapse]. Once ready, the sync
/// notice and the tabs.
class CompanionHeader extends StatelessWidget {
  const CompanionHeader({
    required this.args,
    required this.expanded,
    required this.onExpand,
    required this.onCollapse,
    super.key,
  });

  final PlayerArgs args;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;

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
              ? EpisodeInfoBar(
                  key: const ValueKey('episode'),
                  args: args,
                  onCollapse: onCollapse,
                )
              : Column(
                  key: const ValueKey('title'),
                  children: [
                    const SheetHandle(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: theme.primary,
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
                          IconButton(
                            tooltip: 'Full screen',
                            color: theme.foregroundSoft,
                            icon: const Icon(Icons.open_in_full),
                            onPressed: onExpand,
                          ),
                        ],
                      ),
                    ),
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
