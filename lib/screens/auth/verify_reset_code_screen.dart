import 'package:flutter/material.dart';

class VerifyResetCodeScreen extends StatelessWidget {
  final String email;

  const VerifyResetCodeScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Reset Code')),
      body: Center(child: Text('Verification screen for $email')),
    );
  }
}
