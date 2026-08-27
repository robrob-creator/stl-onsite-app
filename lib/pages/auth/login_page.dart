import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/custom_pin_input.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late AuthController authController;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    authController = Get.find<AuthController>();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _appVersion = 'v${info.version}+${info.buildNumber}');
      final buildNumber = int.tryParse(info.buildNumber) ?? 0;
      authController.checkAppVersionFromLogin(buildNumber);
    });
  }

  void _showImeiDialog(BuildContext context, AuthController ctrl) {
    bool useCustom = ctrl.isUsingCustomImei;
    final customCtrl = TextEditingController(
      text: useCustom ? ctrl.imei.value : '',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Device ID',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Switch to default
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setS(() => useCustom = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: !useCustom
                        ? const Color(0xFFEFF6FF)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !useCustom
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        size: 18,
                        color: !useCustom
                            ? const Color(0xFF2563EB)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              ctrl.deviceImei.value.isNotEmpty
                                  ? ctrl.deviceImei.value
                                  : 'No device ID found',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontFamily: 'RobotoMono',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!useCustom)
                        const Icon(Icons.check_circle,
                            color: Color(0xFF2563EB), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Custom device ID
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setS(() => useCustom = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: useCustom
                        ? const Color(0xFFEFF6FF)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: useCustom
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: useCustom
                            ? const Color(0xFF2563EB)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Custom',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (useCustom)
                        const Icon(Icons.check_circle,
                            color: Color(0xFF2563EB), size: 18),
                    ],
                  ),
                ),
              ),
              if (useCustom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: customCtrl,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'RobotoMono',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter device ID',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (useCustom) {
                  final v = customCtrl.text.trim();
                  if (v.isNotEmpty) ctrl.setCustomImei(v);
                } else {
                  ctrl.resetToDeviceImei();
                }
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/backgrounds/login-bg.png'),
                fit: BoxFit.fill,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Obx(
                  () => Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      // Logo — long-press to override the device ID
                      GestureDetector(
                        onLongPress: () => _showImeiDialog(context, authController),
                        child: Image.asset(
                          'assets/images/logos/logo.png',
                          width: 120,
                          height: 120,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Sign in text
                      if (!authController.isLoading.value)
                        SizedBox(
                          width: MediaQuery.of(context).size.width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sign In to your Account',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              // Subtitle with device ID
                              Text(
                                'Please enter your 6-digit MPIN',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      // PIN Input Field - Hidden during loading
                      if (!authController.isLoading.value)
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
                      if (authController.isLoading.value)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Prominent loading animation with background
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.95),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 30,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      height: 60,
                                      width: 60,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Color(0xFF2563EB),
                                            ),
                                        strokeWidth: 5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                const Text(
                                  'Logging in...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Please wait while we verify your credentials',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Obx(() => GestureDetector(
                        onTap: () {
                          final imei = authController.imei.value;
                          if (imei.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: imei));
                            Get.snackbar(
                              'Copied',
                              'Device ID copied to clipboard',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              authController.imei.value.isNotEmpty
                                  ? 'Device ID: ${authController.imei.value}'
                                  : 'Device ID: ...',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontFamily: 'RobotoMono',
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (authController.imei.value.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.copy_rounded, size: 10, color: Colors.grey),
                              ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_appVersion.isNotEmpty)
            Positioned(
              bottom: 16,
              right: 16,
              child: Text(
                _appVersion,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFAAAAAA),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
