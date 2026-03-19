import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:onstite/core/design_system.dart';
import '../../../core/main_layout.dart';
import '../../../controllers/lottery_controller.dart';
import 'bet_entry_page.dart';
import 'transaction_page.dart';
import 'dashboard_page.dart';
import 'ticket_page.dart';
import 'claim_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1; // Default to Bet tab

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      onMenuPressed: () {},
      appBarTrailing: GetBuilder<LotteryController>(
        builder: (ctrl) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                ctrl.balance.value.toStringAsFixed(2),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
      onBottomNavTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },

      bottomNavItems: [
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/logos/home.png',
            width: 24,
            height: 24,
            color: _currentIndex == 0 ? AppColors.primary : Colors.grey,
          ),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/icons/reciept1.png',
            width: 24,
            height: 24,
            color: _currentIndex == 1 ? AppColors.primary : null,
          ),
          label: 'Bet',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/icons/clock1.png',
            width: 24,
            height: 24,
            color: _currentIndex == 2 ? AppColors.primary : null,
          ),
          label: 'Transaction',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/icons/ticket1.png',
            color: _currentIndex == 3 ? AppColors.primary : null,
            width: 24,
            height: 24,
          ),
          label: 'Ticket',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/icons/star1.png',
            width: 24,
            height: 24,
            color: _currentIndex == 4 ? AppColors.primary : null,
          ),

          label: 'Claim',
        ),
      ],
      currentIndex: _currentIndex,
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const DashboardPage();
      case 1:
        return const BetEntryPage();
      case 2:
        return const TransactionPage();
      case 3:
        return const TicketPage();
      case 4:
        return const ClaimPage();
      default:
        return const BetEntryPage();
    }
  }
}
