import 'package:bloc_test/bloc_test.dart';
import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/widgets/player/play_pause_circle_button.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:cabina/player/models/player_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayerBloc extends MockBloc<PlayerEvent, PlayerState>
    implements PlayerBloc {}

void main() {
  late _MockPlayerBloc playerBloc;

  setUp(() => playerBloc = _MockPlayerBloc());

  Future<void> pumpButton(WidgetTester tester, PlayerStatus status) {
    when(() => playerBloc.state).thenReturn(PlayerState(status: status));
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme(isDark: false).toThemeData(),
        home: Scaffold(
          body: BlocProvider<PlayerBloc>.value(
            value: playerBloc,
            child: const PlayPauseCircleButton(),
          ),
        ),
      ),
    );
  }

  group('PlayPauseCircleButton', () {
    testWidgets('GIVEN playing THEN shows Pause', (tester) async {
      await pumpButton(tester, PlayerStatus.playing);

      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('GIVEN paused THEN shows Play', (tester) async {
      await pumpButton(tester, PlayerStatus.paused);

      expect(find.byTooltip('Play'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets(
      'GIVEN the button '
      'WHEN tapped '
      'THEN adds PlayerPlayPauseToggled',
      (tester) async {
        await pumpButton(tester, PlayerStatus.paused);

        await tester.tap(find.byType(PlayPauseCircleButton));

        verify(
          () => playerBloc.add(const PlayerPlayPauseToggled()),
        ).called(1);
      },
    );
  });
}
