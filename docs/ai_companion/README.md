# AI Companion

Here I explain what AI Companion does inside Cabina, what the user sees and why I decided it this
way. I don't explain how it's built: that lives in [`plan/01_implementation_plan.md`](plan/01_implementation_plan.md).
Prices are in [`costs/`](costs/), and if you want to know how I got to all of this, the reasoning
behind it is in [`marcos_brain.md`](marcos_brain.md).

## What it is

The idea is simple: while you listen to an episode, AI Companion keeps you company with three things.

1. **The synced transcript**, with the sentence you're hearing highlighted. If you've seen the lyrics
   in Spotify, it's the same.
2. **A summary** of the episode.
3. **Chapters** with the real time each one starts.

Interested in a sentence or a chapter? Tap it and the audio jumps to that moment.

## User actions

This is what the user can do and what happens in each case:

| Action                                                        | What happens                                                                                                                                                                      |
|---------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Open an episode in the player                                 | Nothing else. AI Companion doesn't start on its own and no call is made                                                                                                           |
| Tap the "AI Companion" button (magic icon) below the controls | A sheet opens from the bottom and AI Companion starts getting ready. If the episode was already prepared on this device, it's ready instantly. The player stays visible behind it |
| Drag the sheet up or tap the full-screen button              | It takes the whole screen. The episode shows on top, with a button to bring the sheet back to half, and the controls move to the bottom                                         |
| Drag down or close                                            | Back to the player. AI Companion keeps getting ready while the player is open                                                                                                     |
| Tap a sentence                                                | The audio jumps to the start of that sentence and it becomes the active one                                                                                                       |
| Tap a chapter                                                 | The audio jumps to the start of the chapter                                                                                                                                       |
| Move the progress bar or skip seconds                         | The transcript moves to the sentence at that position. If AI Companion is still getting ready, it opens at that position when it finishes                                         |
| Tap "Retry" on an error                                       | The process starts again from the beginning                                                                                                                                       |
| Leave the player while it's getting ready                     | The work is thrown away. When you come back, it starts from zero                                                                                                                  |

## UI decisions and why

| Decision                                                                                                       | Why                                                                                                                                                                           |
|----------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| An "AI Companion" button with a magic icon below the controls, and it only starts there                        | If someone opens an episode by accident, I don't want that to trigger a transcription nobody asked for. The magic icon says "there's AI here" without having to read anything |
| A draggable sheet over the player, not a new screen                                                            | I didn't want the user to lose the player. Also, it's a gesture they already know from Spotify lyrics, nothing new to learn                                                   |
| In full screen, the episode on top and the controls at the bottom: progress bar, play/pause and the AI label    | With the sheet open, the text takes the whole screen. What if you want to pause or move around the audio? You shouldn't have to close it. And the controls sit where the thumb is, like in Spotify |
| The active sentence is highlighted and the list follows it                                                     | Read and listen at the same time, without hunting for where the audio is                                                                                                      |
| Chapters show their start time (`12:30`)                                                                       | The time comes from the transcript, not from the AI model. That way I make sure it always points to a real sentence                                                           |
| A discreet "Sync may be approximate for this episode" notice                                                   | Some podcasts insert different ads on each download, and the duration doesn't always match. I'd rather warn; the feature keeps working                                        |
| A "Generated by AI" label                                                                                      | A model writes the summary and the chapters, and models get things wrong. The user has to know it                                                                             |
| All text is plain: no links, Markdown or HTML                                                                  | The transcript comes from third parties. I treat it as data, never as an instruction                                                                                          |

## Product rules

An MVP is letting things go, and knowing what we're letting go. To keep AI Companion simple (KISS)
and still have it feel good, I set myself these rules:

| Rule                                                                       | Why                                                                                                                                                                                                                                       |
|----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| A single OpenAI key                                                        | I don't want the reviewer creating accounts with several providers or setting up Firebase. One key and done                                                                                                                               |
| `whisper-1` transcribes, `gpt-5.6-luna` summarizes                         | Both use the same key. `gpt-5.6-luna` is the official replacement for `gpt-5-nano`, which shuts down on Dec 11, 2026, and even so, summarizing an hour of episode costs less than a cent (see [`costs/llm_costs.md`](costs/llm_costs.md)) |
| The podcast's RSS transcript comes first                                   | It's free and ready in seconds. Why pay to transcribe something the podcast already gives us? Only if it doesn't exist does the audio get transcribed                                                                                     |
| Audio is transcribed only if it's 25 MB or less (about 26 min at 128 kbps) | That's the limit of a direct upload to OpenAI. Chopping audio on the phone is fragile, that's a server's job                                                                                                                              |
| All or nothing                                                             | An episode is saved only when the transcript, the summary and the chapters are complete. I'd rather start from zero than have half-done episodes                                                                                          |
| The cache is local, on this device                                         | There's no backend in the MVP. If two users open the same episode, each one pays for their own process (see [`costs/`](costs/)). I know, and I accept it for this version                                                                 |
| It starts only when the user taps "AI Companion"                           | Opening an episode by accident costs nothing: only what someone asked for gets transcribed and summarized. **BUT IT'S NOT ALL ROSES:** the first time you open it on an episode with no cache, you have to wait for it to get ready       |
| Silence and music aren't transcribed                                       | In those stretches automatic transcription tends to hallucinate and make up repeated sentences. In the list, a music stretch shows up as a music section (♪)                                                                             |

## Expected behavior

This is how AI Companion has to behave. First what goes right, then what can go wrong.

### Happy paths

| #  | Situation                                                        | What the user sees                                                                        |
|----|------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| H1 | The episode was already prepared on this device                  | Transcript, summary and chapters instantly, offline too                                   |
| H2 | Not prepared, and the RSS has a transcript                       | A loading indicator and, in a few seconds, everything ready. The audio isn't transcribed  |
| H3 | Not prepared, the RSS has no transcript and the audio is ≤ 25 MB | A longer loading indicator (the audio gets transcribed) and then everything ready at once |

### Edge cases

There are things that can go wrong. For each one, the user has to see something clear, not a blank
screen. But clear isn't the same as detailed: the message doesn't name the provider, the key or
technical limits. Knowing which API failed doesn't help the listener, and it helps someone who wants
to attack the app way too much. The detail goes to the log with `addError`, which is where I look for
it:

| #   | Situation                                                         | What the user sees                                                           |
|-----|-------------------------------------------------------------------|------------------------------------------------------------------------------|
| E1  | No key configured                                                 | "AI Companion isn't available right now". No call is made                    |
| E2  | The key isn't valid                                               | "AI Companion isn't available right now"                                     |
| E3  | Rate limit hit or quota used up                                   | "AI Companion is busy. Try again later"                                      |
| E4  | The audio is over 25 MB and the RSS has no transcript             | "This episode is too long for AI Companion". Nothing is uploaded             |
| E5  | Offline and no cache                                              | "No connection. Check your internet and try again" + "Retry"                 |
| E6  | Offline, with the episode cached                                  | Works as usual (H1)                                                          |
| E7  | The download, the transcription or the summary fails              | "Couldn't prepare AI Companion" + "Retry". Nothing is saved                  |
| E8  | The user leaves the player while it's getting ready               | Nothing. When they come back, it starts from zero                            |
| E9  | The episode is only music or silence                              | "Not enough spoken audio in this episode"                                    |
| E10 | The transcribed duration and the player's differ by more than 3 s | Everything works, with the "Sync may be approximate for this episode" notice |
| E11 | What's saved is corrupted or from an older version                | It gets prepared again, as if there were no cache                            |
| E12 | Two podcasts use the same episode identifier                      | Each one has its own AI Companion, without mixing                            |
| E13 | The user jumps to a music stretch                                 | The music section (♪) is highlighted, without moving to another sentence    |

## User stories

**US1 · Synced transcript without stutters.** As a listener, I want to see what's being said while I
listen, without the app stuttering.
- **Given** AI Companion is ready, **when** the audio moves forward, **then** the current sentence is
  highlighted.
- **Given** the audio is still inside the same sentence, **when** it moves forward, **then** the list
  isn't repainted. It only changes when the sentence changes.
- **Given** a duration mismatch (E10), **when** I look at the transcript, **then** the approximate
  sync notice shows up.
- **Given** AI Companion is ready, **when** I jump to another part of the audio, **then** the
  transcript moves to the sentence at that position and that sentence becomes the active one.
- **Given** AI Companion is getting ready, **when** I jump to another part of the audio, **then**
  when it finishes it opens at the sentence at that position, not the first one.
- **Given** AI Companion is ready, **when** I jump to a music stretch, **then** the music section is
  highlighted (E13).

**US2 · Jump by tapping a sentence or a chapter.** As a listener, I want to tap a sentence or a
chapter to go to that moment.
- **Given** AI Companion is ready, **when** I tap a sentence or a chapter, **then** the audio jumps
  to its start and that sentence becomes the active one.

**US3 · Read the debrief.** As a listener, I want a summary and chapters with real times to know what
the episode is about.
- **Given** AI Companion is ready, **when** I open the sheet, **then** I see the summary and the
  chapters, each one with its start time.

**US4 · Saved complete or not at all.** As a listener, I want an episode that's already prepared to
open instantly, with no half-saved data if I leave early.
- **Given** an episode with no cache, **when** it finishes getting ready, **then** next time it opens
  instantly, offline.
- **Given** an episode that's getting ready, **when** I leave the player, **then** nothing is saved.

**US5 · Use the podcast's transcript.** As a listener, I want to take advantage of the official
transcript when the podcast publishes one.
- **Given** an episode with a transcript in its RSS, **when** AI Companion gets ready, **then** the
  audio isn't downloaded or transcribed.

**US6 · Clear messages and retry.** As a reviewer or listener, I want to know what failed and be able
to retry.
- **Given** the key is missing, **when** I open AI Companion, **then** I see it isn't available,
  with no technical details (E1).
- **Given** audio over 25 MB with no transcript, **when** I open AI Companion, **then** I see the
  episode is too long (E4).
- **Given** a network or AI service error, **when** I tap "Retry", **then** the process starts again.

**US7 · It only starts if I ask.** As a listener, I want AI Companion to get ready only when I open
it, so nothing is spent if I opened an episode by accident.
- **Given** an episode with no cache, **when** I open the player and don't tap "AI Companion",
  **then** nothing is downloaded, transcribed or summarized.
- **Given** an episode in the player, **when** I tap "AI Companion", **then** the sheet opens and AI
  Companion starts getting ready (or shows up instantly if it's cached).

## How to try it (reviewer)

I tried to keep the steps you need to take as few as possible. Here they are:

1. Create a key at `platform.openai.com/api-keys`.
2. Copy `.env.example` to `.env` and put your key in it: `OPENAI_API_KEY=sk-...`. `.env` is in
   `.gitignore`, so your key never ends up in a commit.
3. Run `fvm flutter run --dart-define-from-file=.env`.
4. Open an episode and tap the "AI Companion" button below the controls. To see each path:
   - **H2:** a podcast that publishes a transcript in its RSS.
   - **H3:** a short episode, under ~25 min.
   - **E4:** a long one with no transcript.
   - **E1:** run it without `.env`.

## What's left out of the MVP

There are things I would have liked to add, and I felt like getting my hands dirty. But an MVP has to
prove certain things and ship in the shortest time possible, so I apply KISS. This is what I let go,
knowing I let it go:

- Episodes over 25 MB with no transcript in the RSS (the audio would have to be chopped on a server).
- Seeing part of AI Companion while the rest gets ready.
- Keeping the preparation going after closing the player.
- A cache shared between users. Today each device pays for its own process.
- Detecting ads, usage metrics, warning about mobile data.
- RSS transcripts in formats other than SRT and VTT.

### What I would do in production

With thousands of users, I'd change the approach: think per podcast, not per user. If 10,000 users
open the same episode, does it make sense to transcribe and summarize it 10,000 times? No.

- A backend with a shared cache: the first listener pays for the episode (and waits a bit longer), and
  the rest read it for free.
- Keys on the server, never inside the app.
- Groq (Whisper with open weights) + Claude Haiku 5.5. It's about 9 times cheaper on STT and doesn't
  depend on `whisper-1` shutting down on Feb 26, 2027.
- Audio chopping and voice detection on the server, to accept episodes of any length.
- Keep the provider outside the app. If tomorrow we swap Groq for another one, or for our own model,
  the app doesn't even notice.

The numbers for each option are in [`costs/stt_costs.md`](costs/stt_costs.md) and
[`costs/llm_costs.md`](costs/llm_costs.md).
