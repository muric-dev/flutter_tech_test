import 'package:cabina/common/services/itunes_search_service.dart';
import 'package:cabina/discover/models/podcast.dart';
import 'package:cabina/show_detail/data/parsers/rss_feed_parser.dart';
import 'package:cabina/show_detail/data/services/rss_feed_service.dart';
import 'package:cabina/show_detail/models/podcast_detail.dart';

/// Loads a show's detail from its RSS feed.
class ShowDetailRepository {
  ShowDetailRepository({
    required RssFeedService feedService,
    required RssFeedParser feedParser,
    required ItunesSearchService searchService,
  }) : _feedService = feedService,
       _feedParser = feedParser,
       _searchService = searchService;

  final RssFeedService _feedService;
  final RssFeedParser _feedParser;
  final ItunesSearchService _searchService;

  /// An empty [Podcast.feedUrl] (a library subscription saved before feeds
  /// were stored) is looked up on iTunes by id first, so the detail's loader
  /// covers both requests.
  Future<PodcastDetail> loadDetail(Podcast podcast) async {
    final source = podcast.feedUrl.isEmpty
        ? await _searchService.lookupById(podcast.id)
        : podcast;
    final xml = await _feedService.fetchFeed(source.feedUrl);
    // If detail is too big, it would be better to run this into an isolate.
    return _feedParser.parse(xml, source);
  }
}
