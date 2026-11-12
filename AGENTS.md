# Cabina

Podcast player for iOS and Android: search iTunes, browse a show's RSS feed, stream episodes, keep a
library of subscribed shows.

## Stack
- Flutter 3.41.9 pinned with FVM (`.fvmrc`). The SDK and Very Good CLI (1.2.0) are not upgraded:
  ignore the CLI's update prompt.
- Gates run only with `fvm flutter analyze`, `fvm dart format` and `fvm flutter test`.

## Project map
```
lib/
  bootstrap.dart   Bloc observer, LocalStorage, ApiClient, runApp
  app/             CabinaApp + AppDependencyInjection (app-scoped providers)
  common/          Shared code. Never imports a feature
    errors/        CabinaException hierarchy
    extensions/    DurationFormat (.clock, .human)
    network/       ApiClient: http + timeout, failures mapped to CabinaException
    observers/     AppBlocObserver: logs whatever blocs pass to addError
    parsers/       ItunesDurationParser, Rfc822DateParser
    services/      ItunesSearchService (shared by discover, search and show_detail)
    storage/       LocalStorage: async key/value, failures mapped to StorageException
    theme/         AppTheme (ThemeExtension, context.appTheme), AppColors, AppTextStyles
    widgets/       PosterImage, LoaderView, ErrorView, EmptyView
  discover/        Featured grid + favourites (DiscoverCubit)
  search/          Debounced iTunes search (SearchBloc)
  show_detail/     Show detail from the RSS feed (ShowDetailBloc, RssFeedService, RssFeedParser)
  player/          Audio playback (PlayerBloc over just_audio)
    ai_companion/  Sub-feature: synced transcript, summary and chapters (planned, docs/ai_companion/)
  library/         Subscribed shows (LibraryCubit, app-scoped: the tab and SubscribeButton share it)
  home/            Bottom-nav shell
  router/          RouterBuilder: only lists each page's route(). Still in common/router/ (Known debt)
test/              Mirrors lib/ (see Known debt)
docs/<feature>/    plan/: one plan per change (NN_implementation_plan.md), in the format under Workflow
docs/tasks/        technical_debt.md: known issues and their status (source of truth)
```

## Feature anatomy
```
lib/<feature>/
  cubit/ | bloc/   <feature>_cubit.dart or <feature>_bloc.dart, with <feature>_state.dart as a
                   part file (a bloc adds <feature>_event.dart)
  data/            <feature>_repository.dart
    services/      data sources: network, local storage or an SDK
    models/        DTOs: a provider's wire shapes (json_serializable), one file per shape. Never
                   leave data/; parsers map them to the feature's models/
    parsers/       raw payload → model
    prompts/       what an AI model is asked: instructions and the schema of its answer, as consts
  models/
  views/           <feature>_page.dart
  widgets/         one public widget per file; may group by area in subfolders (header/, summary/)
  <sub_feature>/   same anatomy, for a feature that only lives inside its parent's page
```

## Layers and DI
- View → Cubit/Bloc → Repository → Service. Widgets never touch a repository or a service.
- App-scoped services, repositories and blocs go in `AppDependencyInjection`. Route-scoped blocs, and
  the repository and services only they use, are created in the page's `route()`.
- Cabina's Page/View split: `static GoRoute route()` provides the bloc and the Page consumes it. No
  separate `XView` class. Every routed page declares `routeName`, `routePath` and `route()`;
  `RouterBuilder` only lists them. A tab (`DiscoverPage`, `LibraryPage`) has no route: `HomePage`
  owns it and builds the tabs.
- Repository and service:
  - A feature that wraps a single SDK or provider declares `abstract interface class
    <Feature>Repository` and the service implements it (`JustAudioPlayerService implements
    PlayerRepository`). The bloc depends on the repository. No pass-through class.
  - A feature whose repository sits over a shared service (discover, search over
    `ItunesSearchService`) or a service + parser (show_detail) uses a concrete repository, even if it
    only forwards today.
- A feature imports another feature only for its Page, to navigate. Other shared code follows the
  rule of three (Reuse before writing).
- A sub-feature nested in its parent (`lib/player/ai_companion/`) may also import the parent's bloc,
  state, models and widgets. Only its views and widgets read the parent bloc and add its events, never its
  cubit, and never the parent's repository or services. The parent imports the sub-feature only for
  its entry widget. That widget provides the sub-feature's own cubit, with the repository and
  services only it uses, so the parent's `route()` doesn't build them.

## State management
- Cubit by default. Use a Bloc only for (1) `bloc_concurrency` event transformers (see `SearchBloc`)
  or (2) traceability across several event sources, such as UI plus external streams (see
  `PlayerBloc`).
- State is one `Equatable` class with every field in `props`, a
  `<Feature>Status { initial, loading, ready, error }` enum when it loads async data (the player
  mirrors the engine with `PlayerStatus`), and, with an `errorMessage`,
  `copyWith(..., bool clearError = false)`. Never mutate the state or its lists.

## Errors
- Services and parsers throw `CabinaException` subtypes and keep the original as `cause`. `ApiClient`
  already maps http failures.
- Blocs and cubits: `on Object catch (error, stackTrace)` → `addError(error, stackTrace)` → emit
  `CabinaException.messageOf(error)` in `errorMessage`.
- A catch that drops data says why in the enclosing member's `///` (see
  `ItunesSearchService._tryParse`). Optional fields parse with `tryParse` and fall back to `null`.

## Reuse before writing
- Check `common/` (Project map) and `pubspec.yaml` before adding code or a package.
- Colors from `context.appTheme`, text styles from `AppTextStyles`.
- Rule of three: note the second copy in the plan's Out of scope, move it to `common/` at the third.

## Code rules
- Naming: `<X>Repository`, `<X>Service`, `<X>Parser`, `<X>Exception`. No `I` prefix.
- Every new public class gets a short `///` saying what it is for.
- User-facing text is hardcoded English. No l10n.
- No interfaces outside the repository rule, no pass-through wrappers, no parameters or branches for
  cases that don't exist yet, no unreachable fallbacks. Delete dead code.
- `_` for unused callback parameters.

## Tests
- Until a feature is refactored, add tests to its existing test file, even off the mirror path.
- Widget tests wrap in `MaterialApp(theme: AppTheme(isDark: false).toThemeData())`; there is no
  `pumpApp`.
- New or changed behaviour ships with a test that fails without the change.

## Known debt (don't copy)
Full list, targets and status: `docs/tasks/technical_debt.md`.

| Where            | Pattern not to copy                                                                                                                                                  |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `home/`          | Flat folder                                                                                                                                                          |
| `common/router/` | `RouterBuilder` in `common/`, so `common/` imports every feature page. Target: `lib/router/`                                                                         |
| `discover/`      | `DiscoverCubit` also owns favourites                                                                                                                                 |
| `show_detail/`   | `ShowDetailBloc` with a single event and no transformer                                                                                                              |
| Shared code      | `Podcast`, `Episode`, `ShowGrid`/`ShowCard`, `PlayerArgs`, `SubscribeButton` live in a feature but are used by others; `ItunesSearchService` imports discover        |
| DI               | Repositories of route-scoped blocs registered app-scoped                                                                                                             |
| Models           | Fields left out of `props`                                                                                                                                           |
| Pages, DI        | Unused callback params not named `_`                                                                                                                                 |
| `test/`          | Bloc and cubit tests at the feature root, not under `bloc/` or `cubit/`                                                                                              |
| `pubspec.yaml`   | `uuid` unused on purpose. Don't remove                                                                                                                               |

## Ask before acting
Stop and ask, don't infer from general Flutter knowledge, before:
- adding a dependency;
- adding to `common/` or adding a `CabinaException` subtype;
- choosing Cubit vs Bloc, or app-scoped vs route-scoped, when the rules above don't settle it;
- changing a public contract that another feature uses;
- a decision that would set a convention this file doesn't cover;
- code that disagrees with this file in a way `docs/tasks/technical_debt.md` doesn't list.

## Workflow
- Every new feature or refactor, and any bug fix that touches more than one of view, cubit/bloc,
  repository and service, or more than one feature, starts with a plan in
  `docs/<feature>/plan/NN_implementation_plan.md` (NN = next free number in that feature) and
  waits for approval before code changes. The plan format:
  ```
  # NN · <Title>: <one-line outcome>

  **Priority/Effort:** P0–P3 · XS|S|M|L  **Depends on:** <plans or none>
  **Status:** draft | approved | applied
  **Commit draft(s):** one per independent step

  ## Problem          findings, each with file:line; debt items as technical_debt.md:line, no IDs
  ## Decisions        | Decision | Choice | Why |, when there is a choice to make
  ## Fix              per step: what changes; code only where the shape isn't obvious
  ## Files            new / moved / edited / deleted
  ## Tests first      GIVEN/WHEN/THEN names per test file, and what each pins
  ## Audit checklist  how the result should land on the staged-audit categories
  ## Out of scope     found but not done, and why
  ## Verify           gates, then a manual check on a device
  ```
- Never commit or push. Draft commit messages as `type(scope): <gitmoji> summary.`, e.g.
  `fix(search): 🐛 clear stale error on retry.`
- Before handing off, the gates are green. Never run `git add`: say the change is ready to stage, and
  once the user stages it, run `staged-audit`.
- A change to a feature also fixes that feature's open issues in `docs/tasks/technical_debt.md`
  when the fix stays inside the feature (no other feature's contract changes). An issue whose fix
  crosses features goes to the plan's Out of scope.
- When a change clears a Known debt row or changes the project map, update this file in the same
  change, and mark the issue ✅ or 🟡 in `docs/tasks/technical_debt.md`.
- Skills live in `.agent/skills/<name>/SKILL.md`; `.claude/skills` is a local symlink to it. There is
  no `CLAUDE.md`.
