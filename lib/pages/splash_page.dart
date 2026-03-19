import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateBasedOnSession();
  }

  void _navigateBasedOnSession() {
    Future.delayed(const Duration(seconds: 2), () {
      final authController = Get.put(AuthController());

      // Wait for session restoration to complete
      if (!authController.isSessionRestored.value) {
        _navigateBasedOnSession(); // Try again
        return;
      }

      // If already logged in, go to home
      if (authController.isLoggedIn) {
        Get.offNamed('/home');
      }
      // Otherwise go to login (IMEI + PIN)
      else {
        Get.offNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: Image.asset(
            'assets/images/logos/logo.png',
            width: 250,
            height: 250,
          ),
        ),
      ),
    );
  }
}
