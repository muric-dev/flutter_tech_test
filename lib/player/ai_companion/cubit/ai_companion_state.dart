part of 'ai_companion_cubit.dart';

/// Where the episode's preparation is. `initial` until the sheet first opens.
enum AICompanionStatus { initial, loading, ready, error }

/// The AI Companion of the episode in the player. `ready` always carries
/// [companion]; `error` always carries [errorMessage], and [canRetry] says
/// whether the sheet offers "Retry".
class AICompanionState extends Equatable {
  const AICompanionState({
    this.status = AICompanionStatus.initial,
    this.companion,
    this.errorMessage,
    this.canRetry = false,
  });

  final AICompanionStatus status;
  final EpisodeCompanion? companion;
  final String? errorMessage;
  final bool canRetry;

  /// [clearError] drops [errorMessage] and [canRetry] together: one never
  /// outlives the other.
  AICompanionState copyWith({
    AICompanionStatus? status,
    EpisodeCompanion? companion,
    String? errorMessage,
    bool? canRetry,
    bool clearError = false,
  }) {
    return AICompanionState(
      status: status ?? this.status,
      companion: companion ?? this.companion,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      canRetry: !clearError && (canRetry ?? this.canRetry),
    );
  }

  @override
  List<Object?> get props => [status, companion, errorMessage, canRetry];
}
