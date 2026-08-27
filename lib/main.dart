import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin/layout/admin_shell.dart';
import '../admin/screens/admin_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://eoyehpqknyoksaxlvnwl.supabase.co',
    publishableKey:'sb_publishable_vkiv3hr00CNPiGJKlQosNw_oZEG81zZ',
  );

  final session =
      Supabase.instance.client.auth.currentSession;

  runApp(
    AdminApp(
      hasSession: session != null,
    ),
  );
}

class AdminApp extends StatelessWidget {
  final bool hasSession;

  const AdminApp({
    super.key,
    required this.hasSession,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediData Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: hasSession
          ? const AdminShell()
          : const AdminLoginScreen(),
    );
  }
}
