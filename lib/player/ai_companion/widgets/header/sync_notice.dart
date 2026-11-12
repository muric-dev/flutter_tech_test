import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Says the sync may be approximate. Shown only once the player knows
/// the episode's length and it doesn't match the transcript's.
class SyncNotice extends StatelessWidget {
  const SyncNotice({required this.companion, super.key});

  final EpisodeCompanion companion;

  @override
  Widget build(BuildContext context) {
    final total = context.select<PlayerBloc, Duration?>(
      (bloc) => bloc.state.position.total,
    );
    if (total == null || !companion.isSyncApproximate(total)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Sync may be approximate for this episode',
          style: AppTextStyles.caption.copyWith(
            color: context.appTheme.foregroundSoft,
          ),
        ),
      ),
    );
  }
}
