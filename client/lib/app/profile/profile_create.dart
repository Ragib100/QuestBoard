import 'package:flutter/material.dart';

class ProfileCreate extends StatelessWidget {
  const ProfileCreate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Creating')),
      body: const Center(child: Text('This is the Profile Creating screen.')),
    );
  }
}
