import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../theme/app_theme.dart';
import '../services/audio_device_service.dart';
import '../utils/constants.dart';
import '../widgets/username_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final String? currentUsername;
  final ValueChanged<String>? onUsernameChanged;

  const SettingsScreen({
    super.key,
    this.currentUsername,
    this.onUsernameChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _username;
  List<MediaDeviceInfo> _inputDevices = [];
  List<MediaDeviceInfo> _outputDevices = [];
  String? _selectedInputDeviceId;
  String? _selectedOutputDeviceId;
  bool _loadingDevices = true;

  @override
  void initState() {
    super.initState();
    _username = widget.currentUsername;
    _loadAudioDevices();
  }

  Future<void> _loadAudioDevices() async {
    try {
      final inputDevices = await AudioDeviceService.getInputDevices();
      final outputDevices = await AudioDeviceService.getOutputDevices();
      final savedInputId = await AudioDeviceService.getPreferredInputDeviceId();
      final savedOutputId = await AudioDeviceService.getPreferredOutputDeviceId();
      if (mounted) {
        setState(() {
          _inputDevices = inputDevices;
          _outputDevices = outputDevices;
          _selectedInputDeviceId = savedInputId;
          _selectedOutputDeviceId = savedOutputId;
          _loadingDevices = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingDevices = false);
      }
    }
  }

  void _showUsernameDialog() {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UsernameDialog(
        initialUsername: _username,
        onUsernameSaved: (username) {
          setState(() => _username = username);
          widget.onUsernameChanged?.call(username);
        },
      ),
    );
  }

  Future<void> _onInputDeviceChanged(String? deviceId) async {
    setState(() => _selectedInputDeviceId = deviceId);
    await AudioDeviceService.setPreferredInputDeviceId(deviceId);
  }

  Future<void> _onOutputDeviceChanged(String? deviceId) async {
    setState(() => _selectedOutputDeviceId = deviceId);
    await AudioDeviceService.setPreferredOutputDeviceId(deviceId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppTheme.backgroundDark,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionTitle('Profilo'),
                    const SizedBox(height: 8),
                    _buildProfileSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Audio'),
                    const SizedBox(height: 8),
                    _buildAudioSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Info'),
                    const SizedBox(height: 8),
                    _buildInfoSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Text(
            'Impostazioni',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentPurple,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: child,
    );
  }

  Widget _buildProfileSection() {
    return _buildCard(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.accentGradient,
          ),
          child: Center(
            child: Text(
              (_username != null && _username!.isNotEmpty)
                  ? _username![0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          _username ?? 'Non impostato',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Username',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.edit, color: AppTheme.accentPurple, size: 20),
        onTap: _showUsernameDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
    );
  }

  Widget _buildAudioSection() {
    return _buildCard(
      child: Column(
        children: [
          _buildDeviceTile(
            icon: Icons.mic,
            title: 'Dispositivo input',
            devices: _inputDevices,
            selectedDeviceId: _selectedInputDeviceId,
            fallbackLabel: 'Microfono',
            onChanged: _onInputDeviceChanged,
          ),
          const Divider(color: AppTheme.borderColor, height: 1),
          _buildDeviceTile(
            icon: Icons.headphones,
            title: 'Dispositivo output',
            devices: _outputDevices,
            selectedDeviceId: _selectedOutputDeviceId,
            fallbackLabel: 'Speaker',
            onChanged: _onOutputDeviceChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile({
    required IconData icon,
    required String title,
    required List<MediaDeviceInfo> devices,
    required String? selectedDeviceId,
    required String fallbackLabel,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accentPurple),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: _loadingDevices
          ? const Text('Caricamento...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
          : null,
      trailing: _loadingDevices
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accentPurple,
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selectedDeviceId,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardBackground,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Default', overflow: TextOverflow.ellipsis),
                    ),
                    ...devices.map((device) => DropdownMenuItem<String?>(
                          value: device.deviceId,
                          child: Text(
                            device.label.isNotEmpty ? device.label : '$fallbackLabel ${device.deviceId.substring(0, 4)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
    );
  }

  Widget _buildInfoSection() {
    return _buildCard(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppTheme.accentPurple),
            title: const Text(
              'Versione',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            trailing: const Text(
              '1.0.0',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          const Divider(color: AppTheme.borderColor, height: 1),
          ListTile(
            leading: const Icon(Icons.dns_outlined, color: AppTheme.accentPurple),
            title: const Text(
              'Server',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            trailing: const Text(
              AppConstants.signalingServerUrl,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          const Divider(color: AppTheme.borderColor, height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined, color: AppTheme.accentPurple),
            title: const Text(
              'Licenze open source',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'P2P Voice Channel',
                applicationVersion: '1.0.0',
              );
            },
          ),
        ],
      ),
    );
  }
}
