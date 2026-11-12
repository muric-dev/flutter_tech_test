import 'package:cabina/common/widgets/status_views.dart';
import 'package:cabina/player/ai_companion/cubit/ai_companion_cubit.dart';
import 'package:cabina/player/ai_companion/widgets/summary/summary_tab.dart';
import 'package:cabina/player/ai_companion/widgets/transcript/transcript_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The AI Companion sheet's content: loading, an error with Retry when it
/// applies, or the Summary and Transcript tabs.
class CompanionBody extends StatelessWidget {
  const CompanionBody({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AICompanionCubit>().state;
    final companion = state.companion;
    return switch (state.status) {
      AICompanionStatus.ready when companion != null => TabBarView(
        children: [
          SummaryTab(companion: companion),
          TranscriptList(companion: companion),
        ],
      ),
      AICompanionStatus.error => ErrorView(
        message: state.errorMessage!,
        onRetry: state.canRetry ? context.read<AICompanionCubit>().retry : null,
      ),
      _ => const LoaderView(),
    };
  }
}
