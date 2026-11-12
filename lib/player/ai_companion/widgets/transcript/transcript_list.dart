import 'dart:async';

import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:cabina/player/ai_companion/widgets/transcript/segment_row.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The synced transcript. Highlights the sentence at the player's position
/// and follows it; a tap seeks to a sentence.
///
/// Rebuilds only when the active sentence changes, never on a position tick
/// inside the same one (US1). The list is lazy and anchored on a sentence,
/// so opening it far into an episode never lays out what comes before.
class TranscriptList extends StatefulWidget {
  const TranscriptList({required this.companion, super.key});

  final EpisodeCompanion companion;

  @override
  State<TranscriptList> createState() => _TranscriptListState();
}

class _TranscriptListState extends State<TranscriptList> {
  /// Where the active sentence sits, as a fraction of the list's height.
  static const _anchorAlignment = 0.25;

  final _controller = ScrollController();
  final _centerKey = UniqueKey();
  final GlobalKey _activeKey = GlobalKey();

  /// The first sentence of the center sliver, at scroll offset zero.
  late int _anchor;
  late int _active;

  /// Off after a drag by hand; on again after a jump or a tap.
  bool _following = true;

  int _indexOf(PlayerState state) =>
      widget.companion.indexAt(state.position.position);

  @override
  void initState() {
    super.initState();
    _active = _anchor = _indexOf(context.read<PlayerBloc>().state);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A move to the next or previous sentence scrolls smoothly, if the list
  /// is following. A jump (seek, skip, tap) re-anchors on the new sentence,
  /// so nothing in between is laid out, and follows again.
  void _onActiveChanged(int next) {
    final isJump = (next - _active).abs() > 1;
    setState(() {
      _active = next;
      if (isJump) {
        _anchor = next;
        _following = true;
      }
    });
    if (isJump) {
      if (_controller.hasClients) _controller.jumpTo(0);
      return;
    }
    if (!_following) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeContext = _activeKey.currentContext;
      if (!mounted || activeContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          activeContext,
          alignment: _anchorAlignment,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  bool _onScrollStart(ScrollStartNotification notification) {
    if (notification.depth == 0 && notification.dragDetails != null) {
      _following = false;
    }
    return false;
  }

  void _seek(TranscriptSegment segment) {
    _following = true;
    context.read<PlayerBloc>().add(PlayerSeeked(segment.start));
  }

  Widget _row(int index) {
    final segment = widget.companion.segments[index];
    final isActive = index == _active;
    return SegmentRow(
      key: isActive ? _activeKey : null,
      segment: segment,
      isActive: isActive,
      onTap: () => _seek(segment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.companion.segments.length;
    return BlocListener<PlayerBloc, PlayerState>(
      listenWhen: (previous, current) =>
          _indexOf(previous) != _indexOf(current),
      listener: (_, state) => _onActiveChanged(_indexOf(state)),
      child: NotificationListener<ScrollStartNotification>(
        onNotification: _onScrollStart,
        child: CustomScrollView(
          controller: _controller,
          center: _centerKey,
          anchor: _anchorAlignment,
          slivers: [
            // Before the center, slivers grow upwards: item 0 is the
            // sentence right above the anchor.
            SliverList.builder(
              itemCount: _anchor,
              itemBuilder: (_, index) => _row(_anchor - 1 - index),
            ),
            SliverList.builder(
              key: _centerKey,
              itemCount: count - _anchor,
              itemBuilder: (_, index) => _row(_anchor + index),
            ),
          ],
        ),
      ),
    );
  }
}
