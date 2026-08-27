import 'package:flutter/material.dart';

import '../../../core/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _service = SettingsService();

  final _formKey = GlobalKey<FormState>();

  final _appNameController = TextEditingController();

  final _appVersionController = TextEditingController();

  AppSettings? _settings;

  bool _maintenanceMode = false;

  bool _allowRegistration = true;

  bool _loading = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _loadSettings();
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _appVersionController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadSettings() async {
    try {
      final settings = await _service.getSettings();

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = settings;

        _appNameController.text = settings.appName;

        _appVersionController.text = settings.appVersion;

        _maintenanceMode = settings.maintenanceMode;

        _allowRegistration = settings.allowRegistration;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showMessage('Error: $e');
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveSettings() async {
    if (_settings == null) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _service.updateSettings(
        id: _settings!.id,
        appName: _appNameController.text.trim(),
        appVersion: _appVersionController.text.trim(),
        maintenanceMode: _maintenanceMode,
        allowRegistration: _allowRegistration,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage('Settings saved successfully');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage('Error: $e');
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _settings == null
          ? Center(
              child: FilledButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'App Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ==================================================
                        // APP NAME
                        // ==================================================
                        TextFormField(
                          controller: _appNameController,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'App Name',
                            prefixIcon: Icon(Icons.apps_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter app name';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // ==================================================
                        // VERSION
                        // ==================================================
                        TextFormField(
                          controller: _appVersionController,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'App Version',
                            prefixIcon: Icon(Icons.numbers_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter app version';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // ==================================================
                        // MAINTENANCE
                        // ==================================================
                        Card(
                          child: SwitchListTile(
                            title: const Text('Maintenance Mode'),
                            subtitle: const Text(
                              'Temporarily disable normal app usage.',
                            ),
                            value: _maintenanceMode,
                            onChanged: _saving
                                ? null
                                : (value) {
                                    setState(() {
                                      _maintenanceMode = value;
                                    });
                                  },
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // REGISTRATION
                        // ==================================================
                        Card(
                          child: SwitchListTile(
                            title: const Text('Allow Registration'),
                            subtitle: const Text(
                              'Allow new users to create accounts.',
                            ),
                            value: _allowRegistration,
                            onChanged: _saving
                                ? null
                                : (value) {
                                    setState(() {
                                      _allowRegistration = value;
                                    });
                                  },
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ==================================================
                        // SAVE
                        // ==================================================
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveSettings,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(_saving ? 'Saving...' : 'Save Settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
