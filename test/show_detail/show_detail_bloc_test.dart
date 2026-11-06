import 'package:bloc_test/bloc_test.dart';
import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/discover/models/podcast.dart';
import 'package:cabina/show_detail/bloc/show_detail_bloc.dart';
import 'package:cabina/show_detail/data/show_detail_repository.dart';
import 'package:cabina/show_detail/models/podcast_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ShowDetailRepository {}

void main() {
  late _MockRepository repository;

  const podcast = Podcast(
    id: 1,
    title: 'Historias del mas aca',
    author: 'Leyendas Legendarias',
    feedUrl: 'https://example.com/feed.xml',
  );
  const detail = PodcastDetail(
    podcastId: 1,
    title: 'Historias del mas aca',
    author: 'Leyendas Legendarias',
    feedUrl: 'https://example.com/feed.xml',
    episodes: [],
  );

  setUpAll(() => registerFallbackValue(podcast));
  setUp(() => repository = _MockRepository());

  ShowDetailBloc buildBloc() => ShowDetailBloc(repository: repository);

  group('ShowDetailBloc', () {
    blocTest<ShowDetailBloc, ShowDetailState>(
      'GIVEN a podcast and the feed loads successfully '
      'WHEN ShowDetailRequested is added '
      'THEN emits [loading, ready] with the podcast detail '
      'and loads the detail only once',
      build: () {
        when(
          () => repository.loadDetail(any()),
        ).thenAnswer((_) async => detail);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ShowDetailRequested(podcast)),
      expect: () => const [
        ShowDetailState(status: ShowDetailStatus.loading),
        ShowDetailState(status: ShowDetailStatus.ready, detail: detail),
      ],
      verify: (_) {
        verify(() => repository.loadDetail(podcast)).called(1);
      },
    );

    blocTest<ShowDetailBloc, ShowDetailState>(
      'GIVEN a repository that throws a CabinaException '
      'WHEN ShowDetailRequested is added '
      'THEN emits [loading, error] with the exception message',
      build: () {
        when(
          () => repository.loadDetail(any()),
        ).thenThrow(const NetworkException('offline'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ShowDetailRequested(podcast)),
      errors: () => [isA<CabinaException>()],
      expect: () => const [
        ShowDetailState(status: ShowDetailStatus.loading),
        ShowDetailState(
          status: ShowDetailStatus.error,
          errorMessage: 'offline',
        ),
      ],
    );

    blocTest<ShowDetailBloc, ShowDetailState>(
      'GIVEN the repository throws a StateError '
      'WHEN ShowDetailRequested is added '
      'THEN emits error with CabinaException.fallbackMessage',
      build: () {
        when(
          () => repository.loadDetail(any()),
        ).thenThrow(StateError('unexpected'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ShowDetailRequested(podcast)),
      errors: () => [isA<StateError>()],
      expect: () => const [
        ShowDetailState(status: ShowDetailStatus.loading),
        ShowDetailState(
          status: ShowDetailStatus.error,
          errorMessage: CabinaException.fallbackMessage,
        ),
      ],
    );

    blocTest<ShowDetailBloc, ShowDetailState>(
      'GIVEN a previous error state and a feed that now loads successfully '
      'WHEN ShowDetailRequested is added again '
      'THEN emits [loading, ready] and clears the previous error message',
      build: () {
        when(
          () => repository.loadDetail(any()),
        ).thenAnswer((_) async => detail);
        return buildBloc();
      },
      // Initial state of the bloc: applied before act and not part of expect.
      seed: () => const ShowDetailState(
        status: ShowDetailStatus.error,
        errorMessage: 'offline',
      ),
      act: (bloc) => bloc.add(const ShowDetailRequested(podcast)),
      expect: () => const [
        ShowDetailState(status: ShowDetailStatus.loading),
        ShowDetailState(status: ShowDetailStatus.ready, detail: detail),
      ],
    );
  });
}
