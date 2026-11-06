import 'package:cabina/show_detail/models/episode.dart';
import 'package:equatable/equatable.dart';

/// A podcast plus the episodes parsed from its RSS feed. [feedUrl] is the
/// feed they came from.
class PodcastDetail extends Equatable {
  const PodcastDetail({
    required this.podcastId,
    required this.title,
    required this.author,
    required this.feedUrl,
    required this.episodes,
    this.artworkUrl,
    this.descriptionHtml = '',
  });

  final int podcastId;
  final String title;
  final String author;
  final String feedUrl;
  final List<Episode> episodes;
  final String? artworkUrl;
  final String descriptionHtml;

  @override
  List<Object?> get props => [
    podcastId,
    title,
    author,
    feedUrl,
    episodes,
    artworkUrl,
    descriptionHtml,
  ];
}
