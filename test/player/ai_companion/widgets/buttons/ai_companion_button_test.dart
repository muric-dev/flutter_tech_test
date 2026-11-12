import 'package:bloc_test/bloc_test.dart';
import 'package:cabina/common/network/api_client.dart';
import 'package:cabina/common/storage/local_storage.dart';
import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/player/ai_companion/views/ai_companion_sheet.dart';
import 'package:cabina/player/ai_companion/widgets/buttons/ai_companion_button.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:cabina/player/models/player_status.dart';
import 'package:cabina/show_detail/models/episode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayerBloc extends MockBloc<PlayerEvent, PlayerState>
    implements PlayerBloc {}

class _MockApiClient extends Mock implements ApiClient {}

class _MockLocalStorage extends Mock implements LocalStorage {}

const _args = PlayerArgs(
  episode: Episode(
    guid: 'night-shift-42',
    title: 'The last lighthouse keepers',
    audioUrl: 'https://cdn.example.com/night-shift/ep.m4a',
  ),
  podcastTitle: 'Night Shift',
  feedUrl: 'https://feeds.example.com/night-shift.xml',
);

void main() {
  late _MockPlayerBloc playerBloc;
  late _MockApiClient apiClient;
  late _MockLocalStorage localStorage;

  setUp(() {
    playerBloc = _MockPlayerBloc();
    apiClient = _MockApiClient();
    localStorage = _MockLocalStorage();
    when(
      () => playerBloc.state,
    ).thenReturn(const PlayerState(status: PlayerStatus.paused));
    when(() => localStorage.read(any())).thenAnswer((_) async => null);
  });

  Future<void> pumpButton(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme(isDark: false).toThemeData(),
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ApiClient>.value(value: apiClient),
          RepositoryProvider<LocalStorage>.value(value: localStorage),
        ],
        child: BlocProvider<PlayerBloc>.value(
          value: playerBloc,
          child: const Scaffold(
            body: Center(child: AICompanionButton(args: _args)),
          ),
        ),
      ),
    ),
  );

  group('AICompanionButton', () {
    testWidgets(
      'GIVEN the player is open '
      'WHEN the button is not tapped '
      'THEN nothing is read or requested',
      (tester) async {
        await pumpButton(tester);

        expect(find.text('AI Companion'), findsOneWidget);
        verifyNever(() => localStorage.read(any()));
        verifyZeroInteractions(apiClient);
      },
    );

    // Tests run without OPENAI_API_KEY, so the real cubit ends in the
    // missing-key error after the cache lookup, with no request.
    testWidgets(
      'GIVEN the button '
      'WHEN tapped '
      'THEN starts the preparation and opens the sheet',
      (tester) async {
        await pumpButton(tester);

        await tester.tap(find.text('AI Companion'));
        await tester.pumpAndSettle();

        expect(find.byType(AICompanionSheet), findsOneWidget);
        expect(
          find.text("AI Companion isn't available right now"),
          findsOneWidget,
        );
        verify(() => localStorage.read(any())).called(1);
        verifyZeroInteractions(apiClient);
      },
    );
    for (final status in [PlayerStatus.idle, PlayerStatus.loading]) {
      testWidgets(
        'GIVEN the episode is still opening ($status) '
        'WHEN the button is tapped '
        'THEN it is disabled and nothing opens',
        (tester) async {
          when(() => playerBloc.state).thenReturn(PlayerState(status: status));
          await pumpButton(tester);

          await tester.tap(find.text('AI Companion'));
          await tester.pumpAndSettle();

          final button = tester.widget<ButtonStyleButton>(
            find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
          );
          expect(button.onPressed, isNull);
          expect(find.byType(AICompanionSheet), findsNothing);
          verifyNever(() => localStorage.read(any()));
        },
      );
    }

    testWidgets(
      'GIVEN the episode is opening '
      'WHEN it finishes opening '
      'THEN the button is enabled',
      (tester) async {
        whenListen(
          playerBloc,
          Stream.value(const PlayerState(status: PlayerStatus.playing)),
          initialState: const PlayerState(status: PlayerStatus.loading),
        );
        await pumpButton(tester);
        await tester.pump();

        final button = tester.widget<ButtonStyleButton>(
          find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'GIVEN the button '
      'THEN it is a pill tinted with primary',
      (tester) async {
        await pumpButton(tester);

        final theme = AppTheme(isDark: false);
        final style = tester
            .widget<ButtonStyleButton>(
              find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
            )
            .style!;
        expect(style.shape!.resolve({}), const StadiumBorder());
        expect(
          style.backgroundColor!.resolve({}),
          theme.primary.withValues(alpha: 0.15),
        );
        expect(style.foregroundColor!.resolve({}), theme.primary);
      },
    );
  });
}
