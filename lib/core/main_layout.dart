import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:onstite/pages/app/eod_report_page.dart';
import 'package:onstite/pages/app/summary_report_page.dart';
import 'package:onstite/pages/app/live_page.dart';
import '../controllers/auth_controller.dart';
import 'design_system.dart';

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
    Key? key,
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
  }) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
            widget.onMenuPressed?.call();
          },
        ),
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

      body: widget.body,
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
                    // Logo
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/logos/4play-tech.png',
                          width: MediaQuery.of(context).size.width * 0.5,
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
                                Text(
                                  'IMEI No. ${authCtrl.imei.value.isNotEmpty ? authCtrl.imei.value : 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF888888),
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
                            final today = DateTime.now();
                            final dateStr =
                                "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
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
                          final today = DateTime.now();
                          final dateStr =
                              "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
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
                    // Live Draw
                    ListTile(
                      leading: const Icon(
                        Icons.live_tv_rounded,
                        color: Color(0xFF222222),
                      ),
                      title: const Text(
                        'Live Draw',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222222),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LivePage()),
                        );
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      dense: true,
                      minLeadingWidth: 0,
                    ),
                    const SizedBox(height: 2),
                    // Notification with badge
                    ListTile(
                      leading: const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFF222222),
                      ),
                      title: Row(
                        children: [
                          const Text(
                            'Notification',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF222222),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFFF2D55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '2',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {},
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      dense: true,
                      minLeadingWidth: 0,
                    ),
                  ],
                ),
              ),
              // Spacer
              const Spacer(),
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
                    ).withOpacity(0.1),
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

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
