import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/common/widgets/poster_image.dart';
import 'package:cabina/common/widgets/status_views.dart';
import 'package:cabina/player/ai_companion/widgets/buttons/ai_companion_button.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:cabina/player/data/services/just_audio_player_service.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:cabina/player/models/player_status.dart';
import 'package:cabina/player/widgets/player_controls.dart';
import 'package:cabina/player/widgets/seek_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Full-screen player for one episode. Opens it on start and stops it when
/// the route is popped, since the bloc is route-scoped.
class PlayerPage extends StatefulWidget {
  const PlayerPage({required this.args, super.key});

  final PlayerArgs args;

  static const routeName = 'player';
  static const routePath = '/player';

  static GoRoute route() => GoRoute(
    path: routePath,
    name: routeName,
    builder: (_, state) {
      final args = state.extra! as PlayerArgs;
      return BlocProvider(
        create: (_) => PlayerBloc(repository: JustAudioPlayerService()),
        child: PlayerPage(args: args),
      );
    },
  );

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  @override
  void initState() {
    super.initState();
    context.read<PlayerBloc>().add(PlayerOpened(widget.args));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: BlocListener<PlayerBloc, PlayerState>(
        listenWhen: (previous, current) =>
            current.status != PlayerStatus.error &&
            current.errorMessage != null &&
            current.errorMessage != previous.errorMessage,
        listener: (context, state) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!))),
        child: BlocSelector<PlayerBloc, PlayerState, bool>(
          selector: (state) => state.status == PlayerStatus.error,
          builder: (context, failed) {
            if (failed) {
              return ErrorView(
                message: context.read<PlayerBloc>().state.errorMessage!,
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  const Spacer(),
                  _EpisodeHeader(args: widget.args),
                  const Spacer(),
                  const SeekBar(),
                  const SizedBox(height: 12),
                  const PlayerControls(),
                  const SizedBox(height: 16),
                  AICompanionButton(args: widget.args),
                  const Spacer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Artwork and titles. Built from the route's args, so position and status
/// changes never rebuild it.
class _EpisodeHeader extends StatelessWidget {
  const _EpisodeHeader({required this.args});

  final PlayerArgs args;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PosterImage(url: args.artworkUrl, borderRadius: 20),
        ),
        const SizedBox(height: 28),
        Text(
          args.episode.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headline.copyWith(color: theme.foreground),
        ),
        const SizedBox(height: 6),
        Text(
          args.podcastTitle,
          style: AppTextStyles.caption.copyWith(color: theme.foregroundSoft),
        ),
      ],
    );
  }
}
