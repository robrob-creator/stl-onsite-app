import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _opacityController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // Scale animation: Grows from 0.8 to 1.0
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Opacity animation: Fades from 0.0 to 1.0
    _opacityController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _opacityController, curve: Curves.easeIn),
    );

    // Start animations
    _scaleController.forward();
    _opacityController.forward();

    // Navigate after animations complete
    _navigateBasedOnSession();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  void _navigateBasedOnSession() {
    Future.delayed(const Duration(seconds: 3), () {
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
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _opacityAnimation]),
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Image.asset(
                    'assets/images/logos/logo.png',
                    width: 250,
                    height: 250,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
