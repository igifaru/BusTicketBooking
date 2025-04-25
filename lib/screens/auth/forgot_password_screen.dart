import 'package:flutter/material.dart';
import 'package:tickiting/screens/auth/verify_reset_code_screen.dart';
//import 'package:tickiting/utils/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> forgotPasswordFormKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void sendResetRequest() async {
    if (forgotPasswordFormKey.currentState != null &&
        forgotPasswordFormKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      try {
        // Simulate the API call for now
        await Future.delayed(const Duration(seconds: 2));

        // For demonstration purposes, always succeed
        final bool sendSuccess = emailController.text != 'fail@example.com';

        setState(() {
          isLoading = false;
        });

        if (sendSuccess) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        VerifyResetCodeScreen(email: emailController.text),
              ),
            );
          }
        } else {
          setState(() {
            errorMessage = 'Failed to send reset request. Please try again.';
          });
        }
      } catch (e) {
        setState(() {
          isLoading = false;
          errorMessage = 'An error occurred: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blue),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Forgot Password',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your email to reset your password',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Form(
              key: forgotPasswordFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : sendResetRequest,
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Send Reset Request'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Remember your password?'),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
