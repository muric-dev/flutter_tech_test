# 01 · AI Companion: a sheet in the player with the synced transcript, a summary and chapters, prepared on demand and cached per device

**Priority/Effort:** P1 · L  **Depends on:** [`player/plan/01_implementation_plan.md`](../../player/plan/01_implementation_plan.md) (applied)
**Status:** approved
**Commit draft(s):**
1. `feat(show_detail): ✨ read the episode's RSS transcript link and pass the feed URL to the player.`
2. `feat(common): ✨ post JSON, upload files and download capped bytes through ApiClient.`
3. `feat(ai_companion): ✨ add the transcript, chapter and companion models with their parsers.`
4. `feat(ai_companion): ✨ prepare an episode with OpenAI and cache it complete.`
5. `feat(ai_companion): ✨ add AICompanionCubit, started only on demand.`
6. `feat(ai_companion): ✨ show the AI Companion sheet from the player.`
7. `docs(ai_companion): 📝 mark the sub-feature built.`

Behaviour is in [`../README.md`](../README.md) (H1–H3, E1–E13, US1–US7). This file is only the how.

## Problem
- `lib/player/views/player_page.dart:67-79`: the player column ends at `PlayerControls`. There is no
  entry point below the controls.
- `lib/show_detail/data/parsers/rss_feed_parser.dart:63-73` never reads `<podcast:transcript>`, and
  `lib/show_detail/models/episode.dart:5-13` has no field for it. Without it H2 and US5 can't exist.
- `lib/player/models/player_args.dart:6-10` carries no feed URL. A cache keyed by `guid` alone mixes
  two podcasts (E12), and `rss_feed_parser.dart:64` falls back to the title when there is no guid.
- `lib/common/network/api_client.dart:15` only does a GET that returns a string, with one 20 s
  timeout for everything (`api_client.dart:9`). The feature needs a JSON POST, a multipart upload
  and a byte download that stops at 25 MB, each with its own timeout.
- `lib/common/errors/exceptions.dart:20-44`: no exception can carry the companion's safe messages
  or say whether "Retry" applies (E1–E5, E7, E9).
- `lib/app/widgets/app_dependency_injection.dart:27-28`: `ApiClient` and `LocalStorage` are
  constructor fields captured in closures. Nothing below can read them, so a page-scoped feature
  can't build its own repository.
- Debt this change touches: `Episode` leaves `descriptionHtml` and `imageUrl` out of `props`
  (technical_debt.md:54); `ApiException.isRateLimited` is unused (technical_debt.md:79) and gets its
  first caller here.

## Decisions
| Decision          | Choice                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Why                                                                                                                                                                                                                                                                |
|-------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Location          | `lib/player/ai_companion/` with the feature anatomy; classes prefixed `AICompanion`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | AGENTS.md sub-feature rule: it only lives inside `PlayerPage`                                                                                                                                                                                                      |
| Cubit vs Bloc     | `AICompanionCubit`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | One event source (the sheet: start, retry), no transformer. The active sentence is not cubit state                                                                                                                                                                 |
| Scope             | Created by the entry widget `AICompanionButton`, which sits in `PlayerPage`'s column. Lives and dies with the page                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | "Leave the player → thrown away" (E8) and "keeps getting ready while the player is open" both fall out of the page's lifetime. `player/` imports one widget, as the sub-feature rule asks. See Open question 1                                                     |
| Start             | `start()` runs on the button tap and is a no-op unless the status is `initial`. `retry()` only from `error`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | US7: opening the player costs nothing. Also covers a double tap and reopening the sheet                                                                                                                                                                            |
| Active sentence   | Derived in the widget: `context.select((PlayerBloc b) => companion.indexAt(b.state.position.position))`. `indexAt` is a binary search for the last segment whose start ≤ position                                                                                                                                                                                                                                                                                                                                                                                                                                                     | US1: a 200 ms tick rebuilds nothing until the index changes. Seeks while loading need no code: when the list first builds it reads the current position                                                                                                            |
| Seek              | Widgets add `PlayerSeeked(segment.start)` to `PlayerBloc`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Sub-feature rule: only views and widgets talk to the parent bloc, never the cubit                                                                                                                                                                                  |
| Pipeline owner    | The cubit sequences the stages: cache → transcript → debrief → emit `ready` → save. It checks `isClosed` between stages                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | A closed cubit stops before the next paid call and never saves (E8, US4). The call already in flight finishes and is dropped; aborting it is Out of scope                                                                                                          |
| All or nothing    | One `EpisodeCompanion` object is saved, only after it is complete. A failed save is logged with `addError` and the sheet stays `ready`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | The user already paid the wait. Losing the cache only means preparing again next time                                                                                                                                                                              |
| Repository        | Concrete `AICompanionRepository` over three services (remote: `EpisodeDownloadService`, `OpenAIService`; local: `AICompanionCacheService`) and three parsers. Only the cache service touches `LocalStorage`, the key and `schemaVersion`                                                                                                                                                                                                                                                                                                                                                                                              | AGENTS.md: service + parser → concrete repository, and services are the data sources, local storage included. Keeps local and remote apart without new folders or a new rule                                                                                       |
| Provider boundary | `OpenAIService` is the only file that names the host, `whisper-1` or `gpt-5.6-luna`. It returns raw JSON strings                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | costs/stt_costs.md: swapping the provider touches one file                                                                                                                                                                                                         |
| Prompt            | `data/prompts/debrief_prompt.dart`: `DebriefPrompt.instructions` and `DebriefPrompt.schema` as consts. Zero-shot, Markdown sections (Role, Input, Output), explicit limits: summary 2–4 sentences and ≤ 80 words, 1–8 chapters with titles of ≤ 6 words. AGENTS.md (Feature anatomy) gains `prompts/`                                                                                                                                                                                                                                                                                                                                 | OpenAI reasoning best practices: short, no examples or step-by-step, delimiters, concrete goal. The schema is the contract with `DebriefParser`, so both live in one file. No `assets/*.md`: `rootBundle` is async and needs pubspec assets for one string         |
| Debrief request   | `OpenAIDebriefRequest` (`@JsonSerializable(createFactory: false)`) with `DebriefInputSegment`, `ResponsesReasoning`, `ResponsesEffort`, `ResponsesText`, `ResponsesJsonSchema`, in `data/models/open_ai_debrief_request.dart`. `segments` is sent as `input`, one JSON string                                                                                                                                                                                                                                                                                                                                                         | A field can't be misspelled or dropped without the compiler noticing. It doesn't validate against OpenAI: the service test pins the full body against the documented shape                                                                                         |
| Key               | `const String.fromEnvironment('OPENAI_API_KEY')`, read once in `AICompanionButton` and passed to `OpenAIService(apiKey:)`. Empty → E1 before any request, but after the cache lookup                                                                                                                                                                                                                                                                                                                                                                                                                                                  | One reader, so it stays in the feature instead of a new `common/env/`. Cached episodes work without a key (H1, E6)                                                                                                                                                 |
| RSS transcript    | `RssFeedParser` keeps the first `<podcast:transcript>` whose `type` is SRT (`application/srt`, `application/x-subrip`, `text/srt`) or `text/vtt` as `Episode.transcriptUrl`. `SubtitleParser` reads both: same cue shape, VTT detected by its `WEBVTT` header                                                                                                                                                                                                                                                                                                                                                                         | README: only SRT and VTT in the MVP. The feed parser is where raw payload becomes a model                                                                                                                                                                          |
| Audio download    | `ApiClient.getBytes(uri, maxBytes:)` streams the GET and returns `null` as soon as `Content-Length` or the bytes read pass 25 MB                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | E4 without a HEAD request (podcast CDNs redirect, and some omit the length). Nothing is uploaded                                                                                                                                                                   |
| Upload file name  | Extension taken from the enclosure URL path, `mp3` when there is none                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | The transcription endpoint decides the format from the file name                                                                                                                                                                                                   |
| Whisper filter    | `WhisperTranscriptParser` drops a segment when `no_speech_prob > 0.6` and `avg_logprob < -1`, when `compression_ratio > 2.4`, or when it repeats the previous text. Thresholds are open-source Whisper's defaults, as named constants; see the note below                                                                                                                                                                                                                                                                                                                                                                             | README rule: silence and music aren't transcribed                                                                                                                                                                                                                  |
| Music sections    | A gap of 10 s or more between kept segments, and an RSS cue that is only `♪` or `[Music]` between spoken cues, becomes a segment with `isMusic: true`. Music before the first sentence or after the last is not shown: the list starts and ends on a sentence                                                                                                                                                                                                                                                                                                                                                                        | E13: with music as a segment, "last start ≤ position" highlights it with no special case. Intro and outro music are skipped: the sheet opens straight on the sentences, and before the first one `indexAt` returns it                                              |
| No speech         | No spoken segment left after filtering → E9                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |                                                                                                                                                                                                                                                                    |
| Chapters          | The model receives `[{id, text}]` for spoken segments only and returns `segmentId`s (strict JSON schema). `DebriefParser` drops ids it never sent (out of range or a music segment), sorts and de-duplicates. A `Chapter` stores `segmentIndex`; its time is read from the segment                                                                                                                                                                                                                                                                                                                                                    | README: the time comes from the transcript, never from the model                                                                                                                                                                                                   |
| Summary language  | The prompt asks for the transcript's language. The transcript is passed as data, with the instruction that it is never a command                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Third-party text. Everything renders as plain `Text`                                                                                                                                                                                                               |
| Sync notice       | `EpisodeCompanion.isSyncApproximate(total)`: audio source → `abs(transcribed − total) > 3 s`; RSS source → last cue ends more than 3 s after `total`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | E10. An RSS transcript says nothing about the file's length, and an outro with no cues is normal                                                                                                                                                                   |
| Cache             | `LocalStorage`, key `ai_companion_<base64Url(feedUrl + '\n' + guid)>`, value `{schemaVersion: 1, ...}`. A value that isn't valid, or has another version, reads as "no cache"                                                                                                                                                                                                                                                                                                                                                                                                                                                         | No dependency (`crypto`, `path_provider`). E11, E12. Size trade-off in Out of scope                                                                                                                                                                                |
| Errors            | New `AICompanionException(message, {canRetry})`. The repository maps every failure to one of six fixed messages; the original goes in `cause` and reaches the log through `addError`                                                                                                                                                                                                                                                                                                                                                                                                                                                  | README: messages never name the provider, the key or a limit                                                                                                                                                                                                       |
| Sheet             | `showModalBottomSheet(isScrollControlled: true)` + `DraggableScrollableSheet(snap: true, snapSizes: [0.6, 1])`. Both blocs are passed in with `BlocProvider.value`. The sheet's scroll controller drives only the header; each tab scrolls on its own                                                                                                                                                                                                                                                                                                                                                                                 | Back and swipe-down come for free. A modal route sits outside the page's providers                                                                                                                                                                                 |
| Sheet content     | Two tabs: **Summary** (summary + chapters, first) and **Transcript**. "Generated by AI" label in the header                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | US3 wants the summary on opening; US1 wants the transcript opened at the current sentence. One scroll can't do both                                                                                                                                                |
| Transcript list   | Lazy `CustomScrollView` with a `center` sliver anchored on a sentence. A nearby change animates with `Scrollable.ensureVisible`; a far jump re-anchors and `jumpTo(0)`                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Exact jumps in a lazy list of variable heights, without `scrollable_positioned_list`                                                                                                                                                                               |
| Follow            | The list follows the active sentence. A drag by hand pauses it; a jump (tap, seek, skip: the index moves by more than one) resumes it                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Not in the README. Without it the list pulls you back every few seconds while you read ahead                                                                                                                                                                       |
| Compact panel     | Shown when the sheet extent reaches 1: episode title, play/pause, the player's `SeekBar`, close                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | README UI decision. Reusing `SeekBar` avoids a second copy of the drag logic                                                                                                                                                                                       |
| Serialization     | `@JsonSerializable(checked: true)` on the cache models (`EpisodeCompanion`, `TranscriptSegment`, `Chapter`) and on the two OpenAI response shapes (`WhisperResponse`/`WhisperSegment`, `ResponsesEnvelope`/`ResponsesOutput`/`ResponsesContent`, plus the answer inside it, `DebriefAnswer`/`DebriefAnswerChapter`, `createToJson: false`). The provider's shapes (DTOs) live in `data/models/`, one file per shape: `whisper_response`, `responses_envelope`, `debrief_answer`, `open_ai_debrief_request`. They never leave `data/`; the parsers map them to `models/`. `.g.dart` are not commited. SRT/VTT and RSS stay hand-parsed | Already in `pubspec.yaml` and used by `Podcast`: no hand-written casts. `checked: true` turns a bad payload into `CheckedFromJsonException` (an `Exception`), which parsers and the cache read catch by name. DTOs apart from the domain, as VGV's data layer does |
| Isolates          | None                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | A 26 min Whisper JSON is ~400 segments. Measured threshold in Out of scope                                                                                                                                                                                         |

Whisper filter note: OpenAI's Audio API reference gives the same `avg_logprob < -1` and
`compression_ratio > 2.4`, but says `no_speech_prob` "higher than 1.0", which a probability never
reaches. So the plan keeps 0.6, the default in the open-source Whisper code.

### User-facing messages (the only ones)
| Case                                                  | Message                                          | Retry |
|-------------------------------------------------------|--------------------------------------------------|-------|
| E1 no key · E2 `401`/`403`                            | AI Companion isn't available right now           | no    |
| E3 `429`                                              | AI Companion is busy. Try again later            | no    |
| E4 audio over 25 MB, no RSS transcript                | This episode is too long for AI Companion        | no    |
| E5 `NetworkException` (not a timeout)                 | No connection. Check your internet and try again | yes   |
| E7 anything else (timeout, other status, bad payload) | Couldn't prepare AI Companion                    | yes   |
| E9 no spoken segment                                  | Not enough spoken audio in this episode          | no    |

## Open questions
Each one is an "Ask before acting" item in AGENTS.md. All eight are answered; the choices are in
Decisions.
1. **Who creates the cubit.** AGENTS.md says route-scoped blocs are built in the page's `route()`,
   and also that the parent imports the sub-feature only for its entry widget. Both can't hold.
   **Answered:** the entry widget owns its `BlocProvider`. AGENTS.md (Layers and DI) now says so.
2. **`ApiClient` and `LocalStorage` readable from context.** Today `AppDependencyInjection` holds
   both as constructor fields and only hands them to the repositories it builds, so
   `context.read<ApiClient>()` fails anywhere below. `AICompanionButton` needs both to build its
   repository. **Answered:** two `RepositoryProvider.value` in `AppDependencyInjection`, one for
   each. `AICompanionRepository` is not registered app-scoped: that would copy a Known debt row.
3. **Additions to `common/`.** **Answered:** the two POSTs (`ApiClient.postJson`, `postMultipart`)
   `getBytes` (the capped audio download) and the `AICompanionException` subtype are approved.
4. **Contracts other features use.** `Episode.transcriptUrl` (optional) and `PlayerArgs.feedUrl`
   (required, one call site: `show_detail_page.dart:153`). **Answered:** approved. No other feature
   reads either field; `show_detail` only fills them in.
5. **Sub-feature importing a parent widget.** **Answered:** AGENTS.md (Layers and DI) now allows the
   parent's bloc, state, models and widgets, so the compact panel reuses `SeekBar`.
6. **UX the README doesn't settle.** **Answered:** Summary tab first, and follow pauses on a manual
   scroll.
7. **Where this plan lives.** **Answered:** every plan lives in
   `docs/<feature>/plan/NN_implementation_plan.md`, numbered per feature. AGENTS.md (Workflow)
   now says so, and the library and player plans moved with it.
8. **Request shapes.** **Answered:** confirmed against OpenAI's docs on Nov 10, 2026 (speech-to-text
   guide, Audio API reference, `gpt-5.6-luna` model page, reasoning and Structured Outputs guides).
   The shapes are under Step 4. Two things changed from the first draft:
   - The debrief uses the Responses API (`POST /v1/responses`), where the fields are
     `reasoning: {effort}` and `text: {format}`. `reasoning_effort` is the Chat Completions name.
   - The answer comes inside an envelope (`output[]` → `message` → `content[]`), and a refusal or an
     incomplete response doesn't follow the schema. `DebriefParser` reads the envelope.
   Not confirmed: the `gpt-5.6-luna` page lists Structured Outputs without naming strict mode, and
   the unit of `duration` isn't stated (segment `start`/`end` are in seconds). The first real call
   in step 4 settles both.

## Fix
**Step 1: feed data (show_detail, player args).**
- `Episode`: add `transcriptUrl` (`String?`), and put every field in `props`.
- `RssFeedParser._parseEpisode`: read `<podcast:transcript>` as in Decisions. Document the rule in
  the member's `///`.
- `PlayerArgs`: add `feedUrl`. `ShowDetailPage` passes `detail.feedUrl`.

**Step 2: common.**
- `ApiClient`:
  ```dart
  Future<String> postJson(Uri uri, {required Object body, Map<String, String>? headers, Duration? timeout});
  Future<String> postMultipart(Uri uri, {required Map<String, String> fields, required String fileField,
      required String fileName, required Uint8List bytes, Map<String, String>? headers, Duration? timeout});
  /// `null` when the body is larger than [maxBytes]; nothing past the limit is kept.
  Future<Uint8List?> getBytes(Uri uri, {required int maxBytes, Duration? timeout});
  ```
  One private helper holds the timeout and the failure mapping `getString` has today.
- `exceptions.dart`:
  ```dart
  /// AI Companion could not prepare an episode. [message] is safe to show:
  /// it never names the provider, the key or a limit.
  class AICompanionException extends CabinaException {
    const AICompanionException(super.message, {this.canRetry = false, super.cause});
    final bool canRetry;
  }
  ```
- `AppDependencyInjection`: `RepositoryProvider.value` for `apiClient` and `localStorage`.

**Step 3: models and parsers (pure Dart).**
- `TranscriptSegment { start, text, isMusic }`, `Chapter { title, segmentIndex }`,
  `TranscriptSource { rss, audio }`, `EpisodeCompanion { source, segments, transcribedDuration,
  summary, chapters }` with `indexAt` and `isSyncApproximate`. All three are `@JsonSerializable`
  with generated `fromJson`/`toJson`; `Duration` and the enum use the generator's defaults
  (microseconds, enum name). `schemaVersion` wraps the value in the repository, not in the model.
- `Transcript { source, segments, duration }`: what a transcript stage returns before the debrief.
  Not serialized.
- `SubtitleParser` (hand-written: SRT and VTT are text). `WhisperTranscriptParser` and
  `DebriefParser` decode with the generated `fromJson` of their response shapes, then apply the
  filter, music and chapter rules on typed fields. Each parser throws `FeedParseException` on a
  payload it can't read (`FormatException`, `CheckedFromJsonException`), with the original as
  `cause`.
- Run `fvm dart run build_runner build --delete-conflicting-outputs` after editing an annotated
  class.

**Step 4: services and repository.**
- `EpisodeDownloadService(apiClient)`: `fetchTranscript(url)` → text; `fetchAudio(url)` → bytes, or
  `null` over 25 MB. Timeouts: `fetchTranscript` keeps `ApiClient`'s 20 s default; `fetchAudio`
  passes `audioDownloadTimeout` (2 min), a named constant in the service, to `getBytes`.
- `AICompanionCacheService(localStorage)`: `read(feedUrl:, guid:)` → `EpisodeCompanion?` and
  `write(feedUrl:, guid:, companion:)`. Owns the key and `schemaVersion`; an unreadable value or a
  storage failure reads as `null`.
- `DebriefPrompt` (`data/prompts/`): the instructions and the strict schema.
- `OpenAIService(apiClient, apiKey)`: `isConfigured`, `transcribe(bytes, fileName)`,
  `debrief(segments)`. Timeouts: 5 min and 2 min. Both send `Authorization: Bearer <key>`.
  - `transcribe`: `POST https://api.openai.com/v1/audio/transcriptions`, multipart, with `file`,
    `model=whisper-1` and `response_format=verbose_json`. Segment timestamps are the default, so
    `timestamp_granularities[]` isn't sent. The response has `duration`, `language`, `text` and
    `segments[]` (`start`, `end`, `text`, `avg_logprob`, `compression_ratio`, `no_speech_prob`).
    Accepted formats: mp3, mp4, mpeg, mpga, m4a, wav, webm; any other enclosure is rejected by the
    API and lands on E7.
  - `debrief`: `POST https://api.openai.com/v1/responses`, the `toJson()` of an
    `OpenAIDebriefRequest`:
    ```json
    {
      "model": "gpt-5.6-luna",
      "reasoning": {"effort": "low"},
      "instructions": "<system prompt>",
      "input": "<JSON of [{id, text}]>",
      "text": {"format": {"type": "json_schema", "name": "debrief", "strict": true, "schema": {}}}
    }
    ```
    The schema's root is an object, every object sets `additionalProperties: false` and lists every
    property in `required`. `max_output_tokens` isn't set: reasoning tokens count against it.
  - `DebriefParser` reads the response envelope (`ResponsesEnvelope.fromJson`): the `output[]` item with `type: "message"`, then
    its `content[]` item with `type: "output_text"`, whose `text` is the schema JSON. A `refusal`
    content item, `status: "incomplete"` or no message item throws `FeedParseException` (E7).
- `AICompanionRepository`:
  ```dart
  Future<EpisodeCompanion?> loadCached(PlayerArgs args);   // null: none, corrupt or old version
  Future<Transcript> transcript(Episode episode);          // RSS first, else audio
  Future<EpisodeCompanion> debrief(Transcript transcript);
  Future<void> save(PlayerArgs args, EpisodeCompanion companion);
  ```
  `transcript` and `debrief` run inside one private `_guard` that applies the message table.

**Step 5: cubit.**
- `AICompanionState { status, companion, errorMessage, canRetry }` with
  `AICompanionStatus { initial, loading, ready, error }` and `copyWith(..., clearError)`.
- `AICompanionCubit({repository, args})`: `start()`, `retry()`, both over one private `_prepare()`
  with the AGENTS.md catch (`on Object` → `addError` → `messageOf`).

**Step 6: UI.**
- `AICompanionButton(args)`: provides the cubit, shows the "AI Companion" button with
  `Icons.auto_awesome`, opens the sheet and calls `start()`.
- `views/ai_companion_sheet.dart`: loading → `LoaderView`; error → `ErrorView(message, onRetry:
  canRetry ? retry : null)`; ready → tabs. Header, AI label, sync notice, compact panel at extent 1.
- `widgets/`: `summary_tab.dart` (summary + chapter rows with `start.clock`), `transcript_list.dart`,
  `compact_player_bar.dart`. Colors from `context.appTheme`, styles from `AppTextStyles`, times with
  `DurationFormat.clock`.
- `PlayerPage`: `AICompanionButton(args: widget.args)` under `PlayerControls`. Nothing else changes.

**Step 7: docs.**
- `AGENTS.md`: project map line for `ai_companion/` (drop "planned").
- `technical_debt.md`: line 79 without `ApiException.isRateLimited`. (Line 54, `Episode` done,
  landed with step 1.)

## Files
- New, `lib/player/ai_companion/`: `cubit/ai_companion_{cubit,state}.dart`,
  `data/ai_companion_repository.dart`,
  `data/services/{open_ai_service,episode_download_service,ai_companion_cache_service}.dart`,
  `data/prompts/debrief_prompt.dart`,
  `data/models/{whisper_response,responses_envelope,debrief_answer,open_ai_debrief_request}.dart`,
  `data/parsers/{subtitle_parser,whisper_transcript_parser,debrief_parser}.dart`,
  `models/{transcript_segment,chapter,transcript,episode_companion}.dart`, the generated
  `.g.dart` of `transcript_segment`, `chapter`, `episode_companion` and the four `data/models/` files,
  `views/ai_companion_sheet.dart`,
  `widgets/{ai_companion_button,summary_tab,transcript_list,compact_player_bar}.dart`.
- New tests: only the files listed under Tests first (no test for the generated code, `Transcript`,
  `ai_companion_state` or the tab widgets on their own).
- Edited: `lib/show_detail/models/episode.dart`, `lib/show_detail/data/parsers/rss_feed_parser.dart`,
  `lib/show_detail/views/show_detail_page.dart`, `lib/player/models/player_args.dart`,
  `lib/player/views/player_page.dart`, `lib/common/network/api_client.dart`,
  `lib/common/errors/exceptions.dart`, `lib/app/widgets/app_dependency_injection.dart`, their
  existing tests, `AGENTS.md`, `README.md`, `docs/tasks/technical_debt.md`.
- Moved / deleted: none.

## Tests first
Only tests for what a real episode, feed or provider response does. Every fixture is shaped like a
real payload: a real SRT/VTT snippet, a Whisper `verbose_json` and a Responses API body. Each README
row is pinned at one layer only. Not tested: generated `fromJson`/`toJson` field by field,
pass-throughs, `Equatable` boilerplate, the shared `LoaderView`/`ErrorView`, and Out of scope cases.

`test/show_detail/data/parsers/rss_feed_parser_test.dart`
- GIVEN an item listing JSON, HTML and SRT transcripts THEN `transcriptUrl` is the SRT one. Pins
  US5 and the type rule.
- GIVEN an item with only an HTML transcript THEN `transcriptUrl` is null.
- GIVEN two episodes that differ only in `descriptionHtml`, `imageUrl` or `transcriptUrl` THEN they
  are not equal (one test, three expectations). Pins technical_debt.md:54.

`test/common/network/api_client_test.dart` (`MockClient`)
- GIVEN a 2xx WHEN postJson THEN sends the encoded body and headers and returns the body.
- WHEN postMultipart THEN the request carries the fields and the file under its file name.
- GIVEN a body under maxBytes WHEN getBytes THEN returns it.
- GIVEN a Content-Length over maxBytes / no Content-Length and a body over maxBytes WHEN getBytes
  THEN returns null (one test each: CDNs do both). Pins E4.

`.../data/parsers/subtitle_parser_test.dart`
- GIVEN an SRT file with `♪` cues at the start, middle and end THEN returns the cues in order with
  their starts, only the middle one as music. Pins E13 for RSS and the intro/outro rule.
- GIVEN a VTT file THEN returns the same cues.
- GIVEN an SRT with only music cues THEN returns no segment. Pins E9's input for RSS.
- GIVEN an HTML page served at the transcript URL THEN throws FeedParseException.

`.../data/parsers/whisper_transcript_parser_test.dart`
- GIVEN a 20 s silent intro, a looped hallucination (high `compression_ratio`), a repeated line, a
  30 s gap and a 24 s outro THEN keeps only the spoken segments, with a music segment only in the
  gap. Pins the filter, E13 and the intro/outro rule.
- GIVEN a response where every segment is filtered THEN returns no spoken segment. Pins E9's input.

`.../data/parsers/debrief_parser_test.dart`
- GIVEN a response with a reasoning item before the message, and chapters out of order with one
  unknown id THEN returns the summary and the known chapters sorted.
- GIVEN a refusal / `status: "incomplete"` THEN throws FeedParseException (one test, two cases).
  Pins E7 for the debrief.

`.../models/episode_companion_test.dart`
- GIVEN positions before the first sentence, inside one and inside a music section THEN `indexAt`
  returns 0, that sentence and the music segment. Pins US1.
- GIVEN an audio source 5 s off the total THEN sync is approximate; 2 s off THEN it isn't. Pins E10.
- GIVEN an RSS source that ends 30 s before the total (an outro with no cues) THEN sync is not
  approximate.
- GIVEN a companion WHEN `toJson` then `fromJson` THEN it is equal. Pins the generator config
  (`Duration`, enum, nested lists) the cache relies on.

`.../data/services/open_ai_service_test.dart` (mocked `ApiClient`)
- WHEN transcribe THEN posts multipart to `/v1/audio/transcriptions` with the bearer key,
  `whisper-1`, `verbose_json`, the file name and the 5 min timeout.
- WHEN debrief THEN posts the documented body, compared whole (pins `OpenAIDebriefRequest`), to
  `/v1/responses` with the bearer key, `gpt-5.6-luna`, effort
  low, the strict schema, only `{id, text}` of spoken segments, and the 2 min timeout.

`.../data/services/episode_download_service_test.dart` (mocked `ApiClient`)
- WHEN fetchAudio THEN calls `getBytes` with the 25 MB cap and `audioDownloadTimeout`. Pins E4's
  limit.

`.../data/services/ai_companion_cache_service_test.dart` (mocked `LocalStorage`)
- GIVEN a written episode THEN read returns it.
- GIVEN a value written with another schemaVersion THEN read returns null. Pins E11 (an app
  update).
- GIVEN the same guid under two feed URLs THEN each reads its own key. Pins E12.
- GIVEN a corrupt value or a storage failure THEN read returns null.

`.../data/ai_companion_repository_test.dart` (mocked services)
- GIVEN a cached episode THEN loadCached returns it and no remote service is called. Pins H1, E6.
- GIVEN an episode with a transcript URL THEN returns an RSS transcript and never downloads the
  audio. Pins H2, US5.
- GIVEN no transcript URL and an enclosure `…/ep.m4a?updated=123` under the cap THEN uploads once as
  `ep.m4a` and returns an audio transcript. Pins H3.
- GIVEN a transcript WHEN debrief THEN returns the companion with its summary and chapters.
- GIVEN audio over the cap THEN throws "too long" and uploads nothing. Pins E4.
- GIVEN no key THEN throws "not available" with no request. Pins E1.
- GIVEN a 401 / a 429 / a NetworkException / a timeout THEN throws that row's message and
  `canRetry` (one table-driven test). Pins E2, E3, E5, E7.
- GIVEN no spoken segment THEN throws "not enough spoken audio". Pins E9.

`.../cubit/ai_companion_cubit_test.dart`
- GIVEN a cached episode WHEN start THEN emits loading, ready, and saves nothing.
- GIVEN no cache WHEN start THEN emits loading, ready, then saves once. Pins US4.
- GIVEN start running WHEN start again (double tap, sheet reopened) THEN the repository runs once.
- GIVEN the cubit closes during the transcript stage THEN debrief and save are never called.
  Pins E8.
- GIVEN the save fails THEN the state stays ready and the error reaches `errors`.
- GIVEN a retryable failure WHEN retry THEN emits loading without the error, then ready. Pins US6.

`test/player/ai_companion/widgets/ai_companion_button_test.dart` and
`views/ai_companion_sheet_test.dart` (`MockBloc`, `MockCubit`,
`MaterialApp(theme: AppTheme(isDark: false).toThemeData())`)
- GIVEN the button WHEN tapped THEN calls start and opens the sheet. Pins US7.
- GIVEN an error without retry THEN shows the message and no Retry.
- GIVEN ready THEN shows the summary, each chapter with its time and the AI label. Pins US3.
- GIVEN ready WHEN tapping a chapter and a sentence THEN adds `PlayerSeeked(start)` for each. Pins
  US2.
- GIVEN a position far down WHEN the transcript tab opens THEN that sentence is visible and
  highlighted; WHEN the position crosses to the next THEN the highlight moves. Pins US1.
- GIVEN a mismatched duration THEN shows "Sync may be approximate for this episode". Pins E10.
- GIVEN the sheet at full height THEN shows the compact panel with the title and play/pause.

`test/player/views/player_page_test.dart`
- GIVEN a ready player THEN shows the AI Companion button below the controls.

## Audit checklist
- Defensive Programming: every provider payload parsed at the edge; a closed cubit neither calls
  nor saves; corrupt cache reads as none; `getBytes` never holds more than the cap.
- TDD: each README row (H, E, US) pinned once, at the lowest layer that owns it; real-shaped
  fixtures; no test of generated code or pass-throughs. Parsers and cubit written test-first.
- Clean Code: `///` on every public class; one message table, one place.
- Feature First: everything under `lib/player/ai_companion/`; `player/` imports one widget;
  `show_detail` only gains a field.
- KISS: no isolate, no new package, no interface, no partial state; JSON through the generator
  already in `pubspec.yaml`, no hand-written casts.
- VGV Principles: analysis clean; colors and text styles from the theme.
- Repository principles: View → Cubit → Repository → Service; raw JSON never leaves `data/`.
- Scalability: a new provider replaces `OpenAIService`; a new transcript format is one parser.
- DRY: `SeekBar`, `ErrorView`, `LoaderView`, `DurationFormat.clock`, `LocalStorage`, `ApiClient`
  reused.

## Out of scope
- Aborting the request in flight when the player closes: needs `http`'s abortable requests through
  `ApiClient`. Today at most one call is wasted.
- Cache size and eviction: transcripts live in `shared_preferences`, which loads everything at
  start. Fine for a review; a file per episode needs `path_provider`, a new dependency.
- Isolates for parsing: revisit if a parse measures over one frame on a mid-range phone.
- Audio over 25 MB, partial results, background work, shared cache, ads, metrics, other transcript
  formats: README "What's left out of the MVP".
- App-wide player and `audio_session` (technical_debt.md:8, technical_debt.md:18): cross-feature.
- `state.extra!` (technical_debt.md:48) and `PlayerArgs` living in `player/` (technical_debt.md:67):
  shared with `show_detail`.
- `FormatException`/`CheckedFromJsonException` → `FeedParseException` is written in `WhisperTranscriptParser`
  and `DebriefParser` (second copy). The third one moves to `common/`.
- The key ships inside the binary: accepted in the README; production keeps it on a server.

## Verify
- `fvm dart run build_runner build --delete-conflicting-outputs` when an annotated class changed,
  then `fvm flutter analyze`, `fvm dart format --set-exit-if-changed .`, `fvm flutter test`, after
  every step.
- Device, with `fvm flutter run --dart-define-from-file=.env`: the four paths of the README's "How
  to try it" (H2, H3, E4, E1), then H1 in airplane mode, a tap on a sentence and on a chapter, a
  seek while loading, leaving mid-preparation and coming back (starts from zero), and "Highlight
  repaints" on the transcript while it plays.
