import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/common/widgets/status_views.dart';
import 'package:cabina/player/ai_companion/cubit/ai_companion_cubit.dart';
import 'package:cabina/player/ai_companion/models/chapter.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/ai_companion/models/transcript.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';
import 'package:cabina/player/ai_companion/views/ai_companion_sheet.dart';
import 'package:cabina/player/ai_companion/widgets/companion_footer.dart';
import 'package:cabina/player/ai_companion/widgets/header/ai_label_chip.dart';
import 'package:cabina/player/ai_companion/widgets/header/sheet_handle.dart';
import 'package:cabina/player/ai_companion/widgets/player/play_pause_circle_button.dart';
import 'package:cabina/player/ai_companion/widgets/transcript/segment_row.dart';
import 'package:cabina/player/bloc/player_bloc.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:cabina/player/models/player_position.dart';
import 'package:cabina/player/models/player_status.dart';
import 'package:cabina/player/widgets/seek_bar.dart';
import 'package:cabina/show_detail/models/episode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayerBloc extends MockBloc<PlayerEvent, PlayerState>
    implements PlayerBloc {}

class _MockAICompanionCubit extends MockCubit<AICompanionState>
    implements AICompanionCubit {}

const _args = PlayerArgs(
  episode: Episode(
    guid: 'night-shift-42',
    title: 'The last lighthouse keepers',
    audioUrl: 'https://cdn.example.com/night-shift/ep.m4a',
  ),
  podcastTitle: 'Night Shift',
  feedUrl: 'https://feeds.example.com/night-shift.xml',
);

/// 120 sentences, one every 10 s: far more than the sheet shows at once.
final List<TranscriptSegment> _segments = List.generate(
  120,
  (i) => TranscriptSegment(
    start: Duration(seconds: i * 10),
    text: 'Sentence $i about the lighthouse.',
  ),
);

final _companion = EpisodeCompanion(
  source: TranscriptSource.audio,
  segments: _segments,
  transcribedDuration: const Duration(minutes: 20),
  summary: 'Two keepers remember the last manned lighthouse.',
  chapters: const [
    Chapter(title: 'Welcome', segmentIndex: 0),
    Chapter(title: 'The storm of 1987', segmentIndex: 75),
  ],
);

final _ready = AICompanionState(
  status: AICompanionStatus.ready,
  companion: _companion,
);

PlayerState _playingAt(Duration position) => PlayerState(
  status: PlayerStatus.playing,
  position: PlayerPosition(
    position: position,
    total: const Duration(minutes: 20),
  ),
);

void main() {
  late _MockPlayerBloc playerBloc;
  late _MockAICompanionCubit companionCubit;

  setUp(() {
    playerBloc = _MockPlayerBloc();
    companionCubit = _MockAICompanionCubit();
    when(() => playerBloc.state).thenReturn(_playingAt(Duration.zero));
    when(() => companionCubit.state).thenReturn(_ready);
  });

  Future<void> pumpSheet(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme(isDark: false).toThemeData(),
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<PlayerBloc>.value(value: playerBloc),
              BlocProvider<AICompanionCubit>.value(value: companionCubit),
            ],
            child: const AICompanionSheet(args: _args),
          ),
        ),
      ),
    );
  }

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  group('AICompanionSheet', () {
    testWidgets(
      'GIVEN an error without retry '
      'THEN shows the message and no Retry',
      (tester) async {
        when(() => companionCubit.state).thenReturn(
          const AICompanionState(
            status: AICompanionStatus.error,
            errorMessage: 'This episode is too long for AI Companion',
          ),
        );

        await pumpSheet(tester);

        expect(
          find.text('This episode is too long for AI Companion'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets(
      'GIVEN an error with retry '
      'WHEN tapping Retry '
      'THEN calls retry',
      (tester) async {
        when(() => companionCubit.state).thenReturn(
          const AICompanionState(
            status: AICompanionStatus.error,
            errorMessage: 'No connection',
            canRetry: true,
          ),
        );
        when(() => companionCubit.retry()).thenAnswer((_) async {});

        await pumpSheet(tester);
        await tester.tap(find.text('Retry'));

        verify(() => companionCubit.retry()).called(1);
      },
    );

    testWidgets(
      'GIVEN loading '
      'THEN shows LoaderView, no TabBar and no AI chip',
      (tester) async {
        when(() => companionCubit.state).thenReturn(
          const AICompanionState(status: AICompanionStatus.loading),
        );

        await pumpSheet(tester);

        expect(find.byType(LoaderView), findsOneWidget);
        expect(find.byType(TabBar), findsNothing);
        expect(find.byType(AILabelChip), findsNothing);
      },
    );

    testWidgets(
      'GIVEN ready '
      'THEN shows the summary, each chapter with its time and the AI label',
      (tester) async {
        await pumpSheet(tester);

        expect(find.text(_companion.summary), findsOneWidget);
        expect(find.text('Welcome'), findsOneWidget);
        expect(find.text('0:00'), findsOneWidget);
        expect(find.text('The storm of 1987'), findsOneWidget);
        expect(find.text('12:30'), findsOneWidget);
        expect(find.text('Generated by AI'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN ready '
      'WHEN tapping a chapter and a sentence '
      'THEN adds PlayerSeeked to the start of each',
      (tester) async {
        await pumpSheet(tester);

        await tester.tap(find.text('The storm of 1987'));
        await tester.tap(find.text('Transcript'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sentence 2 about the lighthouse.'));

        verify(
          () => playerBloc.add(const PlayerSeeked(Duration(seconds: 750))),
        ).called(1);
        verify(
          () => playerBloc.add(const PlayerSeeked(Duration(seconds: 20))),
        ).called(1);
      },
    );

    testWidgets(
      'GIVEN a position far down '
      'WHEN the transcript tab opens '
      'THEN that sentence is visible and highlighted, '
      'and the highlight moves when the position crosses to the next',
      (tester) async {
        final positions = StreamController<PlayerState>();
        addTearDown(positions.close);
        whenListen(
          playerBloc,
          positions.stream,
          initialState: _playingAt(const Duration(seconds: 905)),
        );
        await pumpSheet(tester);

        await tester.tap(find.text('Transcript'));
        await tester.pumpAndSettle();

        final theme = AppTheme(isDark: false);
        const active = 'Sentence 90 about the lighthouse.';
        const next = 'Sentence 91 about the lighthouse.';
        expect(find.text(active).hitTestable(), findsOneWidget);
        expect(find.text('Sentence 0 about the lighthouse.'), findsNothing);
        expect(colorOf(tester, active), theme.primary);
        expect(colorOf(tester, next), theme.foregroundSoft);

        positions.add(_playingAt(const Duration(seconds: 911)));
        await tester.pumpAndSettle();

        expect(colorOf(tester, active), theme.foregroundSoft);
        expect(colorOf(tester, next), theme.primary);
        expect(find.text(next).hitTestable(), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN a transcript 5 min shorter than the episode '
      'THEN shows the approximate sync notice',
      (tester) async {
        when(() => playerBloc.state).thenReturn(
          const PlayerState(
            status: PlayerStatus.playing,
            position: PlayerPosition(total: Duration(minutes: 25)),
          ),
        );

        await pumpSheet(tester);

        expect(
          find.text('Sync may be approximate for this episode'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GIVEN a transcript as long as the episode '
      'THEN hides the approximate sync notice',
      (tester) async {
        await pumpSheet(tester);

        expect(find.text('Generated by AI'), findsOneWidget);
        expect(
          find.text('Sync may be approximate for this episode'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'GIVEN show '
      'WHEN the sheet opens '
      'THEN it is a surface card with 24 px top corners',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme(isDark: false).toThemeData(),
            home: MultiBlocProvider(
              providers: [
                BlocProvider<PlayerBloc>.value(value: playerBloc),
                BlocProvider<AICompanionCubit>.value(value: companionCubit),
              ],
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AICompanionSheet.show(context, _args),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
        expect(sheet.backgroundColor, AppTheme(isDark: false).surface);
        expect(
          sheet.shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        );
      },
    );

    testWidgets(
      'GIVEN ready '
      'THEN the tabs are pills: the selected one filled in foreground',
      (tester) async {
        await pumpSheet(tester);

        final theme = AppTheme(isDark: false);
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        final indicator = tabBar.indicator! as ShapeDecoration;
        expect(indicator.shape, const StadiumBorder());
        expect(indicator.color, theme.foreground);
        expect(tabBar.labelColor, theme.background);
        expect(tabBar.unselectedLabelColor, theme.foreground);
      },
    );

    testWidgets(
      'GIVEN ready '
      'THEN the AI label is a chip',
      (tester) async {
        await pumpSheet(tester);

        expect(
          find.descendant(
            of: find.byType(AILabelChip),
            matching: find.text('Generated by AI'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GIVEN the start of the episode '
      'WHEN the Transcript tab opens '
      'THEN the first sentence sits an eighth of the list down',
      (tester) async {
        await pumpSheet(tester);
        await tester.tap(find.text('Transcript'));
        await tester.pumpAndSettle();

        final list = tester.getRect(find.byType(CustomScrollView));
        final first = tester.getRect(find.byType(SegmentRow).first);
        expect(first.top - list.top, moreOrLessEquals(list.height * 0.125));
      },
    );

    testWidgets(
      'GIVEN the transcript '
      'WHEN scrolled to the end '
      'THEN an eighth of the list is left empty after the last sentence',
      (tester) async {
        await pumpSheet(tester);
        await tester.tap(find.text('Transcript'));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -10000),
        );
        await tester.pumpAndSettle();

        final list = tester.getRect(find.byType(CustomScrollView));
        final last = tester.getRect(
          find.ancestor(
            of: find.text('Sentence 119 about the lighthouse.'),
            matching: find.byType(SegmentRow),
          ),
        );
        expect(
          list.bottom - last.bottom,
          moreOrLessEquals(list.height * 0.125),
        );
      },
    );

    group('full height', () {
      /// Opens the sheet through [AICompanionSheet.show], as the player
      /// does, so Collapse can be told apart from closing the modal.
      Future<void> openSheet(
        WidgetTester tester, {
        bool disableAnimations = false,
      }) async {
        tester.view
          ..physicalSize = const Size(1170, 2532)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme(isDark: false).toThemeData(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: child!,
            ),
            home: MultiBlocProvider(
              providers: [
                BlocProvider<PlayerBloc>.value(value: playerBloc),
                BlocProvider<AICompanionCubit>.value(value: companionCubit),
              ],
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AICompanionSheet.show(context, _args),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
      }

      Future<void> expand(WidgetTester tester) async {
        await tester.drag(find.text('AI Companion'), const Offset(0, -600));
        await tester.pumpAndSettle();
      }

      testWidgets(
        'GIVEN the sheet at half height '
        'THEN shows the handle, the title with Full screen, '
        'and only the AI chip at the bottom left, 8 px below the content',
        (tester) async {
          await openSheet(tester);

          expect(find.byType(SheetHandle), findsOneWidget);
          expect(find.text('AI Companion'), findsOneWidget);
          expect(find.byTooltip('Full screen'), findsOneWidget);
          final footer = find.byType(CompanionFooter);
          expect(
            find.descendant(of: footer, matching: find.byType(AILabelChip)),
            findsOneWidget,
          );
          expect(find.byType(SeekBar), findsNothing);
          expect(find.byType(PlayPauseCircleButton), findsNothing);

          final sheet = tester.getRect(find.byType(AICompanionSheet));
          final body = tester.getRect(find.byType(TabBarView));
          final chip = tester.getRect(find.byType(AILabelChip));
          expect(chip.left, moreOrLessEquals(sheet.left + 16));
          // The footer's 4 px top padding plus the chip's 8 px.
          expect(chip.top, moreOrLessEquals(body.bottom + 12));
        },
      );

      testWidgets(
        'GIVEN the sheet at half height '
        'WHEN Full screen is tapped '
        'THEN the sheet goes to full height',
        (tester) async {
          await openSheet(tester);

          await tester.tap(find.byTooltip('Full screen'));
          await tester.pumpAndSettle();

          expect(find.byTooltip('Collapse'), findsOneWidget);
          expect(find.text(_args.episode.title), findsOneWidget);
          expect(find.byType(SeekBar), findsOneWidget);
        },
      );

      testWidgets(
        'GIVEN the sheet at half height and disableAnimations '
        'WHEN Full screen is tapped '
        'THEN the sheet is at full height after a single frame',
        (tester) async {
          await openSheet(tester, disableAnimations: true);

          await tester.tap(find.byTooltip('Full screen'));
          await tester.pump();

          expect(find.byTooltip('Collapse'), findsOneWidget);
          expect(find.byType(SeekBar), findsOneWidget);
        },
      );

      testWidgets(
        'GIVEN the sheet '
        'WHEN dragged to full height '
        'THEN the episode is on top and the player controls at the bottom',
        (tester) async {
          await openSheet(tester);
          await expand(tester);

          expect(find.text(_args.episode.title), findsOneWidget);
          expect(find.text(_args.podcastTitle), findsOneWidget);
          expect(find.text('AI Companion'), findsNothing);
          expect(find.byType(SheetHandle), findsNothing);
          final footer = find.byType(CompanionFooter);
          expect(
            find.descendant(of: footer, matching: find.byType(SeekBar)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: footer,
              matching: find.byType(PlayPauseCircleButton),
            ),
            findsOneWidget,
          );
          expect(find.byType(AILabelChip), findsOneWidget);
          expect(
            find.descendant(of: footer, matching: find.byType(AILabelChip)),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'GIVEN full height '
        'THEN play/pause is centered and the chip sits on the left',
        (tester) async {
          await openSheet(tester);
          await expand(tester);

          final sheet = tester.getRect(find.byType(AICompanionSheet));
          final play = tester.getRect(find.byType(PlayPauseCircleButton));
          final chip = tester.getRect(find.byType(AILabelChip));
          expect(play.center.dx, moreOrLessEquals(sheet.center.dx));
          expect(chip.left, moreOrLessEquals(sheet.left + 16));
        },
      );

      testWidgets(
        'GIVEN full height '
        'WHEN the footer play/pause is tapped '
        'THEN adds PlayerPlayPauseToggled',
        (tester) async {
          await openSheet(tester);
          await expand(tester);

          await tester.tap(find.byTooltip('Pause'));

          verify(
            () => playerBloc.add(const PlayerPlayPauseToggled()),
          ).called(1);
        },
      );

      testWidgets(
        'GIVEN full height '
        'WHEN Collapse is tapped '
        'THEN the sheet stays open at half height',
        (tester) async {
          await openSheet(tester);
          await expand(tester);

          await tester.tap(find.byTooltip('Collapse'));
          await tester.pumpAndSettle();

          expect(find.byType(AICompanionSheet), findsOneWidget);
          expect(find.byType(SheetHandle), findsOneWidget);
          expect(find.text('AI Companion'), findsOneWidget);
          expect(find.byType(SeekBar), findsNothing);
        },
      );

      testWidgets(
        'GIVEN full height and disableAnimations '
        'WHEN Collapse is tapped '
        'THEN the sheet is at half height after a single frame',
        (tester) async {
          await openSheet(tester, disableAnimations: true);
          await expand(tester);

          await tester.tap(find.byTooltip('Collapse'));
          await tester.pump();

          expect(find.byType(SheetHandle), findsOneWidget);
          expect(find.byType(SeekBar), findsNothing);
        },
      );
    });
  });
}
