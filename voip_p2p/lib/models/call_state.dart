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
  final String? localUsername;
  final String? remoteUsername;
  final DateTime? connectedAt;

  CallStateModel({
    this.state = CallState.idle,
    this.errorMessage,
    this.isMuted = false,
    this.localUsername,
    this.remoteUsername,
    this.connectedAt,
  });

  CallStateModel copyWith({
    CallState? state,
    String? errorMessage,
    bool? isMuted,
    String? localUsername,
    String? remoteUsername,
    DateTime? connectedAt,
    bool clearConnectedAt = false,
    bool clearRemoteUsername = false,
    bool clearErrorMessage = false,
  }) {
    return CallStateModel(
      state: state ?? this.state,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isMuted: isMuted ?? this.isMuted,
      localUsername: localUsername ?? this.localUsername,
      remoteUsername:
          clearRemoteUsername ? null : (remoteUsername ?? this.remoteUsername),
      connectedAt:
          clearConnectedAt ? null : (connectedAt ?? this.connectedAt),
    );
  }
}
