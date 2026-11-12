import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/common/widgets/poster_image.dart';
import 'package:cabina/common/widgets/status_views.dart';
import 'package:cabina/player/ai_companion/widgets/buttons/ai_companion_button.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:cabina/player/models/player_position.dart';
import 'package:cabina/player/models/player_status.dart';
import 'package:cabina/player/views/player_page.dart';
import 'package:cabina/player/widgets/player_controls.dart';
import 'package:cabina/show_detail/models/episode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayerBloc extends MockBloc<PlayerEvent, PlayerState>
    implements PlayerBloc {}

void main() {
  const args = PlayerArgs(
    episode: Episode(
      guid: 'guid-1',
      title: 'Episode 1',
      audioUrl: 'https://example.com/audio.mp3',
      duration: Duration(minutes: 5),
    ),
    podcastTitle: 'Podcast Title',
    feedUrl: 'https://example.com/feed.xml',
  );

  late _MockPlayerBloc bloc;

  setUp(() {
    bloc = _MockPlayerBloc();
    when(() => bloc.state).thenReturn(
      const PlayerState(status: PlayerStatus.paused),
    );
  });

  /// Pumps the page on a phone-sized view: the square artwork overflows the
  /// default 800x600 test surface.
  Future<void> pumpPage(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme(isDark: false).toThemeData(),
        home: BlocProvider<PlayerBloc>.value(
          value: bloc,
          child: const PlayerPage(args: args),
        ),
      ),
    );
  }

  group('PlayerPage', () {
    testWidgets(
      'GIVEN the page opens '
      'THEN adds PlayerOpened with its args',
      (tester) async {
        await pumpPage(tester);

        verify(() => bloc.add(const PlayerOpened(args))).called(1);
      },
    );

    testWidgets(
      'GIVEN a paused episode '
      'THEN shows the episode and podcast titles',
      (tester) async {
        await pumpPage(tester);

        expect(find.text('Episode 1'), findsOneWidget);
        expect(find.text('Podcast Title'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN error status '
      'THEN shows the ErrorView with the message',
      (tester) async {
        when(() => bloc.state).thenReturn(
          const PlayerState(
            status: PlayerStatus.error,
            errorMessage: 'Could not load audio',
          ),
        );

        await pumpPage(tester);

        expect(find.byType(ErrorView), findsOneWidget);
        expect(find.text('Could not load audio'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN a loading episode '
      'WHEN opening fails '
      'THEN replaces the player with the ErrorView',
      (tester) async {
        whenListen(
          bloc,
          Stream.value(
            const PlayerState(
              status: PlayerStatus.error,
              errorMessage: 'Could not load audio',
            ),
          ),
          initialState: const PlayerState(status: PlayerStatus.loading),
        );
        await pumpPage(tester);
        expect(find.byType(ErrorView), findsNothing);

        await tester.pump();

        expect(find.byType(ErrorView), findsOneWidget);
        expect(find.text('Could not load audio'), findsOneWidget);
        expect(find.byType(PlayerControls), findsNothing);
      },
    );

    testWidgets(
      'GIVEN a playing episode '
      'WHEN only the position changes '
      'THEN rebuilds the seek bar and not the header or the controls',
      (tester) async {
        const playing = PlayerState(
          status: PlayerStatus.playing,
          position: PlayerPosition(total: Duration(minutes: 5)),
        );
        final states = StreamController<PlayerState>();
        addTearDown(states.close);
        whenListen(bloc, states.stream, initialState: playing);
        await pumpPage(tester);

        final controlsRow = find.descendant(
          of: find.byType(PlayerControls),
          matching: find.byType(Row),
        );
        final posterBefore = tester.widget(find.byType(PosterImage));
        final rowBefore = tester.widget(controlsRow.first);
        final sliderBefore = tester.widget(find.byType(Slider));

        states.add(
          const PlayerState(
            status: PlayerStatus.playing,
            position: PlayerPosition(
              position: Duration(seconds: 30),
              total: Duration(minutes: 5),
            ),
          ),
        );
        await tester.pump();

        expect(tester.widget(find.byType(PosterImage)), same(posterBefore));
        expect(tester.widget(controlsRow.first), same(rowBefore));
        expect(tester.widget(find.byType(Slider)), isNot(same(sliderBefore)));
        expect(find.text('0:30'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN a ready player '
      'THEN shows the AI Companion button below the controls',
      (tester) async {
        await pumpPage(tester);

        final button = find.byType(AICompanionButton);
        expect(button, findsOneWidget);
        expect(
          tester.getTopLeft(button).dy,
          greaterThan(tester.getBottomLeft(find.byType(PlayerControls)).dy),
        );
      },
    );

    testWidgets(
      'GIVEN a playing episode '
      'WHEN an action error arrives '
      'THEN shows a SnackBar and keeps the controls',
      (tester) async {
        const playing = PlayerState(status: PlayerStatus.playing);
        whenListen(
          bloc,
          Stream.value(playing.copyWith(errorMessage: 'Could not seek')),
          initialState: playing,
        );

        await pumpPage(tester);
        await tester.pump();

        expect(find.widgetWithText(SnackBar, 'Could not seek'), findsOneWidget);
        expect(find.byType(PlayerControls), findsOneWidget);
        expect(find.byType(ErrorView), findsNothing);
      },
    );
  });
}
