import 'dart:async';

import 'package:cabina/common/network/api_client.dart';
import 'package:cabina/common/storage/local_storage.dart';
import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/cubit/ai_companion_cubit.dart';
import 'package:cabina/player/ai_companion/data/ai_companion_repository.dart';
import 'package:cabina/player/ai_companion/data/services/ai_companion_cache_service.dart';
import 'package:cabina/player/ai_companion/data/services/episode_download_service.dart';
import 'package:cabina/player/ai_companion/data/services/open_ai_service.dart';
import 'package:cabina/player/ai_companion/views/ai_companion_sheet.dart';
import 'package:cabina/player/ai_companion/widgets/buttons/scale_on_press.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:cabina/player/models/player_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The player's entry to AI Companion, a tinted pill. Owns the
/// [AICompanionCubit], so the preparation lives as long as the player page,
/// and opens the sheet.
///
/// Disabled until the episode has opened: if opening fails, the page swaps
/// its content (this button too) for an error, which would close the cubit
/// under an open sheet.
class AICompanionButton extends StatelessWidget {
  const AICompanionButton({required this.args, super.key});

  final PlayerArgs args;

  /// Empty when the app runs without `--dart-define-from-file=.env`.
  static const _apiKey = String.fromEnvironment('OPENAI_API_KEY');

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final opening = context.select<PlayerBloc, bool>(
      (bloc) =>
          bloc.state.status == PlayerStatus.idle ||
          bloc.state.status == PlayerStatus.loading,
    );
    // Lazy: nothing is built, read or requested until the first tap (US7).
    return BlocProvider(
      create: (context) {
        final apiClient = context.read<ApiClient>();
        return AICompanionCubit(
          repository: AICompanionRepository(
            cacheService: AICompanionCacheService(
              localStorage: context.read<LocalStorage>(),
            ),
            downloadService: EpisodeDownloadService(apiClient: apiClient),
            openAIService: OpenAIService(apiClient: apiClient, apiKey: _apiKey),
          ),
          args: args,
        );
      },
      child: Builder(
        builder: (context) => ScaleOnPress(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: theme.primary.withValues(alpha: 0.15),
              foregroundColor: theme.primary,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              textStyle: AppTextStyles.label,
            ),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('AI Companion'),
            onPressed: opening
                ? null
                : () {
                    unawaited(context.read<AICompanionCubit>().start());
                    unawaited(AICompanionSheet.show(context, args));
                  },
          ),
        ),
      ),
    );
  }
}
