import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/potong_kain_model.dart';

class CuttingRepository {
  final SupabaseClient _supabase;

  CuttingRepository(this._supabase);

  Future<List<PotongKainModel>> getDrafts() async {
    final response = await _supabase
        .from('potong_kain')
        .select()
        .eq('status', 'Draft')
        .order('tanggal', ascending: false);
    return (response as List).map((e) => PotongKainModel.fromJson(e)).toList();
  }

  Future<void> simpanSesiBaru(PotongKainModel data) async {
    final json = data.toJson();
    // HAPUS ID dan kolom sensitif agar database tidak komplain
    json.remove('id');
    json.remove('status_pembayaran');
    json.remove('gaji_terbayar');

    await _supabase.from('potong_kain').insert(json);
  }

  Future<void> updateSesiSpesifik(String tanggal, String sesi, String model,
      List<PotongKainModel> listBaru) async {
    // 1. Hapus yang lama dulu
    await _supabase
        .from('potong_kain')
        .delete()
        .eq('tanggal', tanggal)
        .eq('sesi', sesi)
        .eq('model', model)
        .eq('status', 'Draft');

    // 2. Siapkan data baru
    List<Map<String, dynamic>> listJson = [];

    if (listBaru.isEmpty) {
      // Jika kosong, buat 1 baris placeholder agar sesi tidak hilang dari database
      listJson.add({
        'tanggal': tanggal,
        'sesi': sesi,
        'model': model,
        'warna': '',
        'kg_terpakai': 0,
        'hasil_pcs': 0,
        'status': 'Draft',
      });
    } else {
      listJson = listBaru.map((e) {
        final j = e.toJson();
        j.remove('id');
        j.remove('status_pembayaran');
        j.remove('gaji_terbayar');
        return j;
      }).toList();
    }

    await _supabase.from('potong_kain').insert(listJson);
  }

  Future<void> submitSesiFinal(
      String tanggal, String sesi, String model) async {
    await _supabase
        .from('potong_kain')
        .update({'status': 'Selesai'})
        .eq('tanggal', tanggal)
        .eq('sesi', sesi)
        .eq('model', model)
        .eq('status', 'Draft');
  }

  Future<void> hapusSesiDraft(String tanggal, String sesi, String model) async {
    await _supabase
        .from('potong_kain')
        .delete()
        .eq('tanggal', tanggal)
        .eq('sesi', sesi)
        .eq('model', model)
        .eq('status', 'Draft');
  }

  Future<List<PotongKainModel>> getDataSelesai() async {
    final response = await _supabase
        .from('potong_kain')
        .select()
        .or('status.eq.Selesai,status.eq.Lunas')
        .order('tanggal', ascending: false);
    return (response as List).map((e) => PotongKainModel.fromJson(e)).toList();
  }

  Future<List<PotongKainModel>> getSesiBelumBayar() async {
    final response = await _supabase
        .from('potong_kain')
        .select()
        .or('status.eq.Selesai,status.eq.Lunas')
        .neq('warna', '')
        .order('tanggal', ascending: true);

    final all =
        (response as List).map((e) => PotongKainModel.fromJson(e)).toList();
    return all.where((e) => e.statusPembayaran == 'Belum').toList();
  }

  Future<List<PotongKainModel>> getSesiSudahBayar() async {
    final response = await _supabase
        .from('potong_kain')
        .select()
        .or('status.eq.Selesai,status.eq.Lunas')
        .neq('warna', '')
        .order('tanggal', ascending: false);

    final all =
        (response as List).map((e) => PotongKainModel.fromJson(e)).toList();
    return all.where((e) => e.statusPembayaran == 'Lunas').take(20).toList();
  }

  Future<void> bayarSesi(List<int> ids, double tarifPerPcs, {DateTime? tglBayar}) async {
    // 1. Ambil data asli untuk mendapatkan hasil_pcs per ID
    final data = await _supabase
        .from('potong_kain')
        .select('id, hasil_pcs')
        .inFilter('id', ids);

    final String tgl = (tglBayar ?? DateTime.now()).toIso8601String().split('T')[0];

    // 2. Update satu per satu dengan kalkulasi gaji masing-masing
    for (var item in (data as List)) {
      final int id = item['id'];
      final int pcs = item['hasil_pcs'] ?? 0;
      final double totalGaji = pcs * tarifPerPcs;

      await _supabase.from('potong_kain').update({
        'status': 'Lunas',
        'status_pembayaran': 'Lunas',
        'gaji_terbayar': totalGaji,
        'tanggal_bayar': tgl,
      }).eq('id', id);
    }
  }

  Future<void> revertKeDraft(String tanggal, String sesi, String model) async {
    await _supabase
        .from('potong_kain')
        .update({'status': 'Draft'})
        .eq('tanggal', tanggal)
        .eq('sesi', sesi)
        .eq('model', model)
        .eq('status', 'Selesai');
  }
}
