import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/cubit/ai_companion_cubit.dart';
import 'package:cabina/player/ai_companion/widgets/companion_body.dart';
import 'package:cabina/player/ai_companion/widgets/companion_footer.dart';
import 'package:cabina/player/ai_companion/widgets/header/companion_header.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The AI Companion sheet over the player: a rounded card with the header,
/// the content and the footer. At half height a button takes it to full
/// height. At full height the episode shows on top, with a button
/// back to half height, and the player's controls at the bottom, so the
/// audio can be controlled without closing it.
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
  static const _halfSize = 0.6;

  final _controller = DraggableScrollableController();
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns `false` so the notification still reaches the modal, which
  /// closes the sheet when it is dragged down to its minimum.
  bool _onExtentChanged(DraggableScrollableNotification notification) {
    final expanded =
        notification.extent >= notification.maxExtent - precisionErrorTolerance;
    if (expanded != _expanded) setState(() => _expanded = expanded);
    return false;
  }

  /// Moves the sheet to [size]: animated, or at once under
  /// `disableAnimations`.
  Future<void> _moveTo(double size) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(size);
      return Future.value();
    }
    return _controller.animateTo(
      size,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: _onExtentChanged,
      child: DraggableScrollableSheet(
        controller: _controller,
        expand: false,
        initialChildSize: _halfSize,
        minChildSize: 0.3,
        snap: true,
        snapSizes: const [_halfSize],
        builder: (context, scrollController) => DefaultTabController(
          length: 2,
          child: Column(
            children: [
              // Only the header drags the sheet; each tab scrolls on its own
              // and the footer's seek bar must seek, not drag.
              SingleChildScrollView(
                controller: scrollController,
                child: CompanionHeader(
                  args: widget.args,
                  expanded: _expanded,
                  onExpand: () => _moveTo(1),
                  onCollapse: () => _moveTo(_halfSize),
                ),
              ),
              const Expanded(child: CompanionBody()),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(sizeFactor: animation, child: child),
                ),
                child: CompanionFooter(
                  key: ValueKey(_expanded),
                  expanded: _expanded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
