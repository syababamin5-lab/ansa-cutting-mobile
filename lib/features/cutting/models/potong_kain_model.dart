class PotongKainModel {
  final int? id;
  final DateTime tanggal;
  final String sesi;
  final String model;
  final String warna;
  final double kgTerpakai;
  final int hasilPcs;
  final String status;
  final String statusPembayaran;
  final double gajiTerbayar;

  PotongKainModel({
    this.id,
    required this.tanggal,
    required this.sesi,
    required this.model,
    required this.warna,
    required this.kgTerpakai,
    required this.hasilPcs,
    required this.status,
    required this.statusPembayaran,
    required this.gajiTerbayar,
  });

  PotongKainModel copyWith({
    int? id,
    DateTime? tanggal,
    String? sesi,
    String? model,
    String? warna,
    double? kgTerpakai,
    int? hasilPcs,
    String? status,
    String? statusPembayaran,
    double? gajiTerbayar,
  }) {
    return PotongKainModel(
      id: id ?? this.id,
      tanggal: tanggal ?? this.tanggal,
      sesi: sesi ?? this.sesi,
      model: model ?? this.model,
      warna: warna ?? this.warna,
      kgTerpakai: kgTerpakai ?? this.kgTerpakai,
      hasilPcs: hasilPcs ?? this.hasilPcs,
      status: status ?? this.status,
      statusPembayaran: statusPembayaran ?? this.statusPembayaran,
      gajiTerbayar: gajiTerbayar ?? this.gajiTerbayar,
    );
  }

  factory PotongKainModel.fromJson(Map<String, dynamic> json) {
    // Mencoba berbagai kemungkinan nama kolom berat/kg
    final rawKg = json['kg_terpakai'] ?? json['kg'] ?? json['berat'] ?? 0;
    
    return PotongKainModel(
      id: json['id'],
      tanggal: DateTime.parse(json['tanggal'].toString()),
      sesi: json['sesi'] ?? '',
      model: json['model'] ?? '',
      warna: json['warna'] ?? '',
      kgTerpakai: double.tryParse(rawKg.toString()) ?? 0.0,
      hasilPcs: json['hasil_pcs'] ?? 0,
      status: json['status'] ?? 'Draft',
      statusPembayaran: json['status'] == 'Lunas' ? 'Lunas' : 'Belum',
      gajiTerbayar: 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    // HANYA kirim kolom yang pasti ada di database standar
    final map = {
      if (id != null) 'id': id,
      'tanggal': tanggal.toIso8601String().split('T')[0],
      'sesi': sesi,
      'model': model,
      'warna': warna,
      'kg_terpakai': kgTerpakai, // Gunakan nama kolom yang paling standar
      'hasil_pcs': hasilPcs,
      'status': status,
    };
    return map;
  }
}
