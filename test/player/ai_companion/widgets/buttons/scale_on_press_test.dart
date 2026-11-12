import 'package:cabina/player/ai_companion/widgets/buttons/scale_on_press.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpScale(WidgetTester tester, {bool reduceMotion = false}) =>
      tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: const Center(
              child: ScaleOnPress(
                child: ColoredBox(
                  color: Colors.black,
                  child: SizedBox.square(dimension: 44),
                ),
              ),
            ),
          ),
        ),
      );

  double scaleOf(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

  group('ScaleOnPress', () {
    testWidgets(
      'GIVEN the child '
      'WHEN pressed and released '
      'THEN shrinks while down and comes back',
      (tester) async {
        await pumpScale(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ScaleOnPress)),
        );
        await tester.pump();
        expect(scaleOf(tester), ScaleOnPress.pressedScale);

        await gesture.up();
        await tester.pump();
        expect(scaleOf(tester), 1);
      },
    );

    testWidgets(
      'GIVEN reduce motion '
      'WHEN pressed '
      'THEN stays at full size',
      (tester) async {
        await pumpScale(tester, reduceMotion: true);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ScaleOnPress)),
        );
        await tester.pump();
        expect(scaleOf(tester), 1);

        await gesture.up();
      },
    );
  });
}
