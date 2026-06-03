import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:onstite/controllers/auth_controller.dart';
import 'package:onstite/core/design_system.dart';
import 'package:onstite/routes/app_routes.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const Duration _minimumDisplayDuration = Duration(seconds: 3);

  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = Get.put(AuthController());
    _navigateBasedOnSession();
  }

  Future<void> _navigateBasedOnSession() async {
    await Future.delayed(_minimumDisplayDuration);

    while (mounted && !_authController.isSessionRestored.value) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    if (_authController.isLoggedIn) {
      Get.offNamed(AppRoutes.home);
      return;
    }

    Get.offNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortestSide = constraints.biggest.shortestSide;
            final animationSize = shortestSide * 0.92;

            return SizedBox.square(
              dimension: animationSize,
              child: const _SplashAnimation(),
            );
          },
        ),
      ),
    );
  }
}

class _SplashAnimation extends StatelessWidget {
  const _SplashAnimation();

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/animations/splash.json',
      repeat: false,
      fit: BoxFit.contain,
    );
  }
}
