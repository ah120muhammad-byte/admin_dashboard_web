import 'package:flutter/material.dart';
import '../../../core/services/admin_settings_service.dart';

class SettingsScreenV2 extends StatefulWidget {
  final ValueChanged<String>? onThemeModeChanged;

  const SettingsScreenV2({
    super.key,
    this.onThemeModeChanged,
  });

  @override
  State<SettingsScreenV2> createState() => _SettingsScreenV2State();
}

class _SettingsScreenV2State extends State<SettingsScreenV2> {
  final _svc = AdminSettingsService();
  late Future<List<dynamic>> _future;

  AdminSettings? _a;
  StudentAppSettings? _s;
  bool saving = false;

  String theme = 'system';
  bool compact = false;
  bool analytics = true;
  bool maintenance = false;
  bool registration = true;
  bool notifications = true;
  bool forceUpdate = false;

  final appName = TextEditingController();
  final appVersion = TextEditingController();
  final maintMsg = TextEditingController();
  final announcement = TextEditingController();
  final minVersion = TextEditingController();
  final supportEmail = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    for (final controller in [
      appName,
      appVersion,
      maintMsg,
      announcement,
      minVersion,
      supportEmail,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<List<dynamic>> _load() => Future.wait([
        _svc.getAdminSettings(),
        _svc.getStudentSettings(),
      ]);

  void _fill(List<dynamic> data) {
    if (_a != null) return;

    _a = data[0] as AdminSettings;
    _s = data[1] as StudentAppSettings;

    theme = _a!.themeMode;
    compact = _a!.sidebarCompact;
    analytics = _a!.analyticsEnabled;

    appName.text = _s!.appName;
    appVersion.text = _s!.appVersion;
    maintenance = _s!.maintenanceMode;
    maintMsg.text = _s!.maintenanceMessage;
    registration = _s!.allowRegistration;
    notifications = _s!.notificationsEnabled;
    announcement.text = _s!.homeAnnouncement;
    minVersion.text = _s!.minimumSupportedVersion;
    forceUpdate = _s!.forceUpdate;
    supportEmail.text = _s!.supportEmail;
  }

  Future<void> _saveTheme(String value) async {
    if (_a == null || saving) return;

    setState(() {
      theme = value;
    });

    widget.onThemeModeChanged?.call(value);

    try {
      await _svc.updateAdminSettings(
        id: _a!.id,
        themeMode: value,
        sidebarCompact: compact,
        analyticsEnabled: analytics,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        theme = _a!.themeMode;
      });
      widget.onThemeModeChanged?.call(_a!.themeMode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Theme update failed: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (_a == null || _s == null) return;

    setState(() {
      saving = true;
    });

    try {
      await Future.wait([
        _svc.updateAdminSettings(
          id: _a!.id,
          themeMode: theme,
          sidebarCompact: compact,
          analyticsEnabled: analytics,
        ),
        _svc.updateStudentSettings(
          id: _s!.id,
          maintenanceMode: maintenance,
          maintenanceMessage: maintMsg.text.trim(),
          allowRegistration: registration,
          notificationsEnabled: notifications,
          homeAnnouncement: announcement.text.trim(),
          minimumSupportedVersion: minVersion.text.trim(),
          forceUpdate: forceUpdate,
          supportEmail: supportEmail.text.trim(),
          appName: appName.text.trim().isEmpty
              ? 'MediData'
              : appName.text.trim(),
          appVersion: appVersion.text.trim().isEmpty
              ? '1.0.0'
              : appVersion.text.trim(),
        ),
      ]);

      if (!mounted) return;

      setState(() {
        saving = false;
      });

      widget.onThemeModeChanged?.call(theme);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = t.colorScheme;

    return Material(
      color: s.surface,
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _future = _load();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            );
          }

          _fill(snapshot.data!);

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              Text(
                'Settings',
                style: t.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Control the Admin Dashboard and MediData student app centrally.',
                style: t.textTheme.bodyMedium?.copyWith(
                  color: s.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _card(
                context,
                'Admin Dashboard',
                [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      theme == 'dark'
                          ? Icons.dark_mode_rounded
                          : theme == 'light'
                              ? Icons.light_mode_rounded
                              : Icons.brightness_auto_rounded,
                    ),
                    title: const Text('Theme Mode'),
                    subtitle: Text(
                      switch (theme) {
                        'dark' => 'Dark theme',
                        'light' => 'Light theme',
                        _ => 'Follow system theme',
                      },
                    ),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: theme,
                        items: const [
                          DropdownMenuItem(
                            value: 'system',
                            child: Text('System'),
                          ),
                          DropdownMenuItem(
                            value: 'light',
                            child: Text('Light'),
                          ),
                          DropdownMenuItem(
                            value: 'dark',
                            child: Text('Dark'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  _saveTheme(value);
                                }
                              },
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compact Sidebar'),
                    value: compact,
                    onChanged: saving
                        ? null
                        : (value) {
                            setState(() {
                              compact = value;
                            });
                          },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Analytics'),
                    value: analytics,
                    onChanged: saving
                        ? null
                        : (value) {
                            setState(() {
                              analytics = value;
                            });
                          },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _card(
                context,
                'Student App',
                [
                  TextField(
                    controller: appName,
                    decoration: const InputDecoration(labelText: 'App Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: appVersion,
                    decoration:
                        const InputDecoration(labelText: 'App Version'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Maintenance Mode'),
                    value: maintenance,
                    onChanged: saving
                        ? null
                        : (value) {
                            setState(() {
                              maintenance = value;
                            });
                          },
                  ),
                  if (maintenance)
                    TextField(
                      controller: maintMsg,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Maintenance Message',
                      ),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow Registration'),
                    value: registration,
                    onChanged: saving
                        ? null
                        : (value) {
                            setState(() {
                              registration = value;
                            });
                          },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Push Notifications'),
                    value: notifications,
                    onChanged: saving
                        ? null
                        : (value) {
                            setState(() {
                              notifications = value;
                            });
                          },
                  ),
                  TextField(
                    controller: announcement,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Home Announcement',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: minVersion,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Supported Version',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Force Update'),
                    value: forceUpdate,
                    onChanged: saving
                        ? null
                        : (value) {
                            setState(() {
                              forceUpdate = value;
                            });
                          },
                  ),
                  TextField(
                    controller: supportEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Support Email',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(saving ? 'Saving...' : 'Save All Settings'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
