import 'package:cabina/common/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Summary and Transcript as pills, like Spotify's filter chips: the
/// selected one filled in `foreground`, the other tinted. Still a [TabBar],
/// so swipe, focus and semantics stay Material's.
class CompanionTabBar extends StatelessWidget {
  const CompanionTabBar({super.key});

  static const _labels = ['Summary', 'Transcript'];

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.only(right: 8),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: ShapeDecoration(
          shape: const StadiumBorder(),
          color: theme.foreground,
        ),
        splashBorderRadius: BorderRadius.circular(16),
        labelColor: theme.background,
        unselectedLabelColor: theme.foreground,
        labelStyle: AppTextStyles.label,
        tabs: [
          for (final label in _labels)
            Tab(
              height: 32,
              // The tint sits over the indicator: on the selected pill it
              // blends into `foreground`, on the others it is the pill.
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: theme.foreground.withValues(alpha: 0.08),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(widthFactor: 1, child: Text(label)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
