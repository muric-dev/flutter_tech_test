import 'package:cabina/common/network/api_client.dart';
import 'package:cabina/common/services/itunes_search_service.dart';
import 'package:cabina/common/storage/local_storage.dart';
import 'package:cabina/discover/cubit/discover_cubit.dart';
import 'package:cabina/discover/data/discover_repository.dart';
import 'package:cabina/discover/data/favourites_repository.dart';
import 'package:cabina/library/cubit/library_cubit.dart';
import 'package:cabina/library/data/library_repository.dart';
import 'package:cabina/search/data/search_repository.dart';
import 'package:cabina/show_detail/data/parsers/rss_feed_parser.dart';
import 'package:cabina/show_detail/data/services/rss_feed_service.dart';
import 'package:cabina/show_detail/data/show_detail_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Wires the object graph (services → repositories → app-scoped blocs) using
/// `RepositoryProvider`/`BlocProvider`. Route-scoped blocs (search, show detail, player) are
/// created in each page's `route()`.
class AppDependencyInjection extends StatelessWidget {
  const AppDependencyInjection({
    required this.localStorage,
    required this.apiClient,
    required this.child,
    super.key,
  });

  final LocalStorage localStorage;
  final ApiClient apiClient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (ctx) => ItunesSearchService(apiClient: apiClient),
        ),
        RepositoryProvider(
          create: (ctx) => DiscoverRepository(
            searchService: ctx.read<ItunesSearchService>(),
          ),
        ),
        RepositoryProvider(
          create: (ctx) =>
              SearchRepository(searchService: ctx.read<ItunesSearchService>()),
        ),
        RepositoryProvider(
          create: (ctx) => RssFeedService(apiClient: apiClient),
        ),
        RepositoryProvider(
          create: (ctx) => ShowDetailRepository(
            feedService: ctx.read<RssFeedService>(),
            feedParser: const RssFeedParser(),
            searchService: ctx.read<ItunesSearchService>(),
          ),
        ),
        RepositoryProvider(
          create: (_) => FavouritesRepository(localStorage: localStorage),
        ),
        RepositoryProvider(
          create: (_) => LibraryRepository(localStorage: localStorage),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (ctx) => DiscoverCubit(
              discoverRepository: ctx.read<DiscoverRepository>(),
              favouritesRepository: ctx.read<FavouritesRepository>(),
            ),
          ),
          BlocProvider(
            create: (ctx) => LibraryCubit(
              libraryRepository: ctx.read<LibraryRepository>(),
            ),
          ),
        ],
        child: child,
      ),
    );
  }
}
