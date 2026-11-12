import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The compact player's play/pause: a filled `primary` circle, like the
/// player's main button but smaller.
class PlayPauseCircleButton extends StatelessWidget {
  const PlayPauseCircleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final isPlaying = context.select<PlayerBloc, bool>(
      (bloc) => bloc.state.status.isPlaying,
    );
    final label = isPlaying ? 'Pause' : 'Play';
    final icon = isPlaying ? Icons.pause : Icons.play_arrow;
    return IconButton.filled(
      tooltip: label,
      style: IconButton.styleFrom(
        backgroundColor: theme.primary,
        foregroundColor: theme.onPrimary,
        fixedSize: const Size.square(44),
      ),
      icon: Icon(icon),
      onPressed: () =>
          context.read<PlayerBloc>().add(const PlayerPlayPauseToggled()),
    );
  }
}
