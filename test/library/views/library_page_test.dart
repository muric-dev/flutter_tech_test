import 'package:bloc_test/bloc_test.dart';
import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/common/widgets/status_views.dart';
import 'package:cabina/discover/models/podcast.dart';
import 'package:cabina/library/cubit/library_cubit.dart';
import 'package:cabina/library/models/subscribed_podcast.dart';
import 'package:cabina/library/views/library_page.dart';
import 'package:cabina/show_detail/views/show_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockLibraryCubit extends MockCubit<LibraryState>
    implements LibraryCubit {}

void main() {
  const podcast = SubscribedPodcast(
    id: 1,
    title: 'Reply All',
    author: 'Gimlet',
  );

  const withFeed = SubscribedPodcast(
    id: 2,
    title: 'Serial',
    author: 'This American Life',
    feedUrl: 'https://example.com/serial.xml',
    artworkUrl: 'http://serial.png',
  );

  late _MockLibraryCubit cubit;

  setUp(() {
    cubit = _MockLibraryCubit();
    when(() => cubit.state).thenReturn(const LibraryState());
    when(() => cubit.load()).thenAnswer((_) async {});
    when(() => cubit.unsubscribe(any())).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme(isDark: false).toThemeData(),
      home: BlocProvider<LibraryCubit>.value(
        value: cubit,
        child: const LibraryPage(),
      ),
    ),
  );

  /// Pumps the page under a real [GoRouter] whose detail route records the
  /// pushed [Podcast] instead of building [ShowDetailPage].
  Future<List<Podcast>> pumpRouted(WidgetTester tester) async {
    final pushed = <Podcast>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<LibraryCubit>.value(
            value: cubit,
            child: const LibraryPage(),
          ),
        ),
        GoRoute(
          path: ShowDetailPage.routePath,
          name: ShowDetailPage.routeName,
          builder: (_, state) {
            pushed.add(state.extra! as Podcast);
            return const SizedBox();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme(isDark: false).toThemeData(),
        routerConfig: router,
      ),
    );
    return pushed;
  }

  group('LibraryPage', () {
    testWidgets('WHEN pumped '
        'THEN loads the library', (tester) async {
      await pumpPage(tester);

      verify(() => cubit.load()).called(1);
    });

    testWidgets('GIVEN loading '
        'THEN LoaderView shows', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn(const LibraryState(status: LibraryStatus.loading));

      await pumpPage(tester);

      expect(find.byType(LoaderView), findsOneWidget);
    });

    testWidgets('GIVEN an error '
        'WHEN Retry is tapped '
        'THEN loads again', (tester) async {
      when(() => cubit.state).thenReturn(
        const LibraryState(
          status: LibraryStatus.error,
          errorMessage: 'offline',
        ),
      );

      await pumpPage(tester);
      await tester.tap(find.text('Retry'));

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      verify(() => cubit.load()).called(2);
    });

    testWidgets('GIVEN no podcasts '
        'THEN EmptyView shows', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn(const LibraryState(status: LibraryStatus.ready));

      await pumpPage(tester);

      expect(find.byType(EmptyView), findsOneWidget);
    });

    testWidgets('GIVEN podcasts '
        'THEN their title and author show', (tester) async {
      when(() => cubit.state).thenReturn(
        const LibraryState(status: LibraryStatus.ready, podcasts: [podcast]),
      );

      await pumpPage(tester);

      expect(find.text('Reply All'), findsOneWidget);
      expect(find.text('Gimlet'), findsOneWidget);
    });

    testWidgets('GIVEN podcasts '
        'WHEN Unsubscribe is tapped '
        'THEN unsubscribes that podcast', (tester) async {
      when(() => cubit.state).thenReturn(
        const LibraryState(status: LibraryStatus.ready, podcasts: [podcast]),
      );

      await pumpPage(tester);
      await tester.tap(find.byTooltip('Unsubscribe'));

      verify(() => cubit.unsubscribe(podcast.id)).called(1);
    });

    testWidgets('GIVEN an item with feedUrl '
        'WHEN it is tapped '
        'THEN the detail is pushed with it', (tester) async {
      when(() => cubit.state).thenReturn(
        const LibraryState(status: LibraryStatus.ready, podcasts: [withFeed]),
      );

      final pushed = await pumpRouted(tester);
      await tester.tap(find.text('Serial'));
      await tester.pumpAndSettle();

      expect(pushed, const [
        Podcast(
          id: 2,
          title: 'Serial',
          author: 'This American Life',
          feedUrl: 'https://example.com/serial.xml',
          artworkUrl: 'http://serial.png',
        ),
      ]);
    });

    testWidgets('GIVEN an item saved without feedUrl '
        'WHEN it is tapped '
        'THEN the detail is pushed right away with an empty feedUrl', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const LibraryState(status: LibraryStatus.ready, podcasts: [podcast]),
      );

      final pushed = await pumpRouted(tester);
      await tester.tap(find.text('Reply All'));
      await tester.pumpAndSettle();

      expect(pushed, const [
        Podcast(id: 1, title: 'Reply All', author: 'Gimlet', feedUrl: ''),
      ]);
    });

    testWidgets('GIVEN ready '
        'WHEN an errorMessage is emitted '
        'THEN a SnackBar shows it', (tester) async {
      const ready = LibraryState(
        status: LibraryStatus.ready,
        podcasts: [podcast],
      );
      whenListen(
        cubit,
        Stream.value(
          const LibraryState(
            status: LibraryStatus.ready,
            podcasts: [podcast],
            errorMessage: 'Could not save your changes',
          ),
        ),
        initialState: ready,
      );

      await pumpPage(tester);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Could not save your changes'),
        ),
        findsOneWidget,
      );
    });
  });
}
