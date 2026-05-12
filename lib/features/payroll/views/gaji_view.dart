import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../cutting/models/potong_kain_model.dart';
import '../../cutting/viewmodels/cutting_viewmodel.dart';

class GajiView extends ConsumerStatefulWidget {
  const GajiView({super.key});

  @override
  ConsumerState<GajiView> createState() => _GajiViewState();
}

class _GajiViewState extends ConsumerState<GajiView> {
  // Menyimpan sesi mana saja yang dicentang
  final Set<String> _selectedKeys = {};
  
  // Menyimpan input tarif per model
  final Map<String, double> _tarifPerModel = {};

  String _generateKey(PotongKainModel item) {
    return "${item.tanggal.toIso8601String().split('T')[0]}_${item.sesi}_${item.model}";
  }

  @override
  Widget build(BuildContext context) {
    final belumBayarAsync = ref.watch(belumBayarProvider);
    final curFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perhitungan Gaji', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(cuttingControllerProvider.notifier).refreshData(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader("1. Pilih Sesi untuk Digaji", HugeIcons.strokeRoundedCheckmarkBadge01),
              const SizedBox(height: 12),
              
              belumBayarAsync.when(
                data: (belumBayar) {
                  if (belumBayar.isEmpty) {
                    return _buildEmptyState("Semua sesi potongan sudah dibayar lunas!");
                  }

                  // Mengelompokkan berdasarkan Sesi & Model
                  final Map<String, PotongKainModel> grouped = {};
                  final Map<String, int> totalPcsPerSesi = {};
                  
                  for (var item in belumBayar) {
                    final key = _generateKey(item);
                    if (!grouped.containsKey(key)) {
                      grouped[key] = item;
                      totalPcsPerSesi[key] = 0;
                    }
                    totalPcsPerSesi[key] = totalPcsPerSesi[key]! + item.hasilPcs;
                  }

                  return Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: BorderSide(color: Colors.grey.shade200)),
                        child: Column(
                          children: grouped.values.map((item) {
                            final key = _generateKey(item);
                            final isSelected = _selectedKeys.contains(key);
                            final pcs = totalPcsPerSesi[key]!;

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              title: Text(item.model, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("${DateFormat('dd MMM yyyy').format(item.tanggal)} | ${item.sesi}"),
                              secondary: Text("$pcs Pcs", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedKeys.add(key);
                                    if (!_tarifPerModel.containsKey(item.model)) {
                                      _tarifPerModel[item.model] = 1500.0; // Default tarif bawaan
                                    }
                                  } else {
                                    _selectedKeys.remove(key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      
                      if (_selectedKeys.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildHeader("2. Tentukan Tarif Per Model", HugeIcons.strokeRoundedWallet01),
                        const SizedBox(height: 12),
                        _buildTarifEditor(grouped, totalPcsPerSesi, curFormat),
                      ]
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text("Error: $err"),
              ),
              
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              
              _buildHeader("🗄️ Riwayat Pembayaran", HugeIcons.strokeRoundedHistory),
              const SizedBox(height: 12),
              _buildRiwayatPembayaran(curFormat),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkBadge01, color: AppColors.success, size: 40),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTarifEditor(Map<String, PotongKainModel> grouped, Map<String, int> totalPcsPerSesi, NumberFormat curFormat) {
    // Kumpulkan model yang dipilih untuk dikalkulasi
    final Map<String, int> selectedModelsPcs = {};
    for (var key in _selectedKeys) {
      final item = grouped[key]!;
      selectedModelsPcs[item.model] = (selectedModelsPcs[item.model] ?? 0) + totalPcsPerSesi[key]!;
    }

    int totalPcsAll = 0;
    double totalGajiAll = 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12), 
        border: BorderSide(color: AppColors.primaryLight.withOpacity(0.5), width: 2)
      ),
      child: Column(
        children: [
          ...selectedModelsPcs.entries.map((e) {
            final model = e.key;
            final pcs = e.value;
            final tarif = _tarifPerModel[model] ?? 1500.0;
            final subtotal = pcs * tarif;

            totalPcsAll += pcs;
            totalGajiAll += subtotal;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(model, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("$pcs Pcs", style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: tarif.toInt().toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Tarif/Pcs (Rp)",
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _tarifPerModel[model] = double.tryParse(val) ?? 0;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
          
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Produksi:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              Text("$totalPcsAll Pcs", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Grand Total Gaji:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              Text(curFormat.format(totalGajiAll), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("💡 Untuk Cetak PDF, tambahkan package 'pdf' & 'printing' ke pubspec.yaml nantinya.")
                    ));
                  },
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedPrinter, color: AppColors.primary),
                  label: const Text("Cetak Slip", style: TextStyle(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _prosesPembayaran(grouped),
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedLockPassword, color: Colors.white),
                  label: const Text("Bayar & Kunci", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _prosesPembayaran(Map<String, PotongKainModel> grouped) async {
    final controller = ref.read(cuttingControllerProvider.notifier);
    
    // Looping eksekusi bayar ke database
    for (var key in _selectedKeys) {
      final item = grouped[key]!;
      final tarif = _tarifPerModel[item.model] ?? 1500.0;
      await controller.bayarSesi(
        item.tanggal.toIso8601String().split('T')[0], 
        item.sesi, 
        item.model, 
        tarif
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🎉 Pembayaran berhasil dicatat ke Riwayat!'),
        backgroundColor: AppColors.success,
      ));
      setState(() {
        _selectedKeys.clear();
      });
    }
  }

  Widget _buildRiwayatPembayaran(NumberFormat curFormat) {
    // Membaca langsung dari repository untuk riwayat 20 terakhir
    return Consumer(
      builder: (context, ref, child) {
        final repo = ref.read(cuttingRepositoryProvider);
        return FutureBuilder<List<PotongKainModel>>(
          future: repo.getSesiSudahBayar(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("Belum ada riwayat pembayaran.", style: TextStyle(color: Colors.grey));
            
            final data = snapshot.data!;
            final Map<String, PotongKainModel> unique = {};
            final Map<String, int> totalPcs = {};
            final Map<String, double> totalGaji = {};

            for (var item in data) {
              final k = _generateKey(item);
              unique[k] = item;
              totalPcs[k] = (totalPcs[k] ?? 0) + item.hasilPcs;
              totalGaji[k] = (totalGaji[k] ?? 0.0) + item.gajiTerbayar;
            }

            return Column(
              children: unique.values.map((item) {
                final k = _generateKey(item);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(backgroundColor: AppColors.background, child: HugeIcon(icon: HugeIcons.strokeRoundedMoney01, color: AppColors.success)),
                    title: Text(item.model, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${DateFormat('dd MMM yyyy').format(item.tanggal)} | ${item.sesi}\nTotal: ${totalPcs[k]} Pcs"),
                    trailing: Text(curFormat.format(totalGaji[k]), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 16)),
                  ),
                );
              }).toList(),
            );
          },
        );
      }
    );
  }

  Widget _buildHeader(String title, IconData icon) {
    return Row(
      children: [
        HugeIcon(icon: icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
