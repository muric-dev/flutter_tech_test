import 'dart:async';

import 'package:cabina/common/theme/app_theme.dart';
import 'package:cabina/common/widgets/poster_image.dart';
import 'package:cabina/common/widgets/status_views.dart';
import 'package:cabina/discover/models/podcast.dart';
import 'package:cabina/library/cubit/library_cubit.dart';
import 'package:cabina/library/models/subscribed_podcast.dart';
import 'package:cabina/show_detail/views/show_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Library tab: the subscribed shows, oldest first. Loads the app-scoped
/// [LibraryCubit], opens a show's detail on tap and shows the cubit's write
/// errors as a SnackBar.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<LibraryCubit>().load());
  }

  /// Opens [item]'s detail. A subscription saved before feeds were stored
  /// goes with an empty feed URL, and the detail looks it up.
  void _open(SubscribedPodcast item) => unawaited(
    context.pushNamed(
      ShowDetailPage.routeName,
      extra: Podcast(
        id: item.id,
        title: item.title,
        author: item.author,
        feedUrl: item.feedUrl ?? '',
        artworkUrl: item.artworkUrl,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library', style: AppTextStyles.title)),
      body: BlocConsumer<LibraryCubit, LibraryState>(
        listenWhen: (previous, current) =>
            current.status == LibraryStatus.ready &&
            current.errorMessage != null &&
            current.errorMessage != previous.errorMessage,
        listener: (context, state) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!))),
        builder: (context, state) {
          switch (state.status) {
            case LibraryStatus.initial:
            case LibraryStatus.loading:
              return const LoaderView();
            case LibraryStatus.error:
              return ErrorView(
                message: state.errorMessage!,
                onRetry: () => context.read<LibraryCubit>().load(),
              );
            case LibraryStatus.ready:
              if (state.podcasts.isEmpty) {
                return const EmptyView(
                  message: 'Subscribe to a podcast to see it here',
                  icon: Icons.library_music_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.podcasts.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = state.podcasts[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: PosterImage(url: item.artworkUrl, size: 52),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Unsubscribe',
                      onPressed: () =>
                          context.read<LibraryCubit>().unsubscribe(item.id),
                    ),
                    onTap: () => _open(item),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
