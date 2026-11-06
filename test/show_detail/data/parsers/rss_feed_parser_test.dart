import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/discover/models/podcast.dart';
import 'package:cabina/show_detail/data/parsers/rss_feed_parser.dart';
import 'package:cabina/show_detail/models/episode.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal RSS item. Pass `null` to omit a tag entirely.
///
/// [title] and [enclosure] replace the default tags; pass `''` to omit them.
String _item({
  required String guid,
  String? duration,
  String? pubDate,
  String? title,
  String? enclosure,
}) =>
    '''
<item>
  <guid>$guid</guid>
  ${title ?? '<title>Episode $guid</title>'}
  ${enclosure ?? '<enclosure url="https://example.com/$guid.mp3" type="audio/mpeg"/>'}
  ${duration == null ? '' : '<itunes:duration>$duration</itunes:duration>'}
  ${pubDate == null ? '' : '<pubDate>$pubDate</pubDate>'}
</item>''';

String _feed(List<String> items) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Historias del mas aca</title>
    <description>Un podcast de comedia donde cada semana exploramos...</description>
    ${items.join('\n')}
  </channel>
</rss>''';

void main() {
  const parser = RssFeedParser();

  const podcast = Podcast(
    id: 1,
    title: 'Historias del mas aca',
    author: 'Leyendas Legendarias',
    feedUrl: 'https://example.com/feed.xml',
  );

  /// Parses a feed with a single item and returns that episode.
  Episode parseSingle({String? duration, String? pubDate}) {
    final xml = _feed([
      _item(guid: 'ep', duration: duration, pubDate: pubDate),
    ]);
    return parser.parse(xml, podcast).episodes.single;
  }

  group('RssFeedParser', () {
    test('GIVEN a feed '
        'WHEN it is parsed '
        'THEN the detail carries the podcast data and the channel '
        'description', () {
      final detail = parser.parse(_feed([_item(guid: 'ep')]), podcast);

      expect(detail.podcastId, podcast.id);
      expect(detail.title, podcast.title);
      expect(detail.author, podcast.author);
      expect(detail.feedUrl, podcast.feedUrl);
      expect(
        detail.descriptionHtml,
        'Un podcast de comedia donde cada semana exploramos...',
      );
    });

    test('GIVEN input that is not XML '
        'WHEN it is parsed '
        'THEN a FeedParseException is thrown', () {
      expect(
        () => parser.parse('not xml <', podcast),
        throwsA(isA<FeedParseException>()),
      );
    });

    test('GIVEN valid XML without a <channel> '
        'WHEN it is parsed '
        'THEN a FeedParseException is thrown', () {
      expect(
        () => parser.parse('<rss version="2.0"></rss>', podcast),
        throwsA(isA<FeedParseException>()),
      );
    });
  });

  group('RssFeedParser title validation', () {
    test('GIVEN an item with <title> and <itunes:title> '
        'WHEN the feed is parsed '
        'THEN <title> is used', () {
      final detail = parser.parse(
        _feed([
          _item(
            guid: 'ep',
            title: '''
<title>RSS title</title>
<itunes:title>iTunes title</itunes:title>''',
          ),
        ]),
        podcast,
      );

      expect(detail.episodes.single.title, 'RSS title');
    });

    test('GIVEN an item with only <itunes:title> '
        'WHEN the feed is parsed '
        'THEN <itunes:title> is used', () {
      final detail = parser.parse(
        _feed([
          _item(guid: 'ep', title: '<itunes:title>iTunes title</itunes:title>'),
        ]),
        podcast,
      );

      expect(detail.episodes.single.title, 'iTunes title');
    });

    const missingTitles = {
      'no title': '',
      'a blank title': '<title>  </title>',
    };

    for (final MapEntry(key: description, value: title)
        in missingTitles.entries) {
      test('GIVEN one item with $description among valid items '
          'WHEN the feed is parsed '
          'THEN only that item is skipped', () {
        final detail = parser.parse(
          _feed([
            _item(guid: 'good'),
            _item(guid: 'broken', title: title),
          ]),
          podcast,
        );

        expect(detail.episodes.map((e) => e.guid), ['good']);
      });
    }
  });

  group('RssFeedParser enclosure validation', () {
    const brokenEnclosures = {
      'no enclosure': '',
      'an enclosure without url': '<enclosure type="audio/mpeg"/>',
      'an enclosure with an empty url':
          '<enclosure url="  " type="audio/mpeg"/>',
    };

    for (final MapEntry(key: description, value: enclosure)
        in brokenEnclosures.entries) {
      test('GIVEN one item with $description among valid items '
          'WHEN the feed is parsed '
          'THEN only that item is skipped', () {
        final detail = parser.parse(
          _feed([
            _item(guid: 'good'),
            _item(guid: 'broken', enclosure: enclosure),
          ]),
          podcast,
        );

        expect(detail.episodes.map((e) => e.guid), ['good']);
      });
    }
  });

  group('RssFeedParser itunes:duration parsing', () {
    test('GIVEN a HH:MM:SS duration '
        'WHEN the feed is parsed '
        'THEN the duration has hours, minutes and seconds', () {
      final episode = parseSingle(duration: '01:02:03');

      expect(
        episode.duration,
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('GIVEN an item without itunes:duration '
        'WHEN the feed is parsed '
        'THEN the duration is null (unknown), not zero', () {
      final episode = parseSingle();

      expect(episode.duration, isNull);
    });

    test('GIVEN one item with a malformed duration among valid items '
        'WHEN the feed is parsed '
        'THEN the feed still loads and only that duration is null', () {
      final detail = parser.parse(
        _feed([
          _item(guid: 'good', duration: '10:00'),
          _item(guid: 'bad', duration: 'not-a-duration'),
        ]),
        podcast,
      );
      final byGuid = {for (final e in detail.episodes) e.guid: e};

      expect(byGuid['good']?.duration, const Duration(minutes: 10));
      expect(byGuid['bad']?.duration, isNull);
    });
  });

  group('RssFeedParser pubDate parsing', () {
    test('GIVEN an RFC 822 pubDate in GMT '
        'WHEN the feed is parsed '
        'THEN publishedAt is that instant', () {
      final episode = parseSingle(pubDate: 'Wed, 02 Oct 2024 08:00:00 GMT');

      expect(episode.publishedAt?.toUtc(), DateTime.utc(2024, 10, 2, 8));
    });

    test('GIVEN items listed oldest first with RFC 822 pubDates '
        'WHEN the feed is parsed '
        'THEN episodes are sorted newest first', () {
      final detail = parser.parse(
        _feed([
          _item(guid: 'old', pubDate: 'Mon, 01 Jan 2024 08:00:00 GMT'),
          _item(guid: 'mid', pubDate: 'Sat, 01 Jun 2024 08:00:00 GMT'),
          _item(guid: 'new', pubDate: 'Wed, 02 Oct 2024 08:00:00 GMT'),
        ]),
        podcast,
      );

      expect(
        detail.episodes.map((e) => e.guid),
        ['new', 'mid', 'old'],
      );
    });
  });
}
