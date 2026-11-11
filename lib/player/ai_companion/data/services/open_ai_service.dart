import 'dart:typed_data';

import 'package:cabina/common/network/api_client.dart';
import 'package:cabina/player/ai_companion/data/models/open_ai_debrief_request.dart';
import 'package:cabina/player/ai_companion/data/prompts/debrief_prompt.dart';
import 'package:cabina/player/ai_companion/models/transcript_segment.dart';

/// The only file that knows AI Companion's provider: it transcribes audio
/// with Whisper and asks a model for the debrief. It returns the raw JSON;
/// the parsers read it.
class OpenAIService {
  OpenAIService({required ApiClient apiClient, required String apiKey})
    : _apiClient = apiClient,
      _apiKey = apiKey;

  final ApiClient _apiClient;
  final String _apiKey;

  static final Uri _transcriptionsUri = Uri.parse(
    'https://api.openai.com/v1/audio/transcriptions',
  );
  static final Uri _responsesUri = Uri.parse(
    'https://api.openai.com/v1/responses',
  );

  /// Whisper takes about a minute for a long episode, plus the upload.
  static const transcribeTimeout = Duration(minutes: 5);
  static const debriefTimeout = Duration(minutes: 2);

  /// Whether a key was configured. Without one every call fails.
  bool get isConfigured => _apiKey.isNotEmpty;

  Map<String, String> get _auth => {'Authorization': 'Bearer $_apiKey'};

  /// Transcribes [bytes] and returns Whisper's `verbose_json`. The API
  /// reads the format from [fileName]'s extension.
  Future<String> transcribe(Uint8List bytes, String fileName) =>
      _apiClient.postMultipart(
        _transcriptionsUri,
        fields: const {'model': 'whisper-1', 'response_format': 'verbose_json'},
        fileField: 'file',
        fileName: fileName,
        bytes: bytes,
        headers: _auth,
        timeout: transcribeTimeout,
      );

  /// Asks for the summary and chapters of [segments] and returns the
  /// Responses API body. Each spoken segment is sent as `{id, text}`, where
  /// `id` is its index in [segments]; music segments are not sent.
  Future<String> debrief(List<TranscriptSegment> segments) =>
      _apiClient.postJson(
        _responsesUri,
        body: OpenAIDebriefRequest(
          model: 'gpt-5.6-luna',
          reasoning: const ResponsesReasoning(effort: ResponsesEffort.low),
          instructions: DebriefPrompt.instructions,
          segments: [
            for (final (id, segment) in segments.indexed)
              if (!segment.isMusic)
                DebriefInputSegment(id: id, text: segment.text),
          ],
          text: const ResponsesText(
            format: ResponsesJsonSchema(
              name: 'debrief',
              strict: true,
              schema: DebriefPrompt.schema,
            ),
          ),
        ).toJson(),
        headers: _auth,
        timeout: debriefTimeout,
      );
}
