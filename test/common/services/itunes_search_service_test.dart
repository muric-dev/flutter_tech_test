import 'dart:convert';

import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/common/network/api_client.dart';
import 'package:cabina/common/services/itunes_search_service.dart';
import 'package:cabina/discover/models/podcast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const replyAll = Podcast(
  id: 2,
  title: 'Reply All',
  author: 'Gimlet',
  feedUrl: 'https://example.com/feed2.xml',
);

Map<String, Object?> jsonOf(Podcast podcast) => {
  'collectionId': podcast.id,
  'collectionName': podcast.title,
  'artistName': podcast.author,
  'feedUrl': podcast.feedUrl,
};

String resultsBody(List<Map<String, Object?>?> results) =>
    jsonEncode({'resultCount': results.length, 'results': results});

ItunesSearchService buildService(String body) => ItunesSearchService(
  apiClient: ApiClient(
    client: MockClient((_) async => http.Response(body, 200)),
  ),
);

Matcher throwsApiException(String message) => throwsA(
  isA<ApiException>().having((e) => e.message, 'message', message),
);

void main() {
  group('ItunesSearchService', () {
    group('searchPodcasts', () {
      test(
        'GIVEN an empty query '
        'WHEN searchPodcasts '
        'THEN returns empty list without making a request',
        () async {
          var requested = false;
          final client = MockClient((_) async {
            requested = true;
            return http.Response('{}', 200);
          });
          final service = ItunesSearchService(
            apiClient: ApiClient(client: client),
          );

          final results = await service.searchPodcasts('   ');

          expect(results, isEmpty);
          expect(requested, isFalse);
        },
      );

      test(
        'GIVEN a non-JSON body '
        'WHEN searchPodcasts '
        'THEN throws ApiException',
        () async {
          await expectLater(
            buildService('<html>Error</html>').searchPodcasts('technology'),
            throwsApiException('Unexpected response from iTunes'),
          );
        },
      );

      test(
        'GIVEN a body without a "results" list '
        'WHEN searchPodcasts '
        'THEN throws ApiException',
        () async {
          await expectLater(
            buildService('{"resultCount": 0}').searchPodcasts('technology'),
            throwsApiException('Unexpected response from iTunes'),
          );
        },
      );

      test(
        'GIVEN a null result and one missing collectionName '
        'WHEN searchPodcasts '
        'THEN returns only the valid podcasts',
        () async {
          final body = resultsBody([
            null,
            {...jsonOf(replyAll), 'collectionId': 1, 'collectionName': null},
            jsonOf(replyAll),
          ]);

          final results = await buildService(body).searchPodcasts('tech');

          expect(results, [replyAll]);
        },
      );

      test(
        'GIVEN results with an empty or missing feedUrl '
        'WHEN searchPodcasts '
        'THEN drops them',
        () async {
          final body = resultsBody([
            {...jsonOf(replyAll), 'collectionId': 1, 'feedUrl': ''},
            {...jsonOf(replyAll), 'collectionId': 3}..remove('feedUrl'),
            jsonOf(replyAll),
          ]);

          final results = await buildService(body).searchPodcasts('tech');

          expect(results, [replyAll]);
        },
      );
    });

    group('lookupById', () {
      test(
        'GIVEN the first result is malformed '
        'WHEN lookupById '
        'THEN returns the next valid podcast',
        () async {
          final body = resultsBody([
            {'collectionId': 1, 'collectionName': 'No feed', 'artistName': 'X'},
            jsonOf(replyAll),
          ]);

          final podcast = await buildService(body).lookupById(2);

          expect(podcast, replyAll);
        },
      );

      test(
        'GIVEN a non-JSON body '
        'WHEN lookupById '
        'THEN throws ApiException',
        () async {
          await expectLater(
            buildService('<html>Error</html>').lookupById(1),
            throwsApiException('Unexpected response from iTunes'),
          );
        },
      );

      test(
        'GIVEN only a result with an empty feedUrl '
        'WHEN lookupById '
        'THEN throws ApiException instead of returning it',
        () async {
          await expectLater(
            buildService(
              resultsBody([
                {...jsonOf(replyAll), 'feedUrl': ''},
              ]),
            ).lookupById(2),
            throwsApiException('Podcast not found'),
          );
        },
      );

      test(
        'GIVEN no results '
        'WHEN lookupById '
        'THEN throws ApiException',
        () async {
          await expectLater(
            buildService(resultsBody([])).lookupById(1),
            throwsApiException('Podcast not found'),
          );
        },
      );
    });
  });
}
