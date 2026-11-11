import 'package:bloc/bloc.dart';
import 'package:cabina/common/errors/exceptions.dart';
import 'package:cabina/player/ai_companion/data/ai_companion_repository.dart';
import 'package:cabina/player/ai_companion/models/episode_companion.dart';
import 'package:cabina/player/models/player_args.dart';
import 'package:equatable/equatable.dart';

part 'ai_companion_state.dart';

/// Prepares the AI Companion of the episode in [PlayerArgs], only when the
/// sheet asks for it. Lives as long as the player page: closing it stops the
/// preparation before the next paid call and before anything is cached.
class AICompanionCubit extends Cubit<AICompanionState> {
  AICompanionCubit({
    required AICompanionRepository repository,
    required PlayerArgs args,
  }) : _repository = repository,
       _args = args,
       super(const AICompanionState());

  final AICompanionRepository _repository;
  final PlayerArgs _args;

  /// Starts the preparation. Does nothing unless the status is `initial`, so
  /// a double tap or reopening the sheet never prepares twice.
  Future<void> start() async {
    if (state.status != AICompanionStatus.initial) return;
    await _prepare();
  }

  /// Prepares again after a failure. Does nothing unless the status is
  /// `error`.
  Future<void> retry() async {
    if (state.status != AICompanionStatus.error) return;
    await _prepare();
  }

  /// Cache, then transcript, then debrief. Emits `ready` before saving: the
  /// user doesn't wait for the cache.
  ///
  /// Checks [isClosed] after every stage, so a closed cubit makes no further
  /// request and saves nothing. The stage in flight finishes and is dropped,
  /// and so is its failure: a closed cubit can't emit, and nobody is left to
  /// show the error to.
  Future<void> _prepare() async {
    emit(state.copyWith(status: AICompanionStatus.loading, clearError: true));
    try {
      final cached = await _repository.loadCached(_args);
      if (isClosed) return;
      if (cached != null) {
        emit(
          state.copyWith(status: AICompanionStatus.ready, companion: cached),
        );
        return;
      }

      final transcript = await _repository.transcript(_args.episode);
      if (isClosed) return;
      final companion = await _repository.debrief(transcript);
      if (isClosed) return;
      emit(
        state.copyWith(status: AICompanionStatus.ready, companion: companion),
      );
      await _save(companion);
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(
        state.copyWith(
          status: AICompanionStatus.error,
          errorMessage: CabinaException.messageOf(error),
          canRetry: error is AICompanionException && error.canRetry,
        ),
      );
    }
  }

  /// Caches [companion]. A failure is only logged: the sheet stays `ready`,
  /// and losing the cache only means preparing again next time.
  Future<void> _save(EpisodeCompanion companion) async {
    try {
      await _repository.save(_args, companion);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }
}
