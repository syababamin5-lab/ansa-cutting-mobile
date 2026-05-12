import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/constants/app_colors.dart';
import '../../cutting/views/input_view.dart';
import '../../reports/views/laporan_view.dart';
import '../../payroll/views/gaji_view.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const InputView(),
    const LaporanView(),
    const GajiView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedEdit02, color: _currentIndex == 0 ? AppColors.primary : Colors.grey),
              label: 'Input',
            ),
            BottomNavigationBarItem(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedDocumentAttachment, color: _currentIndex == 1 ? AppColors.primary : Colors.grey),
              label: 'Laporan',
            ),
            BottomNavigationBarItem(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedWallet01, color: _currentIndex == 2 ? AppColors.primary : Colors.grey),
              label: 'Gaji',
            ),
          ],
        ),
      ),
    );
  }
}
