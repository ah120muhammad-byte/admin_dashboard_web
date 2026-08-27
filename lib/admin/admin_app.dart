import 'package:flutter/material.dart';
import 'layout/admin_shell.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediData Admin',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const AdminShell(),
    );
  }
}