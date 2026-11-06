# 01 · Library refactor: LibraryCubit over an agnostic LocalStorage, validated and migrated storage, tap opens the detail

**Priority/Effort:** P1 · L  **Depends on:** none
**Status:** applied
**Commit draft(s):**
1. `refactor(common): ♻️ wrap SharedPreferences in an async LocalStorage.`
2. `fix(discover): 🐛 emit a new favourites list on toggle and surface save errors.`
3. `refactor(library): ♻️ move library files to the feature anatomy.`
4. `refactor(library): ♻️ replace LibraryStore with an app-scoped LibraryCubit.`
5. `feat(library): ✨ migrate saved subscriptions to the JSON format.`
6. `feat(library): ✨ open the podcast detail on library item tap.`

## Problem
- `lib/library/library_store.dart:9-12`: singleton `LibraryStore` on raw `SharedPreferences`, no
  repository or cubit, flat folder (technical_debt.md:20, technical_debt.md:62).
- `lib/library/library_store.dart:27-36`: the `id|title|author|artwork` string isn't validated.
  `int.parse(parts[0])` or `parts[3]` throws on a corrupt entry and the Library tab breaks. A title
  or author containing `|` or `;` is saved fine but splits wrong on the next load.
- `lib/library/library_store.dart:14`: users already have subscriptions under
  `library_subscriptions` in that format. A new format must not lose them.
- `lib/library/library_store.dart:19`: `items` exposes the mutable `_items` list.
- `lib/library/subscribed_podcast.dart:5-17`: mutable fields, not `Equatable`, `//` instead of `///`,
  no `feedUrl`, so the library can't build the `Podcast` that `ShowDetailPage.route()` needs
  (`show_detail_page.dart:28`).
- `lib/library/library_page.dart:18-28`: `LibraryPage` loads once inside `HomePage`'s
  `IndexedStack`. A subscription made in the detail never shows up (technical_debt.md:18).
- `lib/library/library_page.dart:54-71`: `ListTile` without `onTap` (technical_debt.md:19).
- `lib/library/library_page.dart:31-34`, `widgets/subscribe_button.dart:38-53`: widgets talk to the
  store directly, and write failures are uncaught.
- `lib/library/widgets/subscribe_button.dart:9`: lives in library, only `show_detail` renders it
  (technical_debt.md:21).
- `lib/discover/data/favourites_repository.dart:9-22`: second direct `SharedPreferences` user
  (technical_debt.md:62). Its saved favourites must survive the swap.
- `lib/discover/data/favourites_repository.dart:18`, `lib/discover/cubit/discover_cubit.dart:19-27`:
  corrupt favourites JSON throws in `DiscoverCubit`'s constructor (technical_debt.md:25).
- `lib/discover/cubit/discover_cubit.dart:51-60`: `toggleFavourite` mutates `state.favouriteIds`.
  On the initial `const []`, `add` throws. On a mutable list it changes the same instance, so
  Equatable sees an equal state, nothing is emitted and the heart doesn't change
  (technical_debt.md:24). `unawaited(save)` drops write errors (technical_debt.md:27).
- `lib/common/services/itunes_search_service.dart:32-38`: `lookupById` returns `Future<Podcast?>`
  but never returns `null` (it throws), and it's unused (technical_debt.md:75).
- No `test/library/` at all. `FavouritesRepository` has no tests.

## Decisions
| Decision                          | Choice                                                                                                                                                                                                                                                                                                                                                                                                               | Why                                                                                                                                                                                                                                                                                                                    |
|-----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Storage wrapper                   | `common/storage/local_storage.dart`: concrete `LocalStorage` with `Future<String?> read(key)`, `Future<void> write(key, value)`, `Future<void> delete(key)`. The public API mentions no backend type, and the constructor takes `SharedPreferences`                                                                                                                                                                  | Agreed with the user. Swapping to Hive (or any async backend) touches `local_storage.dart`, its test and `bootstrap.dart`, not its callers. A concrete class like `ApiClient`: AGENTS.md allows no interface outside the repository rule                                                                               |
| Storage errors                    | New `StorageException extends CabinaException`. Every operation goes through one private guard: a throw becomes `StorageException` (original kept as `cause`), and so does a write or delete that returns `false`                                                                                                                                                                                                    | Agreed with the user. Callers handle one error type whatever the backend                                                                                                                                                                                                                                               |
| Format                            | New key `library_podcasts`, JSON list of objects, hand-written `SubscribedPodcast.fromJson`/`toJson`                                                                                                                                                                                                                                                                                                                 | Agreed with the user. JSON escapes `\|` and `;`                                                                                                                                                                                                                                                                        |
| Validation                        | Invalid JSON or a non-list loads as `[]`. Each entry `fromJson` rejects is skipped (like `ItunesSearchService._tryParse`). `fromJson` requires an `int` id and non-empty `String` title and author. `feedUrl` and `artworkUrl` are optional: a non-string or empty value becomes `null`                                                                                                                              | Agreed with the user. One bad entry doesn't empty the library                                                                                                                                                                                                                                                          |
| Legacy migration                  | `LibraryRepository.load()`: if `library_podcasts` exists, read it. Otherwise, if `library_subscriptions` exists, parse it, write it as JSON under the new key, then delete the old key. A legacy entry needs exactly 4 fields, an `int` id and non-empty title and author, or it's skipped (an entry whose title held `\|` or `;` can't be recovered). A failed write throws, and the old key stays for the next try | Agreed with the user: migrate, then delete. The parser is a private method of the repository: a one-off with a single caller                                                                                                                                                                                           |
| Missing feedUrl                   | Tapping an item opens `ShowDetailPage` right away. Without a stored `feedUrl`, `LibraryPage` passes `feedUrl: ''` and `ShowDetailRepository.loadDetail` looks it up with `ItunesSearchService.lookupById` before fetching the RSS, so the detail's loader covers both requests. The resolved URL isn't saved back to the library                                                                                     | Changed in the Step 5 review, agreed with the user: a small trailing icon turning into a spinner isn't the usual UX, the detail is what loads. `''` keeps `Podcast.feedUrl` non-null for discover, search and player (`_hasFeedUrl` already treats empty as missing). A migrated entry costs one extra lookup per open |
| Detail feed for SubscribeButton   | `PodcastDetail` carries `feedUrl` (the parsed feed's, after the lookup), and `show_detail_page.dart` builds the `SubscribeButton`'s `SubscribedPodcast` from it instead of the route's `Podcast`                                                                                                                                                                                                                     | Found in the Step 5 review. Unsubscribing and subscribing again from a migrated entry's detail stores the feed                                                                                                                                                                                                         |
| `lookupById`                      | `Future<Podcast>`: drop the unreachable nullable. Its existing tests already cover the throw                                                                                                                                                                                                                                                                                                                         | Agreed with the user. `ShowDetailRepository` becomes its first caller (technical_debt.md:75)                                                                                                                                                                                                                           |
| Favourites                        | `FavouritesRepository` moves to `LocalStorage` with the same key and format, and `load()` becomes async. A test seeded with what the old code wrote pins that they survive. `prefs` leaves `AppDependencyInjection` and `CabinaApp`, which take `localStorage`                                                                                                                                                       | Agreed with the user. Closes technical_debt.md:62                                                                                                                                                                                                                                                                      |
| Favourites restore                | `DiscoverCubit` stops restoring in its constructor. `Future<void> restoreFavourites()` is public, catches `on Object` → `addError`, and keeps `favouriteIds` as `[]` (drop documented in its `///`). `DiscoverPage.initState` calls it next to `loadFeatured`                                                                                                                                                        | Agreed with the user. Forced by async reads. Closes technical_debt.md:25                                                                                                                                                                                                                                               |
| Non-int favourite ids             | `FavouritesRepository.load` uses `List<int>.from` instead of `cast<int>()`, so a stored `[1,"a"]` throws inside `restoreFavourites` and lands as `[]`                                                                                                                                                                                                                                                                | Found in Step 1. `cast` is lazy: the bad id would pass the restore and throw later, on toggle or save. Keeps the restore Decision above true for every kind of corrupt data                                                                                                                                            |
| `LocalStorage` in DI              | A field of `AppDependencyInjection` passed straight to `FavouritesRepository`, not a `RepositoryProvider`                                                                                                                                                                                                                                                                                                            | Found in Step 1. Same as `ApiClient`: no widget can read the storage from the tree                                                                                                                                                                                                                                     |
| Toggle while featured isn't ready | `toggleFavourite` sets or clears `errorMessage` only while `status == ready`. In loading or error a success only emits the list and a failure only calls `addError`                                                                                                                                                                                                                                                  | Found in Step 1b, agreed with the user. Search's hearts call the toggle while Discover can be in error: `clearError` would null the message `ErrorView` force-unwraps (`errorMessage!`), and a failure would overwrite the featured error. Matches the SnackBar listener, which only fires while ready                 |
| `DiscoverPage` test in Step 1     | `test/discover/views/discover_page_test.dart` is created here with "WHEN pumped THEN loadFeatured and restoreFavourites called". Step 1b adds the SnackBar cases                                                                                                                                                                                                                                                     | Found in Step 1. The `initState` call is new behaviour and needs its own test                                                                                                                                                                                                                                          |
| Favourites toggle                 | `toggleFavourite` becomes `Future<void>`: it builds a new list, `await`s the save, then emits it with `clearError`. On failure the list stays as it was, `addError`, `errorMessage` with status still `ready`. Favourites stay in `DiscoverCubit`                                                                                                                                                                    | Agreed with the user. Same write order as Library. Closes technical_debt.md:24 and 27                                                                                                                                                                                                                                  |
| Favourites error UI               | One `BlocListener` in `DiscoverPage` shows a `SnackBar` when `errorMessage` changes while `ready`. The featured-load error keeps its `ErrorView`                                                                                                                                                                                                                                                                     | Agreed with the user. Same pattern as `LibraryPage`. `DiscoverPage` stays mounted under Search, so it covers the hearts there too                                                                                                                                                                                      |
| State mgmt                        | `LibraryCubit`. State is `LibraryStatus { initial, loading, ready, error }` + `podcasts` + `errorMessage`                                                                                                                                                                                                                                                                                                            | Cubit by default. The load is async                                                                                                                                                                                                                                                                                    |
| Load trigger                      | `LibraryPage.initState` → `unawaited(cubit.load())`, `ErrorView` with retry on `error`                                                                                                                                                                                                                                                                                                                               | Same as `DiscoverPage.initState` / `loadFeatured`                                                                                                                                                                                                                                                                      |
| Scope                             | `LibraryCubit` and `LibraryRepository(localStorage)`                app-scoped in `AppDependencyInjection`                                                                                                                                                                                                                                                                                                           | Agreed with the user. The tab and `show_detail`'s button share one cubit, which fixes the stale-library bug. `ItunesSearchService` is already app-scoped                                                                                                                                                               |
| Write order                       | Save, then emit. On failure, keep the old list, `addError`, emit `errorMessage` with status still `ready`. The next successful write clears it                                                                                                                                                                                                                                                                       | Agreed with the user. No revert logic                                                                                                                                                                                                                                                                                  |
| Error UI                          | Load error: `ErrorView`. Write error:            one `BlocListener` in `LibraryPage` shows a `SnackBar` when `errorMessage` changes while `ready`                                                                                                                                                                                                                                                                    | Agreed with the user. `LibraryPage` is always mounted and `ScaffoldMessenger` is app-wide, so it also shows over the detail. `home/` doesn't import the cubit                                                                                                                                                          |
| Navigation model                  | On tap, `LibraryPage` builds a `Podcast` from the `SubscribedPodcast` and `pushNamed(ShowDetailPage.routeName)`                                                                                                                                                                                                                                                                                                      | Agreed with the user. Importing discover's `Podcast` is the listed shared-model debt (technical_debt.md:63)                                                                                                                                                                                                            |
| SubscribeButton                   | Stays in `library/widgets/`, takes `SubscribeButton(podcast: SubscribedPodcast)`, reads `LibraryCubit`. `show_detail_page.dart:115` passes `feedUrl`                                                                                                                                                                                                                                                                 | Agreed with the user. Moving it would make `show_detail` import `LibraryCubit`                                                                                                                                                                                                                                         |
| Writes before the load            | `LibraryCubit` ignores `subscribe`/`unsubscribe` unless `ready`, and `SubscribeButton` is disabled until then                                                                                                                                                                                                                                                                                                        | Found in Step 3. Before the load ends, or after it fails, `podcasts` is `[]`: a save would overwrite the stored list, and after a failed migration the new key would win over the legacy one for good                                                                                                                  |
| Model validation                  | `SubscribedPodcast.fromJson` throws `FormatException`, and `LibraryRepository` skips only that                                                                                                                                                                                                                                                                                                                       | Found in Step 3. Same contract as Dart's own parsers. A narrow catch keeps a real bug visible                                                                                                                                                                                                                          |
| Failed legacy delete              | `load` throws after the JSON is saved, and the retry reads the new key                                                                                                                                                                                                                                                                                                                                               | Found in Step 4. No silent catch, and the migration stays idempotent                                                                                                                                                                                                                                                   |
| Repeated write error              | A failed write emits `clearError` before the new `errorMessage`                                                                                                                                                                                                                                                                                                                                                      | Found in the Step 3 audit. Equatable dropped a second identical message, so a second failed tap showed nothing                                                                                                                                                                                                         |
| Stays                             | List order (oldest first), unsubscribe without confirmation, the button's labels and icons, the tab's loader                                                                                                                                                                                                                                                                                                         | Behaviour unchanged                                                                                                                                                                                                                                                                                                    |

## Open questions
None. All of the above were answered before planning.

## Fix
**Step 0: pin.** `test/discover/data/favourites_repository_test.dart` against the current
prefs-based class (green on old code), seeded with the `favourite_podcast_ids` value the old code
wrote.

**Step 1: LocalStorage.**
- `common/errors/exceptions.dart`: `StorageException`.
- `common/storage/local_storage.dart`:
  ```dart
  /// App key/value storage. Callers see only strings and [StorageException], never the backend.
  class LocalStorage {
    LocalStorage({required SharedPreferences prefs}) : _prefs = prefs;
    Future<String?> read(String key) => _guard(() async => _prefs.getString(key));
    Future<void> write(String key, String value) => _guardWrite(() => _prefs.setString(key, value));
    Future<void> delete(String key) => _guardWrite(() => _prefs.remove(key));
  }
  ```
- `bootstrap.dart` builds `LocalStorage(prefs: prefs)`. `CabinaApp` and `AppDependencyInjection`
  take `localStorage` instead of `prefs` and provide it.
- `FavouritesRepository({required LocalStorage localStorage})`, `Future<List<int>> load()`,
  `save` → `write`. Step 0's test is adapted to `await` and stays green on the same seeded data.
- `DiscoverCubit.restoreFavourites()` replaces `_restoreFavourites()` in the constructor.
  `DiscoverPage.initState` calls it.

**Step 1b: favourites toggle.**
- `DiscoverCubit.toggleFavourite`: new list (`[...ids, id]` / `where`), `await
  _favouritesRepository.save`, emit, `try` as in Decisions. `ShowCard`'s `onTap` stays a fire-and-
  forget call (`unawaited`), and the error reaches the user through the state.
- `DiscoverPage`: `BlocBuilder` → `BlocConsumer` with the SnackBar listener.

**Step 2: move (no code change but imports).** `git mv` `library_page.dart` → `views/`,
`subscribed_podcast.dart` → `models/`. Fix imports in `home_page.dart` and the store.

**Step 3: cubit.**
- `models/subscribed_podcast.dart`: immutable `Equatable`, every field in `props`, nullable
  `feedUrl`, `fromJson`/`toJson`.
- `data/library_repository.dart`: `Future<List<SubscribedPodcast>> load()` (new key only in this
  step), `Future<void> save(List<SubscribedPodcast>)`, with the `///` on why bad data is dropped.
- `cubit/library_cubit.dart` + `library_state.dart` (part): `load()`, `subscribe(SubscribedPodcast)`
  (no-op if already there), `unsubscribe(int id)`, both ignored unless `ready`.
  `LibraryState.isSubscribed(int id)`.
- DI: `LibraryRepository` + `LibraryCubit` app-scoped.
- `LibraryPage`: loads in `initState`, `BlocConsumer` (initial/loading → `LoaderView`, error →
  `ErrorView`, ready → `EmptyView` or list; listener → SnackBar).
- `SubscribeButton`: `StatelessWidget`, `context.select` on `isSubscribed` and `ready` (disabled
  until then), calls the cubit.
- `show_detail_page.dart:115`: `SubscribeButton(podcast: SubscribedPodcast(…, feedUrl:
  podcast.feedUrl))`.
- Delete `library_store.dart`.

**Step 4: migration.** `LibraryRepository.load()` falls back to `library_subscriptions`: private
`_parseLegacy`, write as JSON, `delete` the old key.

**Step 5: tap.**
- `ItunesSearchService.lookupById` → `Future<Podcast>`.
- `ListTile.onTap` → `context.pushNamed(ShowDetailPage.routeName, extra: Podcast(..., feedUrl:
  item.feedUrl ?? ''))`. No state, no loader in the list.
- `ShowDetailRepository` takes `ItunesSearchService` (DI passes it). `loadDetail` looks up an
  empty `feedUrl` by id, then fetches and parses that podcast's feed.
- `PodcastDetail.feedUrl`, set by `RssFeedParser`, in `props` (with `descriptionHtml`).
  `show_detail_page.dart`'s `SubscribeButton` uses `detail.feedUrl` and `detail.podcastId`, so
  `_DetailContent` no longer takes the route's `Podcast`.

**Step 6: docs.** `AGENTS.md`: project map (`common/storage/`, `library/` line), remove the
`library/` and `Persistence` Known debt rows. technical_debt.md: lines 18, 19, 20, 24, 25, 27 and 62 ✅,
`lookupById` out of line 75, plus a ✅ line for the pipe-format bug and its migration.

## Files
- New: `lib/common/storage/local_storage.dart`, `lib/library/cubit/library_cubit.dart`,
  `lib/library/cubit/library_state.dart`, `lib/library/data/library_repository.dart`, and the tests
  below (including `test/discover/views/discover_page_test.dart`,
  `test/show_detail/data/show_detail_repository_test.dart` and
  `test/show_detail/views/show_detail_page_test.dart`).
- Moved: `lib/library/library_page.dart` → `lib/library/views/library_page.dart`,
  `lib/library/subscribed_podcast.dart` → `lib/library/models/subscribed_podcast.dart`.
- Edited: `lib/common/errors/exceptions.dart`, `lib/common/services/itunes_search_service.dart`,
  `lib/bootstrap.dart`, `lib/app/view/app.dart`, `lib/app/widgets/app_dependency_injection.dart`,
  `lib/discover/data/favourites_repository.dart`, `lib/discover/cubit/discover_cubit.dart`,
  `lib/discover/views/discover_page.dart`, `lib/home/home_page.dart` (import),
  `lib/show_detail/views/show_detail_page.dart`, `lib/show_detail/data/show_detail_repository.dart`,
  `lib/show_detail/models/podcast_detail.dart`, `lib/show_detail/data/parsers/rss_feed_parser.dart`,
  `lib/library/widgets/subscribe_button.dart`, `test/show_detail/show_detail_bloc_test.dart`,
  `test/show_detail/data/parsers/rss_feed_parser_test.dart`,
  `test/common/errors/exceptions_test.dart`, `test/discover/discover_cubit_test.dart`, `AGENTS.md`,
  `docs/tasks/technical_debt.md`.
- Deleted: `lib/library/library_store.dart`.

## Tests first
- `test/discover/data/favourites_repository_test.dart` (pins that favourites survive the swap)
  - GIVEN nothing stored WHEN load THEN returns []
  - GIVEN `favourite_podcast_ids` = `[1,2]` as the old code wrote it WHEN load THEN returns [1, 2]
  - GIVEN [3] saved WHEN load THEN returns [3]
- `test/discover/discover_cubit_test.dart` (existing file, root-level debt)
  - GIVEN stored favourites [1] WHEN restoreFavourites THEN favouriteIds [1]
  - GIVEN load throws WHEN restoreFavourites THEN addError and favouriteIds stays [] (fails on old
    code, where the constructor throws)
  - Existing tests: `load` stubbed with `thenAnswer`, and the "restored favourites" case seeds the
    state instead of relying on the constructor
  - GIVEN the initial state (`const []`) WHEN toggleFavourite(1) THEN emits [1] and saves [1] (fails
    on old code: `add` on a const list throws)
  - GIVEN favourites [1] WHEN toggleFavourite(1) THEN emits [] and saves []
  - GIVEN save throws WHEN toggleFavourite THEN favouriteIds unchanged, status ready, errorMessage
    set. GIVEN an error WHEN a later toggle succeeds THEN errorMessage cleared
- `test/discover/views/discover_page_test.dart`
  - GIVEN ready WHEN errorMessage emitted THEN SnackBar shows it. GIVEN status error THEN ErrorView
    and no SnackBar
- `test/common/storage/local_storage_test.dart`
  - GIVEN a stored value WHEN read THEN returns it. GIVEN none THEN null
  - GIVEN a value WHEN write then read THEN returns it
  - GIVEN a stored key WHEN delete THEN read is null
  - GIVEN the backend returns false WHEN write / delete THEN throws StorageException
  - GIVEN the backend throws WHEN read / write / delete THEN throws StorageException with that cause
- `test/common/errors/exceptions_test.dart`: messageOf returns StorageException's message.
- `test/common/services/itunes_search_service_test.dart`: unchanged; the `lookupById` cases now
  compile against the non-nullable type.
- `test/library/models/subscribed_podcast_test.dart`
  - GIVEN a podcast WHEN toJson then fromJson THEN equal (title with `|` and `;`)
  - GIVEN a missing/non-int id, empty title or author WHEN fromJson THEN throws
  - GIVEN feedUrl or artworkUrl missing, empty or not a string WHEN fromJson THEN null
- `test/library/data/library_repository_test.dart` (pins the corrupt-data bug and the migration)
  - GIVEN nothing stored WHEN load THEN []
  - GIVEN invalid JSON or a JSON object WHEN load THEN []
  - GIVEN one valid and one malformed entry WHEN load THEN only the valid one
  - GIVEN a list WHEN save THEN load returns it
  - GIVEN only `library_subscriptions` = `1|A|B|http://a.png;2|C|D|` WHEN load THEN both returned
    with feedUrl null and artworkUrl null for the second, `library_podcasts` holds them as JSON, and
    `library_subscriptions` is gone
  - GIVEN legacy entries with a non-int id, 3 fields or 5 fields WHEN load THEN those are skipped
  - GIVEN both keys WHEN load THEN the new key wins and the old one is untouched
  - GIVEN the migration write fails WHEN load THEN throws StorageException and
    `library_subscriptions` is kept
  - GIVEN the legacy delete fails WHEN load THEN throws StorageException after saving under
    `library_podcasts`
- `test/library/cubit/library_cubit_test.dart`
  - GIVEN stored podcasts WHEN load THEN loading, then ready with them
  - GIVEN load throws WHEN load THEN error with messageOf. GIVEN an error WHEN load succeeds THEN
    errorMessage cleared
  - GIVEN a new podcast WHEN subscribe THEN saved and emitted. GIVEN an already subscribed one
    THEN nothing is saved or emitted
  - WHEN unsubscribe THEN saved without it and emitted
  - GIVEN initial, loading or error WHEN subscribe THEN nothing is saved (pins the overwrite)
  - GIVEN save throws WHEN subscribe THEN list unchanged, status ready, errorMessage set. GIVEN an
    error WHEN a later write succeeds THEN errorMessage cleared
  - GIVEN an error WHEN another write fails with the same message THEN cleared, then set again
    (the SnackBar shows again)
- `test/library/views/library_page_test.dart`
  - WHEN pumped THEN cubit.load called. GIVEN loading THEN LoaderView. GIVEN error THEN ErrorView
    and retry calls load
  - GIVEN no podcasts THEN EmptyView. GIVEN podcasts THEN title and author rendered
  - WHEN remove tapped THEN cubit.unsubscribe(id)
  - WHEN an item with feedUrl is tapped THEN ShowDetailPage.routeName pushed with a Podcast
    carrying its feedUrl (fails on old code)
  - WHEN an item saved without feedUrl is tapped THEN pushed right away with `feedUrl: ''`
  - GIVEN errorMessage emitted while ready THEN SnackBar shows it
- `test/library/widgets/subscribe_button_test.dart`
  - GIVEN not subscribed WHEN tapped THEN subscribe(podcast). GIVEN subscribed WHEN tapped THEN
    unsubscribe(id)
  - GIVEN the library is loading THEN the button is disabled
  - GIVEN LibraryPage and SubscribeButton on one real LibraryCubit WHEN Subscribe tapped THEN the
    library list shows the podcast (pins the stale-library bug)
- `test/show_detail/data/show_detail_repository_test.dart`
  - GIVEN a feedUrl WHEN loadDetail THEN parses that feed without a lookup
  - GIVEN an empty feedUrl WHEN loadDetail THEN lookupById, then parses the returned feed, and
    `detail.feedUrl` is it (fails on old code: it fetched `''`)
  - GIVEN an empty feedUrl and the lookup throws WHEN loadDetail THEN it propagates, no fetch
- `test/show_detail/views/show_detail_page_test.dart`
  - GIVEN the route's feedUrl is empty and the detail loaded one WHEN Subscribe tapped THEN
    subscribe carries the loaded feedUrl
- `test/show_detail/data/parsers/rss_feed_parser_test.dart` (existing): `detail.feedUrl` is the
  podcast's

## Audit checklist
- Layers: no widget imports a repository, service or `SharedPreferences`. `shared_preferences` is
  imported only in `local_storage.dart` and `bootstrap.dart`.
- Agnostic storage: no `SharedPreferences` type or prefs-specific name (`getString`, `setString`) in
  `LocalStorage`'s public API.
- Errors: `StorageException` keeps `cause`. Cubits use `on Object catch` → `addError` →
  `messageOf`. Dropping data is documented in `LibraryRepository.load`'s and
  `DiscoverCubit.restoreFavourites`'s `///`.
- Migration: idempotent. A failed write keeps the old key. A failed `delete` leaves the old key
  orphaned but never reread, because the new key wins.
- State: immutable, every field in `props`, `clearError`. No mutation of lists.
- Docs: `///` on `LocalStorage`, `StorageException`, `SubscribedPodcast`, `LibraryRepository`,
  `LibraryCubit`, `LibraryState`, `SubscribeButton`, `LibraryPage`, `restoreFavourites`.
- Naming: `_` for unused callback params in touched code.

## Out of scope
- technical_debt.md:21: moving `SubscribeButton` out of library. `show_detail` would have to import
  `LibraryCubit`, which needs a shared-widget decision.
- technical_debt.md:26, 28: extracting favourites into a `FavouritesCubit`, and `ShowCard`'s
  `context.watch` rebuilding every card. The user kept favourites in `DiscoverCubit`. Both belong
  to the discover refactor.
- technical_debt.md:63: `Podcast` still lives in discover. Library now imports it to navigate.
- Wildcard `_` params in DI beyond the lines touched (technical_debt.md:73).
- Second copy of the write-error SnackBar `BlocConsumer` listener (`DiscoverPage`, `LibraryPage`).
  Rule of three: it moves to `common/` at the third.
- `DiscoverCubit.toggleFavourite` has the same "same message twice, no second SnackBar" gap that
  `LibraryCubit` fixes by clearing the error first. Discover's contract, so it goes to the discover
  refactor.
- `SubscribeButton` takes the detail's title and author as iTunes returns them. An empty one is
  saved, then skipped on the next load by `fromJson`. Not seen in practice, and guarding it means a
  rule for `show_detail`'s data.
- technical_debt.md:44: `ShowDetailBloc` → Cubit. Step 5 touches show_detail only at the
  repository, the model and one widget line; the bloc conversion belongs to the show_detail
  refactor.
- technical_debt.md:51: `Podcast` and `Episode` still leave fields out of `props`. Only
  `PodcastDetail`, which Step 5 changes, is fixed: `Podcast` is discover's and `Episode` the
  player's too.

## Verify
- `fvm dart format .`, `fvm flutter analyze`, `fvm flutter test`.
- Device, migration: install the current build, subscribe to two shows and favourite one. Install
  the new build: both shows are in Library, the favourite keeps its heart. Tap a migrated show:
  the detail opens right away and its loader covers the lookup and the feed. In airplane mode the
  detail shows the error with Retry. Unsubscribe and subscribe again from that detail: the next
  open needs no lookup.
- Device, favourites: tap the heart on a fresh install (empty favourites) and it fills. Tap it
  again and it empties. Restart the app and the state persists. Same from Search.
- Device, new flow: subscribe from a show's detail, go back, and the Library tab lists it right
  away. Restart the app: no duplicates, and the list persists.


## Usage
From `usage-ledger report` at hand-off (2026-11-06). USD is the API list-price equivalent, not
what was paid. Inventory and findings ran in one prompt, and steps 3+4 with their audit and
hand-off in another, so each group sits under its first phase (`inventory`, `apply-3-4`).

```
Feature / phase                             USD  Share  Questions   Calls   Tokens    Active
library          ████░░░░░░░░░░░░░░░░     25.07    19%         35     314    38.7M    1h 25m
  apply-0        █░░░░░░░░░░░░░░░░░░░      6.61     5%          2      48     9.0M       26m
  apply-1b       █░░░░░░░░░░░░░░░░░░░      5.45     4%         13      71     6.8M       15m
  apply-5        ░░░░░░░░░░░░░░░░░░░░      2.99     2%          3      43     5.4M        9m
  apply-3-4      ░░░░░░░░░░░░░░░░░░░░      2.81     2%          1      46     4.9M       11m
  audit-5        ░░░░░░░░░░░░░░░░░░░░      1.88     1%          5      30     5.2M        6m
  plan           ░░░░░░░░░░░░░░░░░░░░      1.87     1%          4      26     2.4M        7m
  apply-1        ░░░░░░░░░░░░░░░░░░░░      1.33     1%          3      19     1.6M        5m
  inventory      ░░░░░░░░░░░░░░░░░░░░      1.07     1%          1      15   955.4K        3m
  handoff-5      ░░░░░░░░░░░░░░░░░░░░      0.44     0%          1       8     1.1M        1m
  handoff        ░░░░░░░░░░░░░░░░░░░░      0.32     0%          1       5     1.1M        1m
  apply-2        ░░░░░░░░░░░░░░░░░░░░      0.31     0%          1       3   151.3K        0m
```
