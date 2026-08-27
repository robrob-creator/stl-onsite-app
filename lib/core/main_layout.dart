import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:onstite/pages/app/collection_page.dart';
import 'package:onstite/pages/app/eod_report_page.dart';
import 'package:onstite/pages/app/summary_report_page.dart';
import 'package:onstite/pages/app/live_page.dart';
import '../controllers/auth_controller.dart';
import '../controllers/live_draw_controller.dart';
import 'services/websocket_service.dart';
import 'utils/manila_time.dart';
import 'app_constants.dart';

/// Main layout widget with AppBar and BottomNavigationBar
class MainLayout extends StatefulWidget {
  final Widget body;
  final String? title;
  final List<Widget>? appBarActions;
  final VoidCallback? onMenuPressed;
  final int? currentIndex;
  final Function(int)? onBottomNavTap;
  final List<BottomNavigationBarItem>? bottomNavItems;
  final FloatingActionButton? floatingActionButton;
  final Color backgroundColor;
  final Widget? appBarTrailing;
  final String? activeDrawerItem;

  const MainLayout({
    super.key,
    required this.body,
    this.title,
    this.appBarActions,
    this.onMenuPressed,
    this.currentIndex = 0,
    this.onBottomNavTap,
    this.bottomNavItems,
    this.floatingActionButton,
    this.backgroundColor = Colors.white,
    this.appBarTrailing,
    this.activeDrawerItem,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Show the disconnected banner only after the WebSocket has been down for
  // this long, so a quick reconnect (common during backoff resets) never
  // flashes the warning at the user.
  static const Duration _disconnectGrace = Duration(seconds: 5);

  Timer? _disconnectTimer;
  Worker? _wsWorker;
  bool _showDisconnectedBanner = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _watchWebSocketConnection();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = 'v${info.version}+${info.buildNumber}');
    });
  }

  @override
  void dispose() {
    _disconnectTimer?.cancel();
    _wsWorker?.dispose();
    super.dispose();
  }

  void _watchWebSocketConnection() {
    if (!Get.isRegistered<WebSocketService>()) return;
    final ws = Get.find<WebSocketService>();
    _handleConnectionChanged(ws.isConnected.value);
    _wsWorker = ever<bool>(ws.isConnected, _handleConnectionChanged);
  }

  void _handleConnectionChanged(bool connected) {
    if (connected) {
      _disconnectTimer?.cancel();
      _disconnectTimer = null;
      if (_showDisconnectedBanner && mounted) {
        setState(() => _showDisconnectedBanner = false);
      }
      return;
    }
    // Debounce: only show the banner if we stay disconnected past the grace
    // period. Cancels itself if a reconnect arrives first.
    _disconnectTimer?.cancel();
    _disconnectTimer = Timer(_disconnectGrace, () {
      if (!mounted) return;
      setState(() => _showDisconnectedBanner = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: Obx(() {
          final isLive = Get.isRegistered<LiveDrawController>()
              ? Get.find<LiveDrawController>().isLive.value
              : false;
          return IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.menu, color: Colors.black),
                if (isLive)
                  Positioned(
                    top: -3,
                    right: -4,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
              widget.onMenuPressed?.call();
            },
          );
        }),
        title: widget.title != null
            ? Text(
                widget.title!,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              )
            : null,
        actions:
            widget.appBarActions ??
            (widget.appBarTrailing != null
                ? [
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Center(child: widget.appBarTrailing!),
                    ),
                  ]
                : null),
      ),
      drawer: _buildDrawer(),

      body: Column(
        children: [
          if (_showDisconnectedBanner) _buildDisconnectedBanner(),
          Expanded(child: widget.body),
        ],
      ),
      bottomNavigationBar: widget.bottomNavItems != null
          ? BottomNavigationBar(
              currentIndex: widget.currentIndex ?? 0,
              onTap: widget.onBottomNavTap,
              items: widget.bottomNavItems!,
              selectedFontSize: 10,
              unselectedFontSize: 10,
            )
          : null,
      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildDrawer() {
    return GetBuilder<AuthController>(
      builder: (authCtrl) => Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Logo and Agent Info
              Padding(
                padding: const EdgeInsets.only(
                  top: 24.0,
                  left: 16,
                  right: 16,
                  bottom: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo — long press to switch environment
                    Row(
                      children: [
                        GestureDetector(
                          onLongPress: _showEnvDialog,
                          child: Image.asset(
                            'assets/images/logos/4play-tech.png',
                            width: MediaQuery.of(context).size.width * 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Agent Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),

                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.blue,
                            child: Text(
                              (authCtrl.currentUser.value?.name.isNotEmpty ==
                                      true)
                                  ? authCtrl.currentUser.value!.name[0]
                                        .toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authCtrl.currentUser.value?.name.isNotEmpty ==
                                          true
                                      ? authCtrl.currentUser.value!.name
                                      : 'AGENT',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Color(0xFF222222),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  onTap: () {
                                    final imei = authCtrl.imei.value;
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
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Device ID: ${authCtrl.imei.value.isNotEmpty ? authCtrl.imei.value : 'N/A'}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF888888),
                                          ),
                                        ),
                                      ),
                                      if (authCtrl.imei.value.isNotEmpty)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Icon(
                                            Icons.copy_rounded,
                                            size: 13,
                                            color: Color(0xFFAAAAAA),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF888888),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Menu Items
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  children: [
                    // Summary Report
                    Container(
                      decoration: BoxDecoration(
                        color: widget.activeDrawerItem == 'summary_report'
                            ? const Color(0xFFF3F5F8)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.grid_view_rounded,
                          color: Color(0xFF222222),
                        ),
                        title: Text(
                          'Summary Report',
                          style: TextStyle(
                            fontWeight:
                                widget.activeDrawerItem == 'summary_report'
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: const Color(0xFF222222),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final userId = authCtrl.currentUser.value?.id;
                          if (userId != null && userId.isNotEmpty) {
                            final dateStr = ManilaTime.dateString();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SummaryReportPage(
                                  date: dateStr,
                                  makerId: userId,
                                ),
                              ),
                            );
                          }
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        dense: true,
                        minLeadingWidth: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // End of Day Report
                    ListTile(
                      leading: const Icon(
                        Icons.table_rows_rounded,
                        color: Color(0xFF222222),
                      ),
                      title: const Text(
                        'End of Day Report',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222222),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        final userId = authCtrl.currentUser.value?.id;
                        if (userId != null && userId.isNotEmpty) {
                          final dateStr = ManilaTime.dateString();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  EodReportPage(makerId: userId, date: dateStr),
                            ),
                          );
                        }
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      dense: true,
                      minLeadingWidth: 0,
                    ),
                    // Collection
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Color(0xFF222222),
                      ),
                      title: const Text(
                        'Collection',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222222),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CollectionPage(),
                          ),
                        );
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      dense: true,
                      minLeadingWidth: 0,
                    ),
                    // Live Draw
                    Obx(() {
                      final isLive = Get.isRegistered<LiveDrawController>()
                          ? Get.find<LiveDrawController>().isLive.value
                          : false;
                      return ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              Icons.live_tv_rounded,
                              color: isLive
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF222222),
                            ),
                            if (isLive)
                              Positioned(
                                top: -3,
                                right: -4,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Text(
                              'Live Draw',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isLive
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF222222),
                              ),
                            ),
                            if (isLive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const LivePage()),
                          );
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        dense: true,
                        minLeadingWidth: 0,
                      );
                    }),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
              // Spacer
              const Spacer(),
              // App version
              if (_appVersion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _appVersion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
                ),
              // Logout Button at bottom
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  top: 8,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(authCtrl);
                  },
                  child: Container(
                    color: const Color.fromARGB(
                      255,
                      255,
                      255,
                      255,
                    ).withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout,
                          color: Color(0xFFFF2D55),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Logout',
                          style: TextStyle(
                            color: Color(0xFFFF2D55),
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedBanner() {
    return Material(
      color: const Color(0xFFFEE2E2),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 18,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Realtime updates paused — reconnecting…',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 14,
                height: 14,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEnvDialog() {
    String selected = AppConstants.apiBaseUrl;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Select Environment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EnvOption(
                label: 'Staging',
                subtitle: AppConstants.envStaging,
                value: AppConstants.envStaging,
                selected: selected,
                onTap: () => setState(() => selected = AppConstants.envStaging),
              ),
              _EnvOption(
                label: 'Production',
                subtitle: AppConstants.envProduction,
                value: AppConstants.envProduction,
                selected: selected,
                onTap: () => setState(() => selected = AppConstants.envProduction),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                AppConstants.setEnvironment(selected);
                Navigator.of(ctx).pop();
                Get.find<AuthController>().logout();
                Get.snackbar(
                  'Environment Changed',
                  'Switched to ${selected.contains('staging') ? 'Staging' : 'Production'}. Please log in again.',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 3),
                );
              },
              child: const Text('Apply', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(AuthController authCtrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authCtrl.logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _EnvOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final String selected;
  final VoidCallback onTap;

  const _EnvOption({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
