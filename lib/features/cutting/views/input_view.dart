import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/potong_kain_model.dart';
import '../viewmodels/cutting_viewmodel.dart';
import 'input_detail_screen.dart';

class InputView extends ConsumerStatefulWidget {
  const InputView({super.key});

  @override
  ConsumerState<InputView> createState() => _InputViewState();
}

class _InputViewState extends ConsumerState<InputView> {
  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(draftSesiProvider);
    final selesaiAsync = ref.watch(laporanSelesaiProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MANAJEMEN POTONG', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 18)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(cuttingControllerProvider.notifier).refreshData(),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
          children: [
            _buildHeaderSection(Icons.assignment_turned_in_rounded, "SESI BELUM SELESAI"),
            const SizedBox(height: 16),
            draftAsync.when(
              data: (draftItems) {
                final Map<String, List<PotongKainModel>> groupedDraft = {};
                for (var item in draftItems) {
                  final key = "${DateFormat('yyyy-MM-dd').format(item.tanggal)}_${item.sesi}_${item.model}";
                  groupedDraft.putIfAbsent(key, () => []).add(item);
                }
                final sortedDrafts = groupedDraft.values.toList()
                  ..sort((a, b) => b.first.tanggal.compareTo(a.first.tanggal));

                if (sortedDrafts.isEmpty) return _buildEmptyState("Tidak Ada Sesi Aktif", "Silakan buka sesi baru di bawah");
                return Column(children: sortedDrafts.map((items) => _buildSessionCard(context, items, true)).toList());
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary))),
              error: (err, _) => Center(child: Text("Error: $err")),
            ),

            const SizedBox(height: 40),

            _buildHeaderSection(Icons.history_rounded, "RIWAYAT SESI HARI INI"),
            const SizedBox(height: 16),
            selesaiAsync.when(
              data: (selesaiItems) {
                final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                final todayFinished = selesaiItems.where((item) => DateFormat('yyyy-MM-dd').format(item.tanggal) == todayStr).toList();
                
                final Map<String, List<PotongKainModel>> groupedToday = {};
                for (var item in todayFinished) {
                  final key = "${DateFormat('yyyy-MM-dd').format(item.tanggal)}_${item.sesi}_${item.model}";
                  groupedToday.putIfAbsent(key, () => []).add(item);
                }
                final sortedToday = groupedToday.values.toList()
                  ..sort((a, b) => b.first.tanggal.compareTo(a.first.tanggal));

                if (sortedToday.isEmpty) return _buildEmptyState("Belum Ada Sesi Selesai", "Sesi yang selesai hari ini akan muncul di sini");
                return Column(children: sortedToday.map((items) => _buildSessionCard(context, items, false)).toList());
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary))),
              error: (err, _) => Center(child: Text("Error: $err")),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () => _showNewSessionModal(context),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: AppColors.background, size: 28),
          label: const Text("BUKA SESI BARU", style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildSessionCard(BuildContext context, List<PotongKainModel> items, bool isDraft) {
    final first = items.first;
    final totalPcs = items.fold<int>(0, (sum, item) => sum + item.hasilPcs);
    final totalKg = items.fold<double>(0, (sum, item) => sum + item.kgTerpakai);
    final totalRol = items.where((e) => e.warna.isNotEmpty).length;
    final displayRol = (totalRol == 0 && (totalKg > 0 || totalPcs > 0)) ? 1 : totalRol;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InputDetailScreen(session: first, isDraft: isDraft)),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: isDraft ? Colors.white.withOpacity(0.05) : AppColors.success.withOpacity(0.1)),
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
                      if (!isDraft)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text("SELESAI", style: TextStyle(color: AppColors.success, fontSize: 8, fontWeight: FontWeight.bold)),
                        )
                      else
                        const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 14),
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
                        _buildStatItem("ROL", displayRol.toString(), Colors.white70),
                        _buildStatItem("KG", totalKg.toStringAsFixed(1), const Color(0xFF00CED1)), // BIRU UNTUK KG
                        _buildStatItem("PCS", totalPcs.toString(), const Color(0xFFFFD700)), // KUNING UNTUK PCS
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 30, top: 20,
            child: Opacity(
              opacity: 0.1,
              child: Icon(isDraft ? Icons.auto_awesome : Icons.check_circle_rounded, color: Colors.white, size: 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildEmptyState(String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.5), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.white10, size: 40),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: Colors.white24, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showNewSessionModal(BuildContext context) {
    String modelName = '';
    String sesiName = 'Sesi 1';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("BUKA SESI BARU", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 32),
                
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppColors.primary, onPrimary: AppColors.background, surface: AppColors.surface),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TANGGAL CUTTING", style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(DateFormat('EEEE, dd MMMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                TextField(
                  onChanged: (val) => modelName = val,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "NAMA MODEL",
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.style_rounded, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: sesiName,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "PILIH SESI",
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.access_time_filled_rounded, color: AppColors.primary),
                  ),
                  items: ['Sesi 1', 'Sesi 2', 'Sesi 3', 'Sesi 4', 'Sesi 5'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => sesiName = val!,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (modelName.isEmpty) return;
                      final newSesi = PotongKainModel(
                        tanggal: selectedDate,
                        sesi: sesiName,
                        model: modelName,
                        warna: '',
                        kgTerpakai: 0,
                        hasilPcs: 0,
                        status: 'Draft',
                        statusPembayaran: 'Belum',
                        gajiTerbayar: 0,
                      );
                      
                      await ref.read(cuttingControllerProvider.notifier).simpanSesiBaru(newSesi);
                      
                      if (mounted) {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => InputDetailScreen(session: newSesi, isDraft: true)));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("MULAI MENCATAT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
