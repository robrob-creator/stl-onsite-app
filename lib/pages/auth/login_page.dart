import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:onstite/core/design_system.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/custom_pin_input.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late AuthController authController;

  @override
  void initState() {
    super.initState();
    authController = Get.find<AuthController>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                // Logo
                Image.asset(
                  'assets/images/logos/logo.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 40),
                // Sign in text
                Text(
                  'Enter Your PIN',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                // Subtitle with IMEI
                Text(
                  'Please enter your 6-digit PIN',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                //   if (authController.imei.value.isNotEmpty) ...[
                //     const SizedBox(height: 12),
                //     Container(
                //       padding: const EdgeInsets.symmetric(
                //         horizontal: 12,
                //         vertical: 8,
                //       ),
                //       decoration: BoxDecoration(
                //         color: Colors.grey[100],
                //         borderRadius: BorderRadius.circular(8),
                //       ),
                //       child: Text(
                //         'Device: ${authController.imei.value}',
                //         style: TextStyle(
                //           fontSize: 12,
                //           color: Colors.grey[600],
                //           fontFamily: 'monospace',
                //         ),
                //       ),
                //     ),
                //   ],
                const SizedBox(height: 24),
                // PIN Input Field
                CustomPinInput(
                  length: 6,
                  onChanged: (value) {
                    authController.mpin.value = value;
                  },
                  onComplete: () {
                    authController.login();
                  },
                ),
                const SizedBox(height: 24),
                // Loading indicator while logging in
                Obx(
                  () => authController.isLoading.value
                      ? const Column(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2563EB),
                                ),
                                strokeWidth: 2.5,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Logging in...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
