import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import '../models/call_state.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Consumer<CallProvider>(
        builder: (context, callProvider, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusIndicator(callProvider.callState.state),
                const SizedBox(height: 40),
                _buildMainButton(context, callProvider),
                const SizedBox(height: 20),
                if (callProvider.isConnected) _buildMuteButton(callProvider),
                if (callProvider.callState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      callProvider.callState.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator(CallState state) {
    String text;
    Color color;
    IconData icon;

    switch (state) {
      case CallState.idle:
        text = 'Disconnesso';
        color = Colors.grey;
        icon = Icons.radio_button_unchecked;
        break;
      case CallState.connecting:
        text = 'Connessione...';
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case CallState.connected:
        text = 'Connesso';
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case CallState.disconnecting:
        text = 'Disconnessione...';
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case CallState.error:
        text = 'Errore';
        color = Colors.red;
        icon = Icons.error;
        break;
    }

    return Column(
      children: [
        Icon(icon, size: 60, color: color),
        const SizedBox(height: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMainButton(BuildContext context, CallProvider provider) {
    final isIdle = provider.callState.state == CallState.idle;

    return ElevatedButton(
      onPressed: provider.isConnecting
          ? null
          : () {
              if (isIdle) {
                provider.connect();
              } else {
                provider.disconnect();
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isIdle ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Text(
        isIdle ? 'CONNETTI' : 'DISCONNETTI',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMuteButton(CallProvider provider) {
    return IconButton(
      onPressed: provider.toggleMute,
      icon: Icon(
        provider.callState.isMuted ? Icons.mic_off : Icons.mic,
        color: provider.callState.isMuted ? Colors.red : Colors.white,
      ),
      iconSize: 40,
    );
  }
}
