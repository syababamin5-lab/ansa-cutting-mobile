import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../cutting/models/potong_kain_model.dart';
import '../../cutting/viewmodels/cutting_viewmodel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GajiView extends ConsumerStatefulWidget {
  const GajiView({super.key});

  @override
  ConsumerState<GajiView> createState() => _GajiViewState();
}

class _GajiViewState extends ConsumerState<GajiView> {
  bool _tampilkanHarga = true;
  final Set<String> _selectedSessions = {};
  final TextEditingController _tarifController = TextEditingController(text: "1500");
  final currencyFmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  @override
  void dispose() {
    _tarifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(laporanSelesaiProvider);

    return Scaffold(
      backgroundColor: AppColors.background, // KEMBALI KE DEEP FOREST
      appBar: AppBar(
        title: const Text('PERHITUNGAN GAJI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 18)),
        centerTitle: false,
      ),
      body: asyncData.when(
        data: (data) {
          final Map<String, List<PotongKainModel>> sessionMap = {};
          for (var item in data) {
            final key = "${DateFormat('yyyy-MM-dd').format(item.tanggal)}_${item.sesi}_${item.model}";
            sessionMap.putIfAbsent(key, () => []).add(item);
          }

          final unpaidSessions = sessionMap.values.where((items) => items.first.statusPembayaran == 'Belum').toList()
            ..sort((a, b) => a.first.tanggal.compareTo(b.first.tanggal));

          final paidSessions = sessionMap.values.where((items) => items.first.statusPembayaran == 'Lunas').toList()
            ..sort((a, b) => b.first.tanggal.compareTo(a.first.tanggal));

          return RefreshIndicator(
            onRefresh: () async => ref.read(cuttingControllerProvider.notifier).refreshData(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
              children: [
                _buildSectionHeader(Icons.fact_check_rounded, "1. Pilih Sesi yang Akan Dicairkan"),
                const SizedBox(height: 16),
                _buildSelectionTable(unpaidSessions),
                const SizedBox(height: 24),
                _buildCalculatorSection(unpaidSessions),
                const SizedBox(height: 48),
                _buildSectionHeader(Icons.history_rounded, "Riwayat Sesi yang Sudah Dibayar"),
                const SizedBox(height: 16),
                _buildHistoryTable(paidSessions),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: AppColors.error))),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildSelectionTable(List<List<PotongKainModel>> sessions) {
    if (sessions.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11),
          dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 11),
          columns: const [DataColumn(label: Text("Gaji?")), DataColumn(label: Text("Tanggal")), DataColumn(label: Text("Sesi")), DataColumn(label: Text("Model")), DataColumn(label: Text("Pcs"))],
          rows: sessions.map((items) {
            final first = items.first;
            final key = "${DateFormat('yyyy-MM-dd').format(first.tanggal)}_${first.sesi}_${first.model}";
            final isSelected = _selectedSessions.contains(key);
            final totalPcs = items.fold<int>(0, (sum, item) => sum + item.hasilPcs);
            return DataRow(selected: isSelected, cells: [
              DataCell(Checkbox(value: isSelected, activeColor: AppColors.primary, onChanged: (v) => setState(() { if (v!) _selectedSessions.add(key); else _selectedSessions.remove(key); }))),
              DataCell(Text(DateFormat('dd/MM/yy').format(first.tanggal))),
              DataCell(Text(first.sesi)),
              DataCell(Text(first.model.toUpperCase(), style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold))),
              DataCell(Text("$totalPcs", style: const TextStyle(color: Color(0xFF00CED1), fontWeight: FontWeight.bold))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCalculatorSection(List<List<PotongKainModel>> allUnpaid) {
    if (_selectedSessions.isEmpty) return const SizedBox();
    int totalPcs = 0;
    for (var sess in allUnpaid) {
      if (_selectedSessions.contains("${DateFormat('yyyy-MM-dd').format(sess.first.tanggal)}_${sess.first.sesi}_${sess.first.model}")) {
        totalPcs += sess.fold<int>(0, (sum, item) => sum + item.hasilPcs);
      }
    }
    final double tarif = double.tryParse(_tarifController.text) ?? 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.navBackground, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("TARIF/PCS", style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              TextField(
                controller: _tarifController, 
                keyboardType: TextInputType.number, 
                onChanged: (_) => setState(() {}), 
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: "0", hintStyle: TextStyle(color: Colors.white24)),
              ),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text("TOTAL PCS", style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("$totalPcs", style: const TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.w900)),
            ])),
          ]),
          const Divider(color: Colors.white10, height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("TAMPILKAN HARGA DI PDF", style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            Transform.scale(
              scale: 0.8,
              child: Switch(value: _tampilkanHarga, onChanged: (v) => setState(() => _tampilkanHarga = v), activeColor: AppColors.primary),
            ),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("TOTAL GAJI", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            Text(currencyFmt.format(totalPcs * tarif), style: const TextStyle(color: Color(0xFF00CED1), fontSize: 22, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _cetakPdf(allUnpaid, tarif), 
              icon: const Icon(Icons.print_rounded), 
              label: const Text("CETAK"), 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton(
              onPressed: () => _prosesBayarMassal(allUnpaid, tarif), 
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.background, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("PROSES BAYAR", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            )),
          ]),
        ],
      ),
    );
  }

  Future<void> _cetakPdf(List<List<PotongKainModel>> allUnpaid, double tarif) async {
    try {
      final pdf = pw.Document();
      List<List<PotongKainModel>> selected = [];
      int totalPcsAll = 0;
      for (var sess in allUnpaid) {
        if (_selectedSessions.contains("${DateFormat('yyyy-MM-dd').format(sess.first.tanggal)}_${sess.first.sesi}_${sess.first.model}")) {
          selected.add(sess);
          totalPcsAll += sess.fold<int>(0, (sum, item) => sum + item.hasilPcs);
        }
      }
      if (selected.isEmpty) return;

      pdf.addPage(pw.Page(build: (pw.Context context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _buildPdfHeader(),
        pw.SizedBox(height: 20),
        pw.Text('HALAMAN 1: RINGKASAN PER SESI', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue700)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['No', 'Tanggal', 'Sesi', 'Model', 'Pcs', if (_tampilkanHarga) 'Tarif', if (_tampilkanHarga) 'Subtotal'],
          data: List.generate(selected.length, (index) {
            final s = selected[index];
            final p = s.fold<int>(0, (sum, i) => sum + i.hasilPcs);
            return [(index + 1).toString(), DateFormat('dd/MM/yyyy').format(s.first.tanggal), s.first.sesi, s.first.model, p.toString(), if (_tampilkanHarga) currencyFmt.format(tarif), if (_tampilkanHarga) currencyFmt.format(p * tarif)];
          }),
        ),
        pw.SizedBox(height: 40),
        _buildPdfSummary(selected.length, totalPcsAll, tarif, _tampilkanHarga),
      ])));

      pdf.addPage(pw.MultiPage(build: (pw.Context context) => [
        _buildPdfHeader(),
        pw.SizedBox(height: 20),
        pw.Text('HALAMAN 2: RINCIAN DETAIL (WARNA/ROL)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue700)),
        ...selected.map((s) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(height: 16),
          pw.Container(padding: const pw.EdgeInsets.all(6), color: PdfColors.grey200, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('DETAIL: ${DateFormat('dd/MM').format(s.first.tanggal)} - ${s.first.sesi}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text('MODEL: ${s.first.model}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ])),
          pw.TableHelper.fromTextArray(
            headers: ['No', 'Warna', 'Kg', 'Pcs', if (_tampilkanHarga) 'Gaji'],
            data: List.generate(s.length, (i) => [(i+1).toString(), s[i].warna, '${s[i].kgTerpakai}kg', s[i].hasilPcs.toString(), if (_tampilkanHarga) currencyFmt.format(s[i].hasilPcs * tarif)]),
          ),
        ])),
        pw.SizedBox(height: 50),
        _buildPdfFooter(),
      ]));

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(), 
        name: 'SlipGaji_${DateFormat('ddMM_HHmm').format(DateTime.now())}.pdf'
      );
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
  }

  pw.Widget _buildPdfHeader() {
    return pw.Header(level: 0, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('ANSA-ENTERPRISE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: PdfColors.blue900)),
        pw.Text('Laporan Pembayaran Gaji Cutting', style: const pw.TextStyle(fontSize: 10)),
      ]),
      pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
    ]));
  }

  pw.Widget _buildPdfSummary(int s, int p, double t, bool h) {
    return pw.Container(padding: const pw.EdgeInsets.all(16), decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey300)), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
      pw.Column(children: [pw.Text('TOTAL SESI', style: const pw.TextStyle(fontSize: 10)), pw.Text('$s', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
      pw.Column(children: [pw.Text('TOTAL PCS', style: const pw.TextStyle(fontSize: 10)), pw.Text('$p', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
      if (h) ...[
        pw.Column(children: [pw.Text('TARIF', style: const pw.TextStyle(fontSize: 10)), pw.Text(currencyFmt.format(t), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
        pw.Column(children: [pw.Text('GRAND TOTAL', style: const pw.TextStyle(fontSize: 10)), pw.Text(currencyFmt.format(p * t), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900))]),
      ],
    ]));
  }

  pw.Widget _buildPdfFooter() {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Column(children: [pw.Text('Penerima,', style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 40), pw.Text('(____________________)')]),
      pw.SizedBox(width: 40),
      pw.Column(children: [pw.Text('Admin Ansa,', style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 40), pw.Text('(____________________)')]),
    ]);
  }

  Widget _buildHistoryTable(List<List<PotongKainModel>> sessions) {
    if (sessions.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11),
          columns: const [DataColumn(label: Text("Tgl")), DataColumn(label: Text("Sesi")), DataColumn(label: Text("Model")), DataColumn(label: Text("Pcs"))],
          rows: sessions.map((s) => DataRow(cells: [
            DataCell(Text(DateFormat('dd/MM').format(s.first.tanggal), style: const TextStyle(color: Colors.white70, fontSize: 11))),
            DataCell(Text(s.first.sesi, style: const TextStyle(color: Colors.white70, fontSize: 11))),
            DataCell(Text(s.first.model.toUpperCase(), style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 11))),
            DataCell(Text("${s.fold<int>(0, (sum, i) => sum + i.hasilPcs)}", style: const TextStyle(color: Color(0xFF00CED1), fontWeight: FontWeight.bold, fontSize: 11))),
          ])).toList(),
        ),
      ),
    );
  }

  Future<void> _prosesBayarMassal(List<List<PotongKainModel>> allUnpaid, double tarif) async {
    if (_selectedSessions.isEmpty) return;
    try {
      showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator()));
      List<int> ids = [];
      for (var sess in allUnpaid) {
        if (_selectedSessions.contains("${DateFormat('yyyy-MM-dd').format(sess.first.tanggal)}_${sess.first.sesi}_${sess.first.model}")) ids.addAll(sess.map((e) => e.id!));
      }
      await ref.read(cuttingControllerProvider.notifier).bayarSesi(ids, tarif);
      if (mounted) { Navigator.pop(context); setState(() => _selectedSessions.clear()); }
    } catch (e) { if (mounted) Navigator.pop(context); }
  }
}
