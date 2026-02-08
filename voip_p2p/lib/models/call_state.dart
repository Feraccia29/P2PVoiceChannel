enum CallState {
  idle,
  connecting,
  connected,
  disconnecting,
  error,
}

class CallStateModel {
  final CallState state;
  final String? errorMessage;
  final bool isMuted;

  CallStateModel({
    this.state = CallState.idle,
    this.errorMessage,
    this.isMuted = false,
  });

  CallStateModel copyWith({
    CallState? state,
    String? errorMessage,
    bool? isMuted,
  }) {
    return CallStateModel(
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
