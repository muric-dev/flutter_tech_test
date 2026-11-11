import 'dart:typed_data';

import 'package:cabina/common/network/api_client.dart';

/// Downloads what AI Companion reads from an episode: the feed's transcript
/// file or the audio itself.
class EpisodeDownloadService {
  EpisodeDownloadService({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// The largest file the transcription accepts: 25 MB.
  static const int maxAudioBytes = 25 * 1024 * 1024;

  /// A podcast CDN can take a while to serve 25 MB on a mobile connection.
  static const audioDownloadTimeout = Duration(minutes: 2);

  /// The raw SRT or VTT text at [url].
  Future<String> fetchTranscript(String url) =>
      _apiClient.getString(Uri.parse(url));

  /// The audio at [url], or `null` when it is over [maxAudioBytes].
  Future<Uint8List?> fetchAudio(String url) => _apiClient.getBytes(
    Uri.parse(url),
    maxBytes: maxAudioBytes,
    timeout: audioDownloadTimeout,
  );
}
