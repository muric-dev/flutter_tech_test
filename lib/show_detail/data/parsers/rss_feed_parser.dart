import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/common/parsers/itunes_duration_parser.dart';
import 'package:cabina/common/parsers/rfc822_date_parser.dart';
import 'package:cabina/discover/models/podcast.dart';
import 'package:cabina/show_detail/models/episode.dart';
import 'package:cabina/show_detail/models/podcast_detail.dart';
import 'package:xml/xml.dart';

/// Turns a podcast's raw RSS feed into a [PodcastDetail].
class RssFeedParser {
  const RssFeedParser();

  /// Parses [xmlString] into the detail of [podcast], newest episode first.
  ///
  /// Items that can't be shown or played are skipped: those without a title
  /// (`<title>`, falling back to `<itunes:title>`) or an enclosure URL.
  ///
  /// Throws a [FeedParseException] when [xmlString] is not valid XML or has
  /// no `<channel>`.
  PodcastDetail parse(String xmlString, Podcast podcast) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xmlString);
    } on XmlException catch (e) {
      throw FeedParseException('Feed is not valid XML', cause: e);
    }

    final channel = document.findAllElements('channel').firstOrNull;
    if (channel == null) {
      throw const FeedParseException('Feed has no <channel>');
    }

    final episodes =
        channel.findAllElements('item').map(_parseEpisode).nonNulls.toList()
          // Newest first.
          ..sort((a, b) {
            final aDate = a.publishedAt ?? DateTime(1970);
            final bDate = b.publishedAt ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });

    final description = _stripHtml(_firstText(channel, 'description') ?? '');

    return PodcastDetail(
      podcastId: podcast.id,
      title: podcast.title,
      author: podcast.author,
      feedUrl: podcast.feedUrl,
      artworkUrl: podcast.artworkUrl,
      descriptionHtml: description,
      episodes: episodes,
    );
  }

  /// Returns `null` when [item] has no title or no enclosure URL to play.
  Episode? _parseEpisode(XmlElement item) {
    final title = _firstText(item, 'title') ?? _firstText(item, 'itunes:title');
    final audioUrl = _firstAttr(item, 'enclosure', 'url');
    if (title == null || audioUrl == null || audioUrl.trim().isEmpty) {
      return null;
    }

    return Episode(
      guid: _firstText(item, 'guid') ?? title,
      title: title,
      audioUrl: audioUrl,
      descriptionHtml: _firstText(item, 'description') ?? '',
      duration: ItunesDurationParser.tryParse(
        _firstText(item, 'itunes:duration'),
      ),
      publishedAt: Rfc822DateParser.tryParse(_firstText(item, 'pubDate')),
      imageUrl: _firstAttr(item, 'itunes:image', 'href'),
    );
  }

  String? _firstText(XmlElement parent, String name) {
    final matches = parent.findElements(name);
    if (matches.isEmpty) return null;
    final text = matches.first.innerText.trim();
    return text.isEmpty ? null : text;
  }

  String? _firstAttr(XmlElement parent, String name, String attr) {
    final matches = parent.findElements(name);
    if (matches.isEmpty) return null;
    return matches.first.getAttribute(attr);
  }

  String _stripHtml(String html) {
    // Remove tags and collapse whitespace.
    final withoutTags = html.replaceAll(RegExp('<[^>]*>'), ' ');
    return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
