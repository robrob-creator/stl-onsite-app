import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _circleDrawController;
  late AnimationController _mountainController;
  late AnimationController _smalltownController;
  late AnimationController _lotteryController;
  late AnimationController _circleScaleController;

  late Animation<double> _circleDrawAnimation;
  late Animation<double> _mountainAnimation;
  late Animation<double> _smalltownAnimation;
  late Animation<double> _lotteryAnimation;
  late Animation<double> _circleScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Red circle reveal animation - starts immediately
    _circleDrawController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _circleDrawAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _circleDrawController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Circle scale animation
    _circleScaleController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );
    _circleScaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _circleScaleController, curve: Curves.easeInOut),
    );

    // Mountain/House/Sun animation: bounces in
    _mountainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _mountainAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mountainController, curve: Curves.elasticOut),
    );

    // SMALLTOWN text animation - slides in from left
    _smalltownController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _smalltownAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _smalltownController, curve: Curves.easeOut),
    );

    // LOTTERY text animation - slides in from right
    _lotteryController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _lotteryAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _lotteryController, curve: Curves.easeOut),
    );

    // Start non-overlapping animation sequence
    _circleDrawController.forward();
    _circleScaleController.forward();

    // Mountain bounces after circle completes (1500ms)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _mountainController.forward();
    });

    // Small Town slides in after mountain completes (1500ms + 1200ms)
    Future.delayed(const Duration(milliseconds: 2700), () {
      if (mounted) _smalltownController.forward();
    });

    // Lottery slides in after smalltown completes (2700ms + 900ms)
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) _lotteryController.forward();
    });

    // Navigate after animations complete
    _navigateBasedOnSession();
  }

  @override
  void dispose() {
    _circleDrawController.dispose();
    _mountainController.dispose();
    _smalltownController.dispose();
    _lotteryController.dispose();
    _circleScaleController.dispose();
    super.dispose();
  }

  void _navigateBasedOnSession() {
    Future.delayed(const Duration(milliseconds: 4600), () {
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Red circle with drawing animation
              AnimatedBuilder(
                animation: Listenable.merge([
                  _circleDrawAnimation,
                  _circleScaleAnimation,
                ]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _circleScaleAnimation.value,
                    child: ClipPath(
                      clipper: CircleRevealClipper(
                        progress: _circleDrawAnimation.value,
                      ),
                      child: Image.asset(
                        'assets/images/logos/logo-red-circle.png',
                        width: 280,
                        height: 280,
                      ),
                    ),
                  );
                },
              ),
              // Mountain/House/Sun element - bounces
              AnimatedBuilder(
                animation: _mountainAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _mountainAnimation.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale:
                          0.85 +
                          (_mountainAnimation.value.clamp(0.0, 1.0) * 0.15),
                      child: Image.asset(
                        'assets/images/logos/logo-mountain-house-sun.png',
                        width: 280,
                        height: 280,
                      ),
                    ),
                  );
                },
              ),
              // SMALLTOWN text element - enters from left
              AnimatedBuilder(
                animation: _smalltownAnimation,
                builder: (context, child) {
                  final progress = _smalltownAnimation.value.clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset((-1 + progress) * 150, 0),
                    child: Opacity(
                      opacity: progress,
                      child: Image.asset(
                        'assets/images/logos/logo-small-town.png',
                        width: 280,
                        height: 280,
                      ),
                    ),
                  );
                },
              ),
              // LOTTERY text element - enters from right
              AnimatedBuilder(
                animation: _lotteryAnimation,
                builder: (context, child) {
                  final progress = _lotteryAnimation.value.clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset((1 - progress) * 150, 0),
                    child: Opacity(
                      opacity: progress,
                      child: Image.asset(
                        'assets/images/logos/logo-lottery.png',
                        width: 280,
                        height: 280,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom clipper that reveals the circle progressively like it's being drawn
class CircleRevealClipper extends CustomClipper<Path> {
  final double progress;

  CircleRevealClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final path = Path();

    // If animation is complete, return full circle
    if (progress >= 0.99) {
      path.addOval(Rect.fromCircle(center: center, radius: radius));
      return path;
    }

    // Animate the sweep angle (0 to 2π)
    final sweepAngle = progress * 2 * 3.14159265359;

    // Draw pie slice that reveals the circle
    path.moveTo(center.dx, center.dy);
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159265359 / 2, // Start from top
      sweepAngle,
      false,
    );
    path.lineTo(center.dx, center.dy);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CircleRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
