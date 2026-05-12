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

  factory PotongKainModel.fromJson(Map<String, dynamic> json) {
    return PotongKainModel(
      id: json['id'],
      tanggal: DateTime.parse(json['tanggal'].toString()),
      sesi: json['sesi'] ?? '',
      model: json['model'] ?? '',
      warna: json['warna'] ?? '',
      kgTerpakai: (json['kg_terpakai'] ?? 0).toDouble(),
      hasilPcs: json['hasil_pcs'] ?? 0,
      status: json['status'] ?? 'Draft',
      statusPembayaran: json['status_pembayaran'] ?? 'Belum',
      gajiTerbayar: (json['gaji_terbayar'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tanggal': tanggal.toIso8601String().split('T')[0], // Mengambil format YYYY-MM-DD
      'sesi': sesi,
      'model': model,
      'warna': warna,
      'kg_terpakai': kgTerpakai,
      'hasil_pcs': hasilPcs,
      'status': status,
      'status_pembayaran': statusPembayaran,
      'gaji_terbayar': gajiTerbayar,
    };
  }
}
