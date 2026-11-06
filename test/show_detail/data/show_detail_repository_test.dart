import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/common/services/itunes_search_service.dart';
import 'package:cabina/discover/models/podcast.dart';
import 'package:cabina/show_detail/data/parsers/rss_feed_parser.dart';
import 'package:cabina/show_detail/data/services/rss_feed_service.dart';
import 'package:cabina/show_detail/data/show_detail_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRssFeedService extends Mock implements RssFeedService {}

class _MockItunesSearchService extends Mock implements ItunesSearchService {}

void main() {
  const feedUrl = 'https://example.com/feed.xml';
  const xml = '''
<rss><channel><title>Feed</title>
  <item><title>Ep 1</title><enclosure url="https://example.com/1.mp3"/></item>
</channel></rss>''';

  const podcast = Podcast(
    id: 1,
    title: 'Reply All',
    author: 'Gimlet',
    feedUrl: feedUrl,
  );

  late _MockRssFeedService feedService;
  late _MockItunesSearchService searchService;
  late ShowDetailRepository repository;

  setUp(() {
    feedService = _MockRssFeedService();
    searchService = _MockItunesSearchService();
    repository = ShowDetailRepository(
      feedService: feedService,
      feedParser: const RssFeedParser(),
      searchService: searchService,
    );
    when(() => feedService.fetchFeed(feedUrl)).thenAnswer((_) async => xml);
  });

  group('ShowDetailRepository.loadDetail', () {
    test('GIVEN a podcast with feedUrl '
        'WHEN loadDetail '
        'THEN parses that feed without a lookup', () async {
      final detail = await repository.loadDetail(podcast);

      expect(detail.feedUrl, feedUrl);
      expect(detail.episodes.single.title, 'Ep 1');
      verifyNever(() => searchService.lookupById(any()));
    });

    test('GIVEN a podcast with an empty feedUrl '
        'WHEN loadDetail '
        'THEN looks it up by id and parses the feed it returns', () async {
      when(
        () => searchService.lookupById(podcast.id),
      ).thenAnswer((_) async => podcast);

      final detail = await repository.loadDetail(
        const Podcast(id: 1, title: 'Reply All', author: 'Gimlet', feedUrl: ''),
      );

      expect(detail.feedUrl, feedUrl);
      expect(detail.episodes.single.title, 'Ep 1');
    });

    test('GIVEN an empty feedUrl and the lookup throws '
        'WHEN loadDetail '
        'THEN the error propagates and no feed is fetched', () async {
      when(
        () => searchService.lookupById(podcast.id),
      ).thenThrow(const ApiException('Podcast not found'));

      await expectLater(
        repository.loadDetail(
          const Podcast(
            id: 1,
            title: 'Reply All',
            author: 'Gimlet',
            feedUrl: '',
          ),
        ),
        throwsA(isA<ApiException>()),
      );
      verifyNever(() => feedService.fetchFeed(any()));
    });
  });
}
