import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../cutting/views/input_view.dart';
import '../../reports/views/laporan_view.dart';
import '../../payroll/views/gaji_view.dart';
import 'dashboard_view.dart'; // Import Dashboard

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardView(), // Dashboard jadi menu pertama
    const InputView(),
    const LaporanView(),
    const GajiView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: _buildCurvedNavBar(),
    );
  }

  Widget _buildCurvedNavBar() {
    final double width = MediaQuery.of(context).size.width;
    final double itemWidth = (width - 32) / 4; // Dibagi 4 tabs

    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        children: [
          // Background Bar with Notch
          Positioned(
            bottom: 0,
            left: 16,
            right: 16,
            child: CustomPaint(
              size: Size(width - 32, 70),
              painter: NavPathPainter(
                _currentIndex, 
                4, // Total tabs jadi 4
                Colors.white,
              ),
            ),
          ),
          // Animated Active Circle
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            left: 16 + (itemWidth * _currentIndex) + (itemWidth / 2) - 30,
            bottom: 40,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                _currentIndex == 0 
                  ? Icons.dashboard_rounded 
                  : _currentIndex == 1 
                    ? Icons.edit_document 
                    : _currentIndex == 2
                      ? Icons.bar_chart_rounded
                      : Icons.wallet_rounded,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),
          // Interactive Icons
          Positioned(
            bottom: 0,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, "HOME"),
                  _buildNavItem(1, Icons.edit_document, "INPUT"),
                  _buildNavItem(2, Icons.bar_chart_rounded, "LAPORAN"),
                  _buildNavItem(3, Icons.wallet_rounded, "GAJI"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: isSelected ? 0 : 1, // Hide icon if active circle is over it
              child: Icon(
                icon, 
                color: isSelected ? Colors.black87 : Colors.black38, 
                size: 26
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.black45,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter to draw the bar with a smooth notch
class NavPathPainter extends CustomPainter {
  final int index;
  final int total;
  final Color color;

  NavPathPainter(this.index, this.total, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final double itemWidth = size.width / total;
    final double center = (itemWidth * index) + (itemWidth / 2);

    path.moveTo(0, 20); // Top left radius
    path.quadraticBezierTo(0, 0, 20, 0);
    
    // Line to the start of the notch
    path.lineTo(center - 50, 0);
    
    // The Notch curve (Smooth)
    path.cubicTo(
      center - 35, 0,
      center - 30, 45,
      center, 45,
    );
    path.cubicTo(
      center + 30, 45,
      center + 35, 0,
      center + 50, 0,
    );

    path.lineTo(size.width - 20, 0);
    path.quadraticBezierTo(size.width, 0, size.width, 20);
    path.lineTo(size.width, size.height - 20);
    path.quadraticBezierTo(size.width, size.height, size.width - 20, size.height);
    path.lineTo(20, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 20);
    path.close();

    canvas.drawShadow(path, Colors.black, 10, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant NavPathPainter oldDelegate) => 
    oldDelegate.index != index;
}
