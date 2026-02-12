import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UsernameDialog extends StatefulWidget {
  final String? initialUsername;
  final Function(String) onUsernameSaved;

  const UsernameDialog({
    super.key,
    this.initialUsername,
    required this.onUsernameSaved,
  });

  @override
  State<UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<UsernameDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUsername);
  }

  bool _isValid(String text) {
    return text.trim().length >= 2 && text.trim().length <= 20;
  }

  void _save() {
    final username = _controller.text.trim();
    if (_isValid(username)) {
      widget.onUsernameSaved(username);
      Navigator.of(context).pop();
    } else {
      setState(() {
        _errorText = 'Il nome deve essere tra 2 e 20 caratteri';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Text(
                'Scegli il tuo Username',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 20,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Username',
              errorText: _errorText,
              prefixIcon:
                  const Icon(Icons.edit, color: AppTheme.accentPurple),
              counterStyle: const TextStyle(color: Colors.white54),
            ),
            onChanged: (value) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('SALVA'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
