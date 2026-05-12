import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../cutting/models/potong_kain_model.dart';
import '../../cutting/viewmodels/cutting_viewmodel.dart';

class LaporanView extends ConsumerStatefulWidget {
  const LaporanView({super.key});

  @override
  ConsumerState<LaporanView> createState() => _LaporanViewState();
}

class _LaporanViewState extends ConsumerState<LaporanView> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    // Memantau data yang sudah selesai (LaporanSelesaiProvider)
    final asyncData = ref.watch(laporanSelesaiProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Produksi', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, color: Colors.white),
            tooltip: "Filter Tanggal",
            onPressed: _showDateRangePicker,
          )
        ],
      ),
      body: asyncData.when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text("Belum ada data produksi yang selesai.", style: TextStyle(color: AppColors.textSecondary)));
          }

          // Tentukan default rentang waktu jika belum difilter
          final sortedData = List<PotongKainModel>.from(data)..sort((a, b) => a.tanggal.compareTo(b.tanggal));
          _startDate ??= sortedData.first.tanggal;
          _endDate ??= sortedData.last.tanggal;

          // Terapkan Filter Tanggal
          final filteredData = data.where((item) {
            final t = item.tanggal;
            return t.isAfter(_startDate!.subtract(const Duration(days: 1))) && 
                   t.isBefore(_endDate!.add(const Duration(days: 1)));
          }).toList();

          if (filteredData.isEmpty) {
            return const Center(child: Text("Tidak ada data pada rentang tanggal tersebut.", style: TextStyle(color: AppColors.textSecondary)));
          }

          // Kalkulasi Metrik (Sama seperti dashboard.py Streamlit)
          int totalPcs = 0;
          double totalKg = 0.0;
          Map<String, int> modelCount = {};
          
          for (var item in filteredData) {
            totalPcs += item.hasilPcs;
            totalKg += item.kgTerpakai;
            modelCount[item.model] = (modelCount[item.model] ?? 0) + item.hasilPcs;
          }

          double rasio = totalKg > 0 ? totalPcs / totalKg : 0.0;

          // Mengurutkan Model Terbanyak
          final topModels = modelCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDateFilterInfo(),
              const SizedBox(height: 16),
              
              // 1. GRID METRIK UTAMA (Total PCS, Total KG, Rata-rata)
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMetricCard("Total (Pcs)", NumberFormat("#,###").format(totalPcs), HugeIcons.strokeRoundedLayers01),
                  _buildMetricCard("Bahan (Kg)", "${totalKg.toStringAsFixed(1)} Kg", HugeIcons.strokeRoundedWeightScale),
                  _buildMetricCard("Rata-rata", "${rasio.toStringAsFixed(1)} Pcs/Kg", HugeIcons.strokeRoundedChartLineUp01),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // 2. MODEL TERBANYAK
              const Text("🏆 Model Terbanyak", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: BorderSide(color: Colors.grey.shade200)),
                child: Column(
                  children: topModels.take(5).map((e) => _buildTopModelItem(e.key, e.value)).toList(),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 3. RAW DATA LIST
              const Text("🔍 Raw Data Produksi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ...filteredData.take(10).map((e) => _buildRawDataItem(e)),
              if (filteredData.length > 10) 
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text("Menampilkan 10 data terbaru...", style: TextStyle(color: Colors.grey, fontSize: 12))),
                )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildDateFilterInfo() {
    if (_startDate == null || _endDate == null) return const SizedBox.shrink();
    final fmt = DateFormat('dd MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text("${fmt.format(_startDate!)} - ${fmt.format(_endDate!)}", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildTopModelItem(String modelName, int pcs) {
    return ListTile(
      leading: const CircleAvatar(backgroundColor: AppColors.background, child: HugeIcon(icon: HugeIcons.strokeRoundedApparel01, color: AppColors.primary)),
      title: Text(modelName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      trailing: Text("$pcs Pcs", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
    );
  }

  Widget _buildRawDataItem(PotongKainModel item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text("${item.model} (${item.warna})", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text("${DateFormat('dd MMM yyyy').format(item.tanggal)} | ${item.sesi}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("${item.hasilPcs} Pcs", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            Text("${item.kgTerpakai} Kg", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null 
          ? DateTimeRange(start: _startDate!, end: _endDate!) 
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, onSurface: AppColors.textPrimary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
}
