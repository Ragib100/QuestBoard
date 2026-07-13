import 'package:flutter/material.dart';
import '../services/common/auth_service.dart';
import './auth/login.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Login()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: const Center(child: Text('Welcome to the Dashboard!')),
    );
  }
}
