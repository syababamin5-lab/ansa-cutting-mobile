import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../cutting/viewmodels/cutting_viewmodel.dart';
import '../../cutting/models/potong_kain_model.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(laporanSelesaiProvider);
    final currencyFmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('DASHBOARD PRODUKSI',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 18)),
        centerTitle: false,
      ),
      body: asyncData.when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text("Belum ada data produksi.", style: TextStyle(color: Colors.white24)));
          }

          // 1. Hitung Ringkasan
          final totalPcs = data.fold<int>(0, (sum, e) => sum + e.hasilPcs);
          final totalKg = data.fold<double>(0, (sum, e) => sum + e.kgTerpakai);
          final totalGaji = data.fold<double>(0, (sum, e) => sum + e.gajiTerbayar);

          // 2. Data untuk Grafik Batang (Pcs per Model)
          final Map<String, int> modelStats = {};
          for (var e in data) {
            modelStats[e.model] = (modelStats[e.model] ?? 0) + e.hasilPcs;
          }
          final sortedModels = modelStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final topModels = sortedModels.take(5).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.read(cuttingControllerProvider.notifier).refreshData(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSummaryCards(totalPcs, totalKg, totalGaji, currencyFmt),
                const SizedBox(height: 32),
                _buildSectionHeader("Top 5 Produksi Model (Pcs)"),
                const SizedBox(height: 16),
                _buildBarChart(topModels),
                const SizedBox(height: 40),
                _buildSectionHeader("Persentase Model"),
                const SizedBox(height: 16),
                _buildPieChart(topModels),
                const SizedBox(height: 100), // Padding bawah navigasi
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: AppColors.error))),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(),
        style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1));
  }

  Widget _buildSummaryCards(int pcs, double kg, double gaji, NumberFormat fmt) {
    return Row(
      children: [
        Expanded(child: _buildMiniCard("TOTAL PCS", "$pcs", const Color(0xFF00CED1))),
        const SizedBox(width: 12),
        Expanded(child: _buildMiniCard("TOTAL KG", "${kg.toStringAsFixed(1)}", const Color(0xFFFFD700))),
        const SizedBox(width: 12),
        Expanded(child: _buildMiniCard("GAJI CAIR", fmt.format(gaji), AppColors.success, isSmall: true)),
      ],
    );
  }

  Widget _buildMiniCard(String label, String value, Color color, {bool isSmall = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: isSmall ? 11 : 18,
                  fontWeight: FontWeight.w900,
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<MapEntry<String, int>> data) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: data.isEmpty ? 100 : (data.first.value * 1.2),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= data.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(data[value.toInt()].key.substring(0, 3).toUpperCase(),
                        style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value.toDouble(),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00CED1), Color(0xFF008B8B)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPieChart(List<MapEntry<String, int>> data) {
    final colors = [
      const Color(0xFF00CED1),
      const Color(0xFFFFD700),
      AppColors.primary,
      const Color(0xFFFF6347),
      const Color(0xFF9370DB),
    ];

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: data.asMap().entries.map((e) {
                  return PieChartSectionData(
                    color: colors[e.key % colors.length],
                    value: e.value.value.toDouble(),
                    title: '',
                    radius: 20,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(e.value.key.toUpperCase(),
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text("${e.value.value}", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
