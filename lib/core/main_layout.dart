import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
        child: Column(
          children: [
            // Header
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    authCtrl.currentUser.value?.name ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authCtrl.currentUser.value?.email ?? 'user@example.com',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to profile page
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to notifications page
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to help page
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to settings page
                    },
                  ),
                ],
              ),
            ),
            // Logout Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    _showLogoutDialog(authCtrl);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
