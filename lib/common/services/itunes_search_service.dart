import 'dart:convert';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/common/network/api_client.dart';
import 'package:cabina/discover/models/podcast.dart';

/// Talks to the iTunes Search API. No API key required.
///
/// Docs: https://performance-partners.apple.com/search-api
class ItunesSearchService {
  ItunesSearchService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  static const _host = 'itunes.apple.com';

  Future<List<Podcast>> searchPodcasts(String term, {int limit = 50}) async {
    if (term.trim().isEmpty) return const [];
    final uri = Uri.https(_host, '/search', {
      'media': 'podcast',
      'entity': 'podcast',
      'term': term,
      'limit': '$limit',
    });

    final body = await _apiClient.getString(uri);
    return _decodeResults(
      body,
    ).where(_hasFeedUrl).map(_tryParse).nonNulls.toList();
  }

  /// The podcast with [collectionId]. Throws [ApiException] when iTunes has no
  /// valid result with a feed URL for it.
  Future<Podcast> lookupById(int collectionId) async {
    final uri = Uri.https(_host, '/lookup', {'id': '$collectionId'});
    final body = await _apiClient.getString(uri);
    final podcast = _decodeResults(
      body,
    ).where(_hasFeedUrl).map(_tryParse).nonNulls.firstOrNull;
    if (podcast == null) throw const ApiException('Podcast not found');
    return podcast;
  }

  static bool _hasFeedUrl(Map<String, dynamic> json) =>
      (json['feedUrl'] as String?)?.isNotEmpty ?? false;

  List<Map<String, dynamic>> _decodeResults(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return (decoded['results'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    } on Object catch (e) {
      throw ApiException('Unexpected response from iTunes', cause: e);
    }
  }

  /// Skips a malformed result instead of failing the whole response.
  Podcast? _tryParse(Map<String, dynamic> json) {
    try {
      return Podcast.fromJson(json);
    } on Object {
      return null;
    }
  }
}
