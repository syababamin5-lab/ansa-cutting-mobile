import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/potong_kain_model.dart';
import '../viewmodels/cutting_viewmodel.dart';
import 'input_detail_screen.dart';

class InputView extends ConsumerWidget {
  const InputView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(draftSesiProvider);
    final selesaiAsync = ref.watch(laporanSelesaiProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Potong Kain', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(cuttingControllerProvider.notifier).refreshData(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader("Belum Selesai (Draft)", HugeIcons.strokeRoundedTime02),
            const SizedBox(height: 12),
            draftsAsync.when(
              data: (drafts) => _buildList(drafts, isDraft: true, context: context),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
            
            const SizedBox(height: 32),
            
            _buildHeader("Selesai Hari Ini", HugeIcons.strokeRoundedCheckmarkCircle02),
            const SizedBox(height: 12),
            selesaiAsync.when(
              data: (selesai) {
                final hariIni = selesai.where((e) => isSameDate(e.tanggal, DateTime.now())).toList();
                return _buildList(hariIni, isDraft: false, context: context);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSessionDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.white),
        label: const Text('Buka Sesi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  bool isSameDate(DateTime d1, DateTime d2) => 
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  Widget _buildHeader(String title, IconData icon) {
    return Row(
      children: [
        HugeIcon(icon: icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildList(List<PotongKainModel> data, {required bool isDraft, required BuildContext context}) {
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text("Kosong", style: TextStyle(color: Colors.grey))),
      );
    }
    
    // Group by Tanggal, Sesi, Model (karena model list menyimpan detail warna)
    // Di aplikasi aslinya, ada peringkasan. Untuk sementara kita tampilkan per item unik
    final Map<String, PotongKainModel> uniqueSessions = {};
    for (var item in data) {
      final key = "${item.tanggal}_${item.sesi}_${item.model}";
      if (!uniqueSessions.containsKey(key)) {
        uniqueSessions[key] = item;
      }
    }

    return Column(
      children: uniqueSessions.values.map((item) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200)
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isDraft ? AppColors.warning.withOpacity(0.2) : AppColors.success.withOpacity(0.2),
              child: HugeIcon(
                icon: isDraft ? HugeIcons.strokeRoundedTime02 : HugeIcons.strokeRoundedCheckmarkBadge01,
                color: isDraft ? AppColors.warning : AppColors.success,
              ),
            ),
            title: Text(item.model, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${DateFormat('dd MMM yyyy').format(item.tanggal)} | ${item.sesi}"),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDraft ? AppColors.primary : Colors.grey.shade200,
                foregroundColor: isDraft ? Colors.white : AppColors.textPrimary,
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => InputDetailScreen(session: item, isDraft: isDraft))
                );
              },
              child: Text(isDraft ? "Teruskan" : "Edit"),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAddSessionDialog(BuildContext context, WidgetRef ref) {
    // Form untuk buka sesi baru seperti di Streamlit
    String selectedSesi = "Sesi 1";
    final TextEditingController modelCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Buka Sesi Baru", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedSesi,
                    decoration: InputDecoration(
                      labelText: "Pilih Sesi",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ["Sesi 1", "Sesi 2", "Sesi 3", "Sesi 4"].map((String val) {
                      return DropdownMenuItem<String>(value: val, child: Text(val));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedSesi = val!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: modelCtrl,
                    decoration: InputDecoration(
                      labelText: "Nama Model (Cth: Kemeja Polos)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      onPressed: () {
                        if (modelCtrl.text.isNotEmpty) {
                          final newData = PotongKainModel(
                            tanggal: DateTime.now(),
                            sesi: selectedSesi,
                            model: modelCtrl.text,
                            warna: '',
                            kgTerpakai: 0.0,
                            hasilPcs: 0,
                            status: 'Draft',
                            statusPembayaran: 'Belum',
                            gajiTerbayar: 0.0,
                          );
                          ref.read(cuttingControllerProvider.notifier).simpanSesiBaru(newData);
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text("Simpan Sesi"),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }
}
