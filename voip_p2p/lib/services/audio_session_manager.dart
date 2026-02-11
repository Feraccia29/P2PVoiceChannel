import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

class AudioSessionManager {
  AudioSession? _session;

  /// Configura audio session per VoIP communication.
  /// Chiamare PRIMA di startLocalStream() per impostare il contesto audio corretto.
  Future<void> configure() async {
    if (kIsWeb) return;

    _session = await AudioSession.instance;

    await _session!.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
        flags: AndroidAudioFlags.none,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    await _session!.setActive(true);
  }

  /// Rilascia audio focus quando la chiamata termina.
  Future<void> deactivate() async {
    if (kIsWeb) return;
    await _session?.setActive(false);
  }
}
