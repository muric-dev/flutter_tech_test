import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:flutter/material.dart';

/// One transcript sentence: highlighted in `primary` when it is the one
/// playing, dimmed otherwise. A tap calls [onTap].
class SegmentRow extends StatelessWidget {
  const SegmentRow({
    required this.segment,
    required this.isActive,
    required this.onTap,
    super.key,
  });

  final TranscriptSegment segment;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Semantics(
      selected: isActive,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            segment.text,
            style: AppTextStyles.body.copyWith(
              color: isActive ? theme.primary : theme.foregroundSoft,
              fontWeight: isActive ? FontWeight.w600 : null,
            ),
          ),
        ),
      ),
    );
  }
}
