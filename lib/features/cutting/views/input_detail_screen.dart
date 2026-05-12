import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../models/potong_kain_model.dart';
import '../viewmodels/cutting_viewmodel.dart';

class InputDetailScreen extends ConsumerStatefulWidget {
  final PotongKainModel session;
  final bool isDraft; // Jika false, ini artinya kita Edit data Selesai, butuh di-revert ke Draft dulu.

  const InputDetailScreen({super.key, required this.session, required this.isDraft});

  @override
  ConsumerState<InputDetailScreen> createState() => _InputDetailScreenState();
}

class _InputDetailScreenState extends ConsumerState<InputDetailScreen> {
  bool _isLoading = true;
  List<PotongKainModel> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = ref.read(cuttingRepositoryProvider);
    final strTanggal = widget.session.tanggal.toIso8601String().split('T')[0];

    // Jika diedit dari Tab "Selesai Hari Ini", kembalikan statusnya ke Draft di DB
    if (!widget.isDraft) {
      await repo.revertKeDraft(strTanggal, widget.session.sesi, widget.session.model);
      ref.read(cuttingControllerProvider.notifier).refreshData();
    }

    // Ambil detail sesi (bakul potongan)
    final res = await Supabase.instance.client
        .from('potong_kain')
        .select()
        .eq('tanggal', strTanggal)
        .eq('sesi', widget.session.sesi)
        .eq('model', widget.session.model)
        .eq('status', 'Draft');
    
    setState(() {
      _items = (res as List).map((e) => PotongKainModel.fromJson(e)).toList();
      // Filter dummy row kosong
      _items.removeWhere((item) => item.warna.isEmpty && item.kgTerpakai == 0 && item.hasilPcs == 0);
      _isLoading = false;
    });
  }

  void _addNewRow() {
    setState(() {
      _items.add(
        PotongKainModel(
          tanggal: widget.session.tanggal,
          sesi: widget.session.sesi,
          model: widget.session.model,
          warna: '',
          kgTerpakai: 0,
          hasilPcs: 0,
          status: 'Draft',
          statusPembayaran: 'Belum',
          gajiTerbayar: 0,
        )
      );
    });
  }

  Future<void> _simpanDanKembali() async {
    setState(() => _isLoading = true);
    final repo = ref.read(cuttingRepositoryProvider);
    final strTanggal = widget.session.tanggal.toIso8601String().split('T')[0];
    
    await repo.updateSesiSpesifik(strTanggal, widget.session.sesi, widget.session.model, _items);
    ref.read(cuttingControllerProvider.notifier).refreshData();
    
    if (mounted) Navigator.pop(context);
  }

  Future<void> _submitSelesai() async {
    if (_items.isEmpty || _items.any((e) => e.warna.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Isi semua data warna terlebih dahulu!')));
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(cuttingRepositoryProvider);
    final strTanggal = widget.session.tanggal.toIso8601String().split('T')[0];
    
    // Simpan tabel
    await repo.updateSesiSpesifik(strTanggal, widget.session.sesi, widget.session.model, _items);
    // Finalisasi Sesi
    await ref.read(cuttingControllerProvider.notifier).submitSesiFinal(strTanggal, widget.session.sesi, widget.session.model);
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🎉 Sesi Berhasil Diselesaikan!'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _hapusSesi() async {
    setState(() => _isLoading = true);
    final repo = ref.read(cuttingRepositoryProvider);
    final strTanggal = widget.session.tanggal.toIso8601String().split('T')[0];
    
    await repo.hapusSesiDraft(strTanggal, widget.session.sesi, widget.session.model);
    ref.read(cuttingControllerProvider.notifier).refreshData();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit: ${widget.session.model}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, color: Colors.white),
            tooltip: "Padam Sesi",
            onPressed: () => _hapusSesi(),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.background,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("🧺 Bakul Potongan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  TextButton.icon(
                    onPressed: _addNewRow,
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: AppColors.primary, size: 20),
                    label: const Text("Tambah Warna", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                ? const Center(child: Text("Belum ada data kain. Tekan 'Tambah Warna'.", style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) => _buildFormRow(index),
                  ),
            ),
            _buildBottomButtons(),
          ],
        ),
    );
  }

  Widget _buildFormRow(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Item #${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, color: AppColors.error, size: 20),
                  onPressed: () => setState(() => _items.removeAt(index)),
                )
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.warna,
              decoration: InputDecoration(
                labelText: "Warna Kain", 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), 
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              ),
              onChanged: (val) => _items[index] = PotongKainModel(
                id: item.id, tanggal: item.tanggal, sesi: item.sesi, model: item.model,
                warna: val, kgTerpakai: item.kgTerpakai, hasilPcs: item.hasilPcs, status: item.status, statusPembayaran: item.statusPembayaran, gajiTerbayar: item.gajiTerbayar
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.kgTerpakai == 0 ? '' : item.kgTerpakai.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Berat (Kg)", 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), 
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    ),
                    onChanged: (val) => _items[index] = PotongKainModel(
                      id: item.id, tanggal: item.tanggal, sesi: item.sesi, model: item.model,
                      warna: item.warna, kgTerpakai: double.tryParse(val) ?? 0, hasilPcs: item.hasilPcs, status: item.status, statusPembayaran: item.statusPembayaran, gajiTerbayar: item.gajiTerbayar
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: item.hasilPcs == 0 ? '' : item.hasilPcs.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Hasil (Pcs)", 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), 
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    ),
                    onChanged: (val) => _items[index] = PotongKainModel(
                      id: item.id, tanggal: item.tanggal, sesi: item.sesi, model: item.model,
                      warna: item.warna, kgTerpakai: item.kgTerpakai, hasilPcs: int.tryParse(val) ?? 0, status: item.status, statusPembayaran: item.statusPembayaran, gajiTerbayar: item.gajiTerbayar
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _simpanDanKembali,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16), 
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: const Text("💾 Simpan", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _submitSelesai,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16), 
                backgroundColor: AppColors.primary, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: const Text("🚀 SELESAI", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
