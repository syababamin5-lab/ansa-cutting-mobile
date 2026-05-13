import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../models/potong_kain_model.dart';
import '../viewmodels/cutting_viewmodel.dart';

class InputDetailScreen extends ConsumerStatefulWidget {
  final PotongKainModel session;
  final bool isDraft; 

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
    try {
      final repo = ref.read(cuttingRepositoryProvider);
      final strTanggal = widget.session.tanggal.toIso8601String().split('T')[0];

      if (!widget.isDraft) {
        await repo.revertKeDraft(strTanggal, widget.session.sesi, widget.session.model);
        ref.read(cuttingControllerProvider.notifier).refreshData();
      }

      final res = await Supabase.instance.client
          .from('potong_kain')
          .select()
          .eq('tanggal', strTanggal)
          .eq('sesi', widget.session.sesi)
          .eq('model', widget.session.model)
          .eq('status', 'Draft');
      
      if (mounted) {
        setState(() {
          _items = (res as List).map((e) => PotongKainModel.fromJson(e)).toList();
          _items.removeWhere((item) => item.warna.isEmpty && item.kgTerpakai == 0 && item.hasilPcs == 0);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showStatus(context, "Gagal memuat data: $e", isError: true);
      }
    }
  }

  void _showStatus(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
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
    try {
      final repo = ref.read(cuttingRepositoryProvider);
      final strTanggal = widget.session.tanggal.toIso8601String().split('T')[0];
      
      await repo.updateSesiSpesifik(strTanggal, widget.session.sesi, widget.session.model, _items);
      ref.read(cuttingControllerProvider.notifier).refreshData();
      
      if (mounted) {
        _showStatus(context, "Draft Berhasil Disimpan!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showStatus(context, "Gagal menyimpan: $e", isError: true);
      }
    }
  }

  Future<void> _submitSelesai() async {
    if (_items.isEmpty || _items.any((e) => e.warna.isEmpty)) {
      _showStatus(context, "Isi semua data warna terlebih dahulu!", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(cuttingRepositoryProvider);
      final strTanggal = widget.session.tanggal.toIso8601String().split('T')[0];
      
      await repo.updateSesiSpesifik(strTanggal, widget.session.sesi, widget.session.model, _items);
      await ref.read(cuttingControllerProvider.notifier).submitSesiFinal(strTanggal, widget.session.sesi, widget.session.model);
      
      if (mounted) {
        _showStatus(context, "Sesi Berhasil Diselesaikan!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showStatus(context, "Gagal finalisasi: $e", isError: true);
      }
    }
  }

  Future<void> _hapusSesi() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(cuttingRepositoryProvider);
      final strTanggal = widget.session.tanggal.toIso8601String().split('T')[0];
      
      await repo.hapusSesiDraft(strTanggal, widget.session.sesi, widget.session.model);
      ref.read(cuttingControllerProvider.notifier).refreshData();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showStatus(context, "Gagal menghapus: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('SESI: ${widget.session.model}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
                tooltip: "Hapus Sesi",
                onPressed: () => _hapusSesi(),
              )
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("BAKUL POTONGAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.5)),
                    GestureDetector(
                      onTap: _addNewRow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, color: AppColors.background, size: 18),
                            SizedBox(width: 8),
                            Text("TAMBAH", style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Expanded(
                child: _items.isEmpty && !_isLoading
                  ? const Center(child: Text("Belum ada data kain.", style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _items.length,
                      itemBuilder: (context, index) => _buildFormRow(index),
                    ),
              ),
              _buildBottomButtons(),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 24),
                    Text("Sedang Memproses...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.none, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFormRow(int index) {
    final item = _items[index];
    return Container(
      key: ValueKey("row_$index"),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ITEM #${index + 1}", style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 12, letterSpacing: 1)),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.cancel_rounded, color: AppColors.error, size: 24),
                onPressed: () => setState(() => _items.removeAt(index)),
              )
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: "WARNA KAIN",
            initialValue: item.warna,
            onChanged: (val) {
              setState(() {
                _items[index] = item.copyWith(warna: val);
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: "BERAT (KG)",
                  initialValue: item.kgTerpakai == 0 ? '' : item.kgTerpakai.toString(),
                  isNumber: true,
                  onChanged: (val) {
                    // Penanganan koma menjadi titik
                    final cleanedVal = val.replaceAll(',', '.');
                    setState(() {
                      _items[index] = item.copyWith(kgTerpakai: double.tryParse(cleanedVal) ?? 0);
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: "HASIL (PCS)",
                  initialValue: item.hasilPcs == 0 ? '' : item.hasilPcs.toString(),
                  isNumber: true,
                  onChanged: (val) {
                    setState(() {
                      _items[index] = item.copyWith(hasilPcs: int.tryParse(val) ?? 0);
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required String label, required String initialValue, required Function(String) onChanged, bool isNumber = false}) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
        filled: true,
        fillColor: AppColors.navBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: BoxDecoration(
        color: AppColors.navBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -10))]
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _simpanDanKembali,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18), 
                side: const BorderSide(color: AppColors.primary, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
              ),
              child: const Text("SIMPAN DRAFT", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: ElevatedButton(
                onPressed: _submitSelesai,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18), 
                  backgroundColor: Colors.transparent, 
                  foregroundColor: AppColors.background,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                child: const Text("SUBMIT FINAL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
