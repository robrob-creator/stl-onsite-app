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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Top spacing
                const SizedBox(height: 48),
                
                // Logo with subtle shadow
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logos/logo.png',
                    width: 120,
                    height: 120,
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Main heading
                Text(
                  'Enter Your PIN',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                // Subtitle description
                Text(
                  'Please enter your 6-digit PIN to continue',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // PIN Input Field Container with subtle background
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppLayout.largeBorderRadius),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Obx(
                    () => AbsorbPointer(
                      absorbing: authController.isLoading.value,
                      child: Opacity(
                        opacity: authController.isLoading.value ? 0.5 : 1.0,
                        child: CustomPinInput(
                          length: 6,
                          onChanged: (value) {
                            authController.mpin.value = value;
                          },
                          onComplete: () {
                            if (!authController.isLoading.value) {
                              authController.login();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Loading indicator section - Enhanced visibility
                Obx(
                  () => authController.isLoading.value
                      ? Column(
                          children: [
                            // Animated loading circle
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                              child: const SizedBox(
                                height: 40,
                                width: 40,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                  strokeWidth: 3.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Authenticating...',
                              style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Verifying your device and PIN',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
