part of 'library_cubit.dart';

/// Where the library's load is. Writes happen only while `ready`.
enum LibraryStatus { initial, loading, ready, error }

/// The user's subscriptions. `error` always carries [errorMessage]. While
/// `ready`, [errorMessage] reports the last failed write.
class LibraryState extends Equatable {
  const LibraryState({
    this.status = LibraryStatus.initial,
    this.podcasts = const [],
    this.errorMessage,
  });

  final LibraryStatus status;
  final List<SubscribedPodcast> podcasts;
  final String? errorMessage;

  bool isSubscribed(int id) => podcasts.any((podcast) => podcast.id == id);

  LibraryState copyWith({
    LibraryStatus? status,
    List<SubscribedPodcast>? podcasts,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LibraryState(
      status: status ?? this.status,
      podcasts: podcasts ?? this.podcasts,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, podcasts, errorMessage];
}
