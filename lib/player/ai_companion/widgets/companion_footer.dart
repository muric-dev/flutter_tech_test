import 'package:cabina/player/ai_companion/cubit/ai_companion_cubit.dart';
import 'package:cabina/player/ai_companion/widgets/header/ai_label_chip.dart';
import 'package:cabina/player/ai_companion/widgets/player/play_pause_circle_button.dart';
import 'package:cabina/player/widgets/seek_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The bottom of the AI Companion sheet: the AI label on the left once it
/// is ready. When [expanded], also the player's [SeekBar] and play/pause in
/// the center. Empty at half height until ready.
class CompanionFooter extends StatelessWidget {
  const CompanionFooter({required this.expanded, super.key});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final ready = context.select<AICompanionCubit, bool>(
      (cubit) => cubit.state.status == AICompanionStatus.ready,
    );
    if (!expanded && !ready) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (expanded) ...[
              const SeekBar(),
              const SizedBox(height: 8),
            ],
            // Both sides expand equally, so play/pause stays centered
            // whatever the chip's width.
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ready
                        ? const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: AILabelChip(),
                          )
                        : null,
                  ),
                ),
                if (expanded) const PlayPauseCircleButton(),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
