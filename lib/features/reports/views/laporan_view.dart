import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final asyncData = ref.watch(laporanSelesaiProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('STATISTIK CUTTING', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 18)),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
              tooltip: "Filter Tanggal",
              onPressed: _showDateRangePicker,
            ),
          )
        ],
      ),
      body: asyncData.when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text("Belum ada data produksi yang selesai.", style: TextStyle(color: AppColors.textSecondary)));
          }

          final sortedData = List<PotongKainModel>.from(data)..sort((a, b) => a.tanggal.compareTo(b.tanggal));
          _startDate ??= sortedData.first.tanggal;
          _endDate ??= sortedData.last.tanggal;

          final filteredData = data.where((item) {
            final t = item.tanggal;
            return t.isAfter(_startDate!.subtract(const Duration(days: 1))) && 
                   t.isBefore(_endDate!.add(const Duration(days: 1)));
          }).toList();

          if (filteredData.isEmpty) {
            return const Center(child: Text("Tidak ada data pada rentang tanggal tersebut.", style: TextStyle(color: AppColors.textSecondary)));
          }

          int totalPcs = 0;
          double totalKg = 0.0;
          Map<String, int> modelCount = {};
          
          for (var item in filteredData) {
            totalPcs += item.hasilPcs;
            totalKg += item.kgTerpakai;
            modelCount[item.model] = (modelCount[item.model] ?? 0) + item.hasilPcs;
          }

          double rasio = totalKg > 0 ? totalPcs / totalKg : 0.0;
          final topModels = modelCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final maxModelPcs = topModels.isNotEmpty ? topModels.first.value : 1;

          final Map<String, List<PotongKainModel>> historyGrouped = {};
          for (var item in filteredData) {
            final key = "${DateFormat('yyyy-MM-dd').format(item.tanggal)}_${item.sesi}_${item.model}";
            historyGrouped.putIfAbsent(key, () => []).add(item);
          }
          final sortedSessions = historyGrouped.values.toList()
            ..sort((a, b) => b.first.tanggal.compareTo(a.first.tanggal));

          return RefreshIndicator(
            onRefresh: () async => ref.read(cuttingControllerProvider.notifier).refreshData(),
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              children: [
                _buildDateFilterInfo(),
                const SizedBox(height: 24),
                _buildMainOutputCard(totalPcs),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildSmallMetricCard("BAHAN TERPAKAI", "${totalKg.toStringAsFixed(1)} Kg", const Color(0xFF00CED1))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSmallMetricCard("RATA-RATA", "${rasio.toStringAsFixed(1)} Pcs/Kg", AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 32),
                _buildTopModelCard(topModels, maxModelPcs),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 12),
                        Text("RIWAYAT PER SESI", style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      ],
                    ),
                    InkWell(
                      onTap: _showDateRangePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 14),
                            SizedBox(width: 6),
                            Text("FILTER", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...sortedSessions.map((items) => _buildSessionHistoryItem(items)),
                const SizedBox(height: 32),
                _buildDynamicDetailSection(filteredData),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: AppColors.error))),
      ),
    );
  }

  Widget _buildDynamicDetailSection(List<PotongKainModel> allData) {
    final Map<String, List<PotongKainModel>> dateGrouped = {};
    for (var item in allData) {
      final dateKey = DateFormat('yyyy-MM-dd').format(item.tanggal);
      dateGrouped.putIfAbsent(dateKey, () => []).add(item);
    }
    final sortedDates = dateGrouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Row(
            children: [
              Icon(Icons.analytics_rounded, color: Color(0xFF00CED1), size: 18),
              SizedBox(width: 12),
              Text("Detail Laporan Dinamis", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          children: sortedDates.map((dateKey) {
            final dateItems = dateGrouped[dateKey]!;
            final dayTotalPcs = dateItems.fold<int>(0, (sum, item) => sum + item.hasilPcs);
            final dayTotalKg = dateItems.fold<double>(0, (sum, item) => sum + item.kgTerpakai);

            final Map<String, List<PotongKainModel>> sessionGrouped = {};
            for (var item in dateItems) {
              final sessKey = "${item.sesi} - ${item.model.toUpperCase()}";
              sessionGrouped.putIfAbsent(sessKey, () => []).add(item);
            }
            final sortedSessKeys = sessionGrouped.keys.toList()..sort();

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.navBackground.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ExpansionTile(
                title: Text(
                  DateFormat('EEEE, dd MMM').format(DateTime.parse(dateKey)),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTag(dayTotalKg.toStringAsFixed(1), "KG", const Color(0xFF00CED1)),
                    const SizedBox(width: 8),
                    _buildTag(dayTotalPcs.toString(), "PCS", const Color(0xFFFFD700)),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more_rounded, color: Colors.white38, size: 18),
                  ],
                ),
                children: sortedSessKeys.map((sessKey) {
                  final items = sessionGrouped[sessKey]!;
                  final sessTotalPcs = items.fold<int>(0, (sum, item) => sum + item.hasilPcs);
                  final sessTotalKg = items.fold<double>(0, (sum, item) => sum + item.kgTerpakai);

                  return Container(
                    margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      title: Text(sessKey, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("${sessTotalKg.toStringAsFixed(1)}kg", style: const TextStyle(color: Color(0xFF00CED1), fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text("$sessTotalPcs", style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      children: [
                        _buildCustomStyledTable(items),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomStyledTable(List<PotongKainModel> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(flex: 3, child: Text("WARNA", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
              Expanded(flex: 2, child: Text("KG", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text("PCS", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1), textAlign: TextAlign.right)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          ...items.map((item) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(item.warna, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text(item.kgTerpakai.toStringAsFixed(1), style: const TextStyle(color: Color(0xFF00CED1), fontSize: 14, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text(item.hasilPcs.toString(), style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w900), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
            ],
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildTag(String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(width: 2),
          Text(unit, style: TextStyle(color: color.withOpacity(0.6), fontSize: 7, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDateFilterInfo() {
    if (_startDate == null || _endDate == null) return const SizedBox.shrink();
    final fmt = DateFormat('dd MMM yyyy');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.5), 
        borderRadius: BorderRadius.circular(16)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text("${fmt.format(_startDate!)}  -  ${fmt.format(_endDate!)}", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMainOutputCard(int pcs) {
    final fmt = NumberFormat("#,###");
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.05), size: 100),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text("TOTAL OUTPUT", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmt.format(pcs), style: const TextStyle(color: Color(0xFFFFD700), fontSize: 56, fontWeight: FontWeight.w900, height: 1)),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text("PCS", style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetricCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.navBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: valueColor, fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTopModelCard(List<MapEntry<String, int>> models, int maxPcs) {
    final fmt = NumberFormat("#,###");
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 12),
              Text("TOP MODEL", style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 24),
          if (models.isEmpty)
             const Text("Belum ada data", style: TextStyle(color: Colors.white54))
          else
            ...models.take(5).map((item) {
              double ratio = maxPcs > 0 ? item.value / maxPcs : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.key.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        Row(
                          children: [
                            Text(fmt.format(item.value), style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 14)),
                            const SizedBox(width: 4),
                            const Text("pcs", style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.navBackground,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.progressBar, 
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildSessionHistoryItem(List<PotongKainModel> items) {
    final first = items.first;
    final totalPcs = items.fold<int>(0, (sum, item) => sum + item.hasilPcs);
    final totalKg = items.fold<double>(0, (sum, item) => sum + item.kgTerpakai);
    final totalRol = items.where((e) => e.warna.isNotEmpty).length;

    return GestureDetector(
      onTap: () => _showSessionDetail(context, items),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(first.model.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text("${DateFormat('dd MMM yyyy').format(first.tanggal)} | ${first.sesi}", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Text("SELESAI", style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                )
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.navBackground.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat("ROL", totalRol.toString(), Colors.white70),
                  _buildMiniStat("KG", totalKg.toStringAsFixed(1), const Color(0xFF00CED1)),
                  _buildMiniStat("PCS", totalPcs.toString(), const Color(0xFFFFD700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionDetail(BuildContext context, List<PotongKainModel> items) {
    final first = items.first;
    final totalPcs = items.fold<int>(0, (sum, item) => sum + item.hasilPcs);
    final totalKg = items.fold<double>(0, (sum, item) => sum + item.kgTerpakai);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(first.model.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(DateFormat('EEEE, dd MMMM yyyy').format(first.tanggal), style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white38),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    _buildPopupHeaderStat("TOTAL BERAT", "${totalKg.toStringAsFixed(1)} KG", const Color(0xFF00CED1)),
                    const SizedBox(width: 16),
                    _buildPopupHeaderStat("TOTAL HASIL", "$totalPcs PCS", const Color(0xFFFFD700)),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    SizedBox(width: 30, child: Text("NO", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 10))),
                    Expanded(child: Text("WARNA KAIN", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 10))),
                    SizedBox(width: 60, child: Text("KG", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center)),
                    SizedBox(width: 60, child: Text("PCS", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 30, child: Text("${index + 1}", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                          Expanded(child: Text(item.warna, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                          SizedBox(width: 60, child: Text("${item.kgTerpakai}", style: const TextStyle(color: Color(0xFF00CED1), fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                          SizedBox(width: 60, child: Text("${item.hasilPcs}", style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900), textAlign: TextAlign.right)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopupHeaderStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
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
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary, 
              onPrimary: AppColors.navBackground, 
              surface: AppColors.surface,
              onSurface: Colors.white
            ),
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
