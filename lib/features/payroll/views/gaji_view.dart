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
  DateTime _tglBayarSelected = DateTime.now(); // Variabel Tanggal Bayar
  final Set<String> _selectedSessions = {};
  final currencyFmt =
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  final Map<String, TextEditingController> _rateControllers = {};

  TextEditingController _getRateController(String key) {
    return _rateControllers.putIfAbsent(
        key, () => TextEditingController(text: "")); // Kosongkan di sini
  }

  @override
  void dispose() {
    for (var controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(laporanSelesaiProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PERHITUNGAN GAJI',
            style: TextStyle(
                fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 18)),
        centerTitle: false,
      ),
      body: asyncData.when(
        data: (data) {
          final Map<String, List<PotongKainModel>> sessionMap = {};
          for (var item in data) {
            final key =
                "${DateFormat('yyyy-MM-dd').format(item.tanggal)}_${item.sesi}_${item.model}";
            sessionMap.putIfAbsent(key, () => []).add(item);
          }

          final unpaidSessions = sessionMap.values
              .where((items) => items.first.statusPembayaran == 'Belum')
              .toList()
            ..sort((a, b) => a.first.tanggal.compareTo(b.first.tanggal));

          final paidSessions = sessionMap.values
              .where((items) => items.first.statusPembayaran == 'Lunas')
              .toList()
            ..sort((a, b) => b.first.tanggal.compareTo(a.first.tanggal));

          return RefreshIndicator(
            onRefresh: () async =>
                ref.read(cuttingControllerProvider.notifier).refreshData(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
              children: [
                _buildSectionHeader(Icons.fact_check_rounded,
                    "1. Pilih Sesi & Isi Tarif per Model"),
                const SizedBox(height: 16),
                _buildSelectionTable(unpaidSessions),
                const SizedBox(height: 24),
                _buildCalculatorSection(unpaidSessions),
                const SizedBox(height: 48),
                _buildSectionHeader(
                    Icons.history_rounded, "Riwayat Sesi yang Sudah Dibayar"),
                const SizedBox(height: 16),
                _buildHistoryTable(paidSessions),
              ],
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
            child: Text("Error: $err",
                style: const TextStyle(color: AppColors.error))),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Text(title.toUpperCase(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5)),
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
      child: SizedBox(
        width: MediaQuery.of(context).size.width - 42,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            horizontalMargin: 10,
            headingTextStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11),
            dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 11),
            columns: const [
              DataColumn(label: Text("Gaji?")),
              DataColumn(label: Text("Tgl")),
              DataColumn(label: Text("S")),
              DataColumn(label: Text("Model")),
              DataColumn(label: Text("Pcs")),
              DataColumn(label: Text("Tarif")),
              DataColumn(label: Text("Dtl")),
            ],
            rows: sessions.map((items) {
              final first = items.first;
              final key =
                  "${DateFormat('yyyy-MM-dd').format(first.tanggal)}_${first.sesi}_${first.model}";
              final isSelected = _selectedSessions.contains(key);
              final totalPcs =
                  items.fold<int>(0, (sum, item) => sum + item.hasilPcs);
              final controller = _getRateController(key);

              return DataRow(selected: isSelected, cells: [
                DataCell(Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() {
                          if (v!) {
                            _selectedSessions.add(key);
                          } else {
                            _selectedSessions.remove(key);
                          }
                        }))),
                DataCell(Text(DateFormat('dd/MM').format(first.tanggal))),
                DataCell(Text(first.sesi.replaceAll('Sesi ', ''))),
                DataCell(SizedBox(
                  width: 70,
                  child: Text(first.model.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold)),
                )),
                DataCell(Text("$totalPcs",
                    style: const TextStyle(
                        color: Color(0xFF00CED1),
                        fontWeight: FontWeight.bold))),
                DataCell(Container(
                  width: 65,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                        isDense: true, 
                        border: InputBorder.none, 
                        hintText: "1500",
                        hintStyle: const TextStyle(color: Colors.white10)),
                    onChanged: (_) => setState(() {}),
                  ),
                )),
                DataCell(IconButton(
                  onPressed: () =>
                      _showHistoryDetailPopup(context, first, items),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.visibility_rounded,
                      color: Colors.white38, size: 18),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCalculatorSection(List<List<PotongKainModel>> allUnpaid) {
    if (_selectedSessions.isEmpty) return const SizedBox();
    int totalPcs = 0;
    double grandTotalGaji = 0;

    for (var sess in allUnpaid) {
      final key =
          "${DateFormat('yyyy-MM-dd').format(sess.first.tanggal)}_${sess.first.sesi}_${sess.first.model}";
      if (_selectedSessions.contains(key)) {
        final pcs = sess.fold<int>(0, (sum, item) => sum + item.hasilPcs);
        final tarif = double.tryParse(_rateControllers[key]?.text ?? "0") ?? 0;
        totalPcs += pcs;
        grandTotalGaji += (pcs * tarif);
      }
    }

    bool isAllRatesFilled = _selectedSessions.isNotEmpty &&
        _selectedSessions.every((key) {
          final rate = double.tryParse(_rateControllers[key]?.text ?? "") ?? 0;
          return rate > 0;
        });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.navBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)
        ],
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("TOTAL PCS TERPILIH",
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            Text("$totalPcs",
                style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
          ]),
          const Divider(color: Colors.white10, height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("TAMPILKAN HARGA DI PDF",
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                  value: _tampilkanHarga,
                  onChanged: (v) => setState(() => _tampilkanHarga = v),
                  activeThumbColor: AppColors.primary),
            ),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("TANGGAL PEMBAYARAN",
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _tglBayarSelected,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(primary: AppColors.primary),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _tglBayarSelected = picked);
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
              label: Text(DateFormat('dd MMMM yyyy').format(_tglBayarSelected),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05), padding: const EdgeInsets.symmetric(horizontal: 16)),
            ),
          ]),
          const Divider(color: Colors.white10, height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("TOTAL GAJI",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            Text(currencyFmt.format(grandTotalGaji),
                style: TextStyle(
                    color: isAllRatesFilled ? const Color(0xFF00CED1) : Colors.white24,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: ElevatedButton.icon(
              onPressed: isAllRatesFilled ? () => _cetakPdf(allUnpaid) : null,
              icon: const Icon(Icons.print_rounded),
              label: const Text("CETAK"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white.withOpacity(0.05),
                  disabledForegroundColor: Colors.white10,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
            )),
            const SizedBox(width: 12),
            Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isAllRatesFilled ? () => _prosesBayarMassal(allUnpaid) : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: isAllRatesFilled ? AppColors.primary : Colors.white10,
                      foregroundColor: isAllRatesFilled ? AppColors.background : Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: Text(isAllRatesFilled ? "PROSES BAYAR" : "ISI TARIF DULU",
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: 1)),
                )),
          ]),
        ],
      ),
    );
  }

  Future<void> _cetakPdf(List<List<PotongKainModel>> allData, {bool isDirectPrint = false}) async {
    try {
      final pdf = pw.Document();
      List<Map<String, dynamic>> selectedData = [];
      int totalPcsAll = 0;
      double grandTotalAll = 0;

      for (var sess in allData) {
        final first = sess.first;
        final key = "${DateFormat('yyyy-MM-dd').format(first.tanggal)}_${first.sesi}_${first.model}";
        
        // Cek apakah dicentang ATAU ini adalah cetak langsung dari riwayat
        if (isDirectPrint || _selectedSessions.contains(key)) {
          final pcs = sess.fold<int>(0, (sum, item) => sum + item.hasilPcs);
          
          double tarif;
          double subtotal;

          if (first.statusPembayaran == 'Lunas') {
            // Jika sudah lunas, gunakan data dari database
            subtotal = sess.fold<double>(0, (sum, item) => sum + item.gajiTerbayar);
            tarif = pcs > 0 ? subtotal / pcs : 0;
          } else {
            // Jika belum lunas, gunakan tarif dari input kalkulator
            tarif = double.tryParse(_rateControllers[key]?.text ?? "0") ?? 0;
            subtotal = pcs * tarif;
          }

          selectedData.add({
            'items': sess,
            'pcs': pcs,
            'tarif': tarif,
            'subtotal': subtotal
          });
          totalPcsAll += pcs;
          grandTotalAll += subtotal;
        }
      }
      if (selectedData.isEmpty) return;

      pdf.addPage(pw.Page(
          build: (pw.Context context) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfHeader(),
                    pw.SizedBox(height: 20),
                    pw.Text('HALAMAN 1: RINGKASAN PER SESI',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.blue700)),
                    pw.SizedBox(height: 16),
                    pw.TableHelper.fromTextArray(
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      headers: [
                        'No',
                        'Tanggal',
                        'Sesi',
                        'Model',
                        'Pcs',
                        if (_tampilkanHarga) 'Tarif',
                        if (_tampilkanHarga) 'Subtotal'
                      ],
                      data: List.generate(selectedData.length, (index) {
                        final data = selectedData[index];
                        final s = data['items'] as List<PotongKainModel>;
                        return [
                          (index + 1).toString(),
                          DateFormat('dd/MM/yyyy').format(s.first.tanggal),
                          s.first.sesi,
                          s.first.model,
                          data['pcs'].toString(),
                          if (_tampilkanHarga)
                            currencyFmt.format(data['tarif']),
                          if (_tampilkanHarga)
                            currencyFmt.format(data['subtotal'])
                        ];
                      }),
                    ),
                    pw.SizedBox(height: 40),
                    _buildPdfSummary(selectedData.length, totalPcsAll,
                        grandTotalAll, _tampilkanHarga),
                  ])));

      pdf.addPage(pw.MultiPage(
          build: (pw.Context context) => [
                _buildPdfHeader(),
                pw.SizedBox(height: 20),
                pw.Text('HALAMAN 2: RINCIAN DETAIL (WARNA/ROL)',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: PdfColors.blue700)),
                ...selectedData.map((data) {
                  final s = data['items'] as List<PotongKainModel>;
                  final t = data['tarif'] as double;
                  return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 16),
                        pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            color: PdfColors.grey200,
                            child: pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                      'DETAIL: ${DateFormat('dd/MM').format(s.first.tanggal)} - ${s.first.sesi}',
                                      style: pw.TextStyle(
                                          fontWeight: pw.FontWeight.bold,
                                          fontSize: 10)),
                                  pw.Text('MODEL: ${s.first.model}',
                                      style: pw.TextStyle(
                                          fontWeight: pw.FontWeight.bold,
                                          fontSize: 10)),
                                ])),
                        pw.TableHelper.fromTextArray(
                          headers: [
                            'No',
                            'Warna',
                            'Kg',
                            'Pcs',
                            if (_tampilkanHarga) 'Gaji'
                          ],
                          data: List.generate(
                              s.length,
                              (i) => [
                                    (i + 1).toString(),
                                    s[i].warna,
                                    '${s[i].kgTerpakai}kg',
                                    s[i].hasilPcs.toString(),
                                    if (_tampilkanHarga)
                                      currencyFmt.format(s[i].hasilPcs * t)
                                  ]),
                        ),
                      ]);
                }),
                pw.SizedBox(height: 50),
                _buildPdfFooter(),
              ]));

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name:
              'SlipGaji_${DateFormat('ddMM_HHmm').format(DateTime.now())}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  pw.Widget _buildPdfHeader() {
    return pw.Header(
        level: 0,
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ANSA-ENTERPRISE',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 20,
                            color: PdfColors.blue900)),
                    pw.Text('Laporan Pembayaran Gaji Cutting',
                        style: const pw.TextStyle(fontSize: 10)),
                  ]),
              pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 10)),
            ]));
  }

  pw.Widget _buildPdfSummary(int s, int p, double grandTotal, bool h) {
    return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300)),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(children: [
                pw.Text('TOTAL SESI', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('$s',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
              ]),
              pw.Column(children: [
                pw.Text('TOTAL PCS', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('$p',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
              ]),
              if (h) ...[
                pw.Column(children: [
                  pw.Text('GRAND TOTAL GAJI',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(currencyFmt.format(grandTotal),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                          color: PdfColors.blue900))
                ]),
              ],
            ]));
  }

  pw.Widget _buildPdfFooter() {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Column(children: [
        pw.Text('Penerima,', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 40),
        pw.Text('(____________________)')
      ]),
      pw.SizedBox(width: 40),
      pw.Column(children: [
        pw.Text('Admin Ansa,', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 40),
        pw.Text('(____________________)')
      ]),
    ]);
  }

  Widget _buildHistoryTable(List<List<PotongKainModel>> sessions) {
    if (sessions.isEmpty) return const SizedBox();
    return Column(
      children: sessions.map((items) {
        final first = items.first;
        final totalPcs = items.fold<int>(0, (sum, item) => sum + item.hasilPcs);
        final totalGaji = items.fold<double>(0, (sum, item) => sum + (item.gajiTerbayar ?? 0));

        return GestureDetector(
          onTap: () => _showHistoryDetailPopup(context, first, items),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.success.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(first.model.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(
                            "Cutting: ${DateFormat('dd MMM yyyy').format(first.tanggal)} | ${first.sesi}",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        if (first.tanggalBayar != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                "Dibayar: ${DateFormat('dd MMM yyyy').format(first.tanggalBayar!)}",
                                style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success.withOpacity(0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 10),
                          SizedBox(width: 4),
                          Text("PAID",
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniStat("TOTAL PCS", "$totalPcs", const Color(0xFFFFD700)),
                    _buildMiniStat("TOTAL GAJI", currencyFmt.format(totalGaji), const Color(0xFF00CED1)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showHistoryDetailPopup(BuildContext context, PotongKainModel first, List<PotongKainModel> items) {
    final totalPcs = items.fold<int>(0, (sum, item) => sum + item.hasilPcs);
    final totalKg = items.fold<double>(0, (sum, item) => sum + item.kgTerpakai);
    final totalGaji = items.fold<double>(0, (sum, item) => sum + (item.gajiTerbayar ?? 0));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text("RINCIAN PEMBAYARAN",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 20),
            _buildPopupRow("Model", first.model.toUpperCase()),
            _buildPopupRow("Sesi", first.sesi),
            _buildPopupRow("Tgl Cutting", DateFormat('dd MMMM yyyy').format(first.tanggal)),
            if (first.tanggalBayar != null)
              _buildPopupRow("Tgl Bayar", DateFormat('dd MMMM yyyy').format(first.tanggalBayar!), color: AppColors.success),
            _buildPopupRow(
              "Status", 
              first.statusPembayaran == 'Lunas' ? "LUNAS (PAID)" : "BELUM DIBAYAR", 
              color: first.statusPembayaran == 'Lunas' ? AppColors.success : AppColors.warning
            ),
            const Divider(color: Colors.white10, height: 32),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text("${index + 1}.", style: const TextStyle(color: Colors.white24, fontSize: 12)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(item.warna.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                        Text("${item.kgTerpakai} Kg", style: const TextStyle(color: Color(0xFF00CED1), fontSize: 12)),
                        const SizedBox(width: 16),
                        Text("${item.hasilPcs} Pcs", style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10, height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat("TOTAL KG", "${totalKg.toStringAsFixed(1)} Kg", Colors.white70),
                _buildMiniStat("TOTAL PCS", "$totalPcs Pcs", Colors.white70),
                _buildMiniStat("TOTAL GAJI", currencyFmt.format(totalGaji), AppColors.primary),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _cetakPdf([items], isDirectPrint: true);
                    },
                    icon: const Icon(Icons.print_rounded),
                    label: const Text("CETAK PDF"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("TUTUP", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupRow(String label, String value, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Future<void> _prosesBayarMassal(List<List<PotongKainModel>> allUnpaid) async {
    if (_selectedSessions.isEmpty) return;
    try {
      showDialog(
          context: context,
          builder: (c) => const Center(child: CircularProgressIndicator()));

      for (var sess in allUnpaid) {
        final key =
            "${DateFormat('yyyy-MM-dd').format(sess.first.tanggal)}_${sess.first.sesi}_${sess.first.model}";
        if (_selectedSessions.contains(key)) {
          final tarif = double.tryParse(_rateControllers[key]?.text ?? "0") ?? 0;
          final ids = sess.map((e) => e.id!).toList();
          await ref.read(cuttingControllerProvider.notifier).bayarSesi(
            ids, 
            tarif, 
            tglBayar: _tglBayarSelected // Mengirim tanggal manual
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        setState(() => _selectedSessions.clear());
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("GAGAL MEMPROSES: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
