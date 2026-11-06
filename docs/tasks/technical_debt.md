# Technical Debt

Source of truth for known issues. One line each, `file:line` when it helps.

✅ done · 🟡 partial · ❌ open

## Player
- ❌ Playback scoped to `PlayerPage`. Needs one app-wide player, a "Now Playing" mini-player above the bottom nav and native media controls
- ✅ Going back from a podcast kept it playing → audio disposed on `AudioPlayerBloc.close`
- ❌ `await play()` never completes, it resolves when playback stops
- ❌ Play button on detail sometimes failing, probably the `await play()`
- ❌ Play/pause/seek/speed errors only logged, UI not updated. Handlers without `try`, only `open` maps to `CabinaPlayerException`
- ❌ `PlayerPage.route()` builds `AudioPlayerRepository(service: JustAudioPlayerService())` inline, no injection → refactor `PlayerPage` to the standard
- ❌ `IPlayerService` + pass-through `AudioPlayerRepository`, `I` prefix, files named `audio_player_*` → `PlayerRepository` implemented by `JustAudioPlayerService`, files `player_*`
- ❌ `audio_session` declared, not configured 

## Library
- ✅ Subscribing a new podcast and going back, library is not updated. `LibraryPage` loads once inside the `IndexedStack` → one app-scoped `LibraryCubit` shared by the tab and `SubscribeButton`
- ✅ Library item tap doesn't open the podcast detail → `LibraryPage` pushes `ShowDetailPage` right away; for migrated entries without `feedUrl`, `ShowDetailRepository` looks it up through `lookupById`
- ✅ Singleton `LibraryStore` on raw prefs, no repository or cubit, flat folder → `LibraryCubit` → `LibraryRepository` → `LocalStorage`, feature anatomy
- ❌ `SubscribeButton` lives in library, only `show_detail` renders it
- ✅ Subscriptions saved as `id|title|author|artwork`: a corrupt entry broke the tab, and a title or author with `|` or `;` split wrong on the next load → JSON under `library_podcasts`, the old key migrated once and then deleted, bad entries skipped

## Discover & favourites
- ✅ Favourite tap on the listing not working. `toggleFavourite` mutates `favouriteIds` `const []` throws, and Equatable skips the emit → a new list on every toggle, emitted after the save
- ✅ Corrupt favourites in prefs → crash on startup → `DiscoverCubit.restoreFavourites` loads them as `[]`
- ❌ `DiscoverCubit` holds 2 features, discover + favourites → `FavouritesCubit`
- ✅ `unawaited(save)` drops the error in discover_cubit → `toggleFavourite` awaits the save, and a failure keeps the list and shows a SnackBar
- ❌ `ShowCard` uses `context.watch`, every card rebuilds on any Discover change
- ❌ Heart tap target is 32dp, under 48
- ❌ Grid heights uneven with 2-line titles
- ❌ No pagination. What happens with 100+ favourites?

## Search
- ✅ No debounce: every keystroke hit iTunes, out-of-order responses, stale results after clearing → debounce + `restartable`
- ✅ Stale `errorMessage` after a successful retry → `clearError`, and a new query is a full reset
- ❌ No retry and no clear button

## Show detail
- ❌ Detail page rebuilt on every podcast change
- ❌ Podcast without episodes shows only the header + "0 episodes", no empty view
- ✅ One broken item failed the whole feed → bad items skipped (`RssFeedParser`, `ItunesSearchService._tryParse`)
- ✅ Episodes sorted newest first
- ❌ `ShowDetailBloc` has a single event and no transformer → Cubit
- ❌ `state.extra!` null → crash in `ShowDetailPage` and `PlayerPage`. Unreachable today, no deep links

## Parsing & data
- ✅ iTunes duration badly parsed (`hh:mm`, `mm`) → `ItunesDurationParser`
- ❌ Named time zones other than UTC (`EST`, `PDT`) rejected → episode without date, sorted last
- ❌ `artworkUrl` checks null, never empty or invalid URLs
- 🟡 `Podcast`, `Episode` and `PodcastDetail` leave fields out of `props` → `PodcastDetail` fixed; `Podcast` and `Episode` still open
- ❌ `.g.dart` kept. Removing it means hand-writing `Podcast.fromJson`, its own refactor

## Errors
- ✅ `copyWith` kept the last error → `clearError` on every state
- ✅ Blocs only handled `CabinaException`, unexpected errors left the screen loading forever → `on Object catch` + `addError` + `messageOf`
- ✅ `CabinaException` hierarchy
- ✅ `AppBlocObserver` logs `onError` only. `onChange` would flood with position ticks
- ✅ Unreachable `errorMessage ??` fallbacks in 4 pages → `errorMessage!`, the state documents that the error status always carries it

## Architecture
- ❌ `SearchRepository`, `RssFeedService` and `ShowDetailRepository` are app-scoped, though only route-scoped blocs use them
- ✅ `SharedPreferences` without a wrapper, changing package means touching every direct use → `LocalStorage` in `common/storage/` (like `ApiClient`), concrete `<Feature>Repository` per feature
- ❌ Shared code inside features: `Podcast`, `Episode`, `ShowGrid`/`ShowCard`, `PlayerArgs`. `ItunesSearchService` imports discover → `common/`
- ❌ `home/` flat folder → `views/`
- ❌ `RouterBuilder` lives in `common/router/` and imports every feature page → `lib/router/`
- ❌ Listing and detail views mixed, no grouping by kind. Open question
- ✅ Each route declared on its page, `RouterBuilder` only lists them
- ✅ `CabinaApp` is stateful to keep the `GoRouter` across rebuilds
- ✅ `bloc_concurrency` where it's needed (`SearchBloc`)

## Code & tests
- 🟡 Missing docs across the app. New classes documented, many old ones still without `///`
- 🟡 Wildcards for unused params. `PosterImage` done, DI and pages still use `ctx`/`context`
- ❌ Private named params (`required this._repository`) not adopted
- 🟡 Dead code. `hive` and `cupertino_icons` removed. `DiscoverRepository.search`, `ApiClient.dispose`, `PlayerPosition.progress` and `ApiException.isRateLimited` still unused
- ❌ Bloc and cubit tests at the feature root, not under `bloc/` or `cubit/`
- ❌ Hardcoded colors outside the theme: `show_card.dart:46,50`, `player_controls.dart:77`
- ❌ `uuid` declared but unused, for an upcoming feature. Don't remove
- ✅ No l10n. English only, by decision
