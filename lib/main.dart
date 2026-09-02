import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_dashboard_web/admin/layout/admin_shell.dart';
import 'package:admin_dashboard_web/admin/layout/admin_theme.dart';
import 'package:admin_dashboard_web/admin/screens/admin_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://eoyehpqknyoksaxlvnwl.supabase.co',
    publishableKey: 'sb_publishable_vkiv3hr00CNPiGJKlQosNw_oZEG81zZ',
  );

  final client = Supabase.instance.client;
  final session = client.auth.currentSession;
  bool isAdmin = false;

  if (session != null) {
    try {
      final profile = await client
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();
      isAdmin = profile?['role']?.toString().toLowerCase().trim() == 'admin';
    } catch (_) {
      isAdmin = false;
    }
  }

  runApp(AdminApp(isAdmin: isAdmin));
}

class AdminApp extends StatelessWidget {
  final bool isAdmin;

  const AdminApp({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediData Admin',
      theme: AdminTheme.lightTheme,
      home: isAdmin ? const AdminShell() : const AdminLoginScreen(),
    );
  }
}
