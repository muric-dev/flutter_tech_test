import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/cubit/ai_companion_cubit.dart';
import 'package:cabina/player/ai_companion/widgets/companion_body.dart';
import 'package:cabina/player/ai_companion/widgets/header/companion_header.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The AI Companion sheet over the player: a rounded card with the header
/// and the content. At full height the header shows a compact player, so
/// the audio can be controlled without closing it.
class AICompanionSheet extends StatefulWidget {
  const AICompanionSheet({required this.args, super.key});

  final PlayerArgs args;

  /// Opens the sheet over the player. [context] must read both the
  /// [PlayerBloc] and the [AICompanionCubit]: the sheet lives in its own
  /// route, so both are passed in.
  static Future<void> show(BuildContext context, PlayerArgs args) {
    final playerBloc = context.read<PlayerBloc>();
    final companionCubit = context.read<AICompanionCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appTheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: playerBloc),
          BlocProvider.value(value: companionCubit),
        ],
        child: AICompanionSheet(args: args),
      ),
    );
  }

  @override
  State<AICompanionSheet> createState() => _AICompanionSheetState();
}

class _AICompanionSheetState extends State<AICompanionSheet> {
  bool _expanded = false;

  /// Returns `false` so the notification still reaches the modal, which
  /// closes the sheet when it is dragged down to its minimum.
  bool _onExtentChanged(DraggableScrollableNotification notification) {
    final expanded =
        notification.extent >= notification.maxExtent - precisionErrorTolerance;
    if (expanded != _expanded) setState(() => _expanded = expanded);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: _onExtentChanged,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        snap: true,
        snapSizes: const [0.6],
        builder: (context, scrollController) => DefaultTabController(
          length: 2,
          child: Column(
            children: [
              // Only the header drags the sheet; each tab scrolls on its own.
              SingleChildScrollView(
                controller: scrollController,
                child: CompanionHeader(
                  args: widget.args,
                  expanded: _expanded,
                ),
              ),
              const Expanded(child: CompanionBody()),
            ],
          ),
        ),
      ),
    );
  }
}
