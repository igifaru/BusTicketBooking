import 'package:flutter/material.dart';
import 'package:tickiting/screens/auth/verify_reset_code_screen.dart';
//import 'package:tickiting/utils/theme.dart';
//import 'package:tickiting/utils/database_helper.dart';
//import 'package:tickiting/utils/email_service.dart';
//import 'package:tickiting/utils/sms_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Use a different name for the form key to avoid conflicts
  final GlobalKey<FormState> forgotPasswordFormKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';

  @override
  void dispose() {
    emailOrPhoneController.dispose();
    super.dispose();
  }

  void sendVerificationCode() async {
    // Check validation without using currentState
    if (forgotPasswordFormKey.currentState != null &&
        forgotPasswordFormKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      try {
        // Simulate the API call for now
        await Future.delayed(const Duration(seconds: 2));

        // For demonstration purposes, always succeed in development
        final Map<String, dynamic> result = {
          'success': true,
          'user_id': 1,
          'email': emailOrPhoneController.text,
          'phone': '1234567890',
          'name': 'Test User',
          'token': '123456',
        };
        final bool sendSuccess = result['success'] ?? false;

        setState(() {
          isLoading = false;
        });

        if (sendSuccess) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => VerifyResetCodeScreen(
                      userId: result['user_id'],
                      emailOrPhone: emailOrPhoneController.text,
                      verificationMethod: verificationMethod,
                    ),
              ),
            );
          }
        } else if (mounted) {
          setState(() {
            errorMessage =
                'Failed to send verification code. Please try again.';
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
              'Choose how to receive your code',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Verification method selector
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verification Method',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Email'),
                          value: 'email',
                          groupValue: verificationMethod,
                          onChanged: (value) {
                            setState(() {
                              verificationMethod = value!;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('SMS'),
                          value: 'phone',
                          groupValue: verificationMethod,
                          onChanged: (value) {
                            setState(() {
                              verificationMethod = value!;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
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
                    controller: emailOrPhoneController,
                    keyboardType:
                        verificationMethod == 'email'
                            ? TextInputType.emailAddress
                            : TextInputType.phone,
                    decoration: InputDecoration(
                      labelText:
                          verificationMethod == 'email'
                              ? 'Email'
                              : 'Phone Number',
                      prefixIcon: Icon(
                        verificationMethod == 'email'
                            ? Icons.email
                            : Icons.phone,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your ${verificationMethod == 'email' ? 'email' : 'phone number'}';
                      }

                      if (verificationMethod == 'email' &&
                          !RegExp(
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
                      onPressed: isLoading ? null : sendVerificationCode,
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
                              : const Text('Send Verification Code'),
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
