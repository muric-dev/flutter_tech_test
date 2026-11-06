import 'package:bloc_test/bloc_test.dart';
import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/discover/models/podcast.dart';
import 'package:cabina/library/cubit/library_cubit.dart';
import 'package:cabina/library/models/subscribed_podcast.dart';
import 'package:cabina/show_detail/bloc/show_detail_bloc.dart';
import 'package:cabina/show_detail/models/podcast_detail.dart';
import 'package:cabina/show_detail/views/show_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockShowDetailBloc extends MockBloc<ShowDetailEvent, ShowDetailState>
    implements ShowDetailBloc {}

class _MockLibraryCubit extends MockCubit<LibraryState>
    implements LibraryCubit {}

void main() {
  const resolvedFeed = 'https://example.com/reply.xml';

  late _MockShowDetailBloc bloc;
  late _MockLibraryCubit libraryCubit;

  setUp(() {
    bloc = _MockShowDetailBloc();
    libraryCubit = _MockLibraryCubit();
    when(() => bloc.state).thenReturn(
      const ShowDetailState(
        status: ShowDetailStatus.ready,
        detail: PodcastDetail(
          podcastId: 1,
          title: 'Reply All',
          author: 'Gimlet',
          feedUrl: resolvedFeed,
          episodes: [],
        ),
      ),
    );
    when(
      () => libraryCubit.state,
    ).thenReturn(const LibraryState(status: LibraryStatus.ready));
    when(() => libraryCubit.subscribe(any())).thenAnswer((_) async {});
  });

  setUpAll(
    () => registerFallbackValue(
      const SubscribedPodcast(id: 0, title: 'x', author: 'x'),
    ),
  );

  testWidgets('GIVEN a podcast opened with an empty feedUrl '
      'WHEN Subscribe is tapped '
      'THEN it subscribes with the feedUrl the detail loaded', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme(isDark: false).toThemeData(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ShowDetailBloc>.value(value: bloc),
            BlocProvider<LibraryCubit>.value(value: libraryCubit),
          ],
          child: const ShowDetailPage(
            podcast: Podcast(
              id: 1,
              title: 'Reply All',
              author: 'Gimlet',
              feedUrl: '',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Subscribe'));

    verify(
      () => libraryCubit.subscribe(
        const SubscribedPodcast(
          id: 1,
          title: 'Reply All',
          author: 'Gimlet',
          feedUrl: resolvedFeed,
        ),
      ),
    ).called(1);
  });
}
