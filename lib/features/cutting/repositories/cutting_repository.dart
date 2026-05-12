import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/potong_kain_model.dart';

class CuttingRepository {
  final SupabaseClient _supabase;

  CuttingRepository(this._supabase);

  // Menggantikan get_daftar_sesi_draft() & get_detail_sesi()
  Future<List<PotongKainModel>> getDrafts() async {
    final response = await _supabase
        .from('potong_kain')
        .select()
        .eq('status', 'Draft')
        .order('tanggal', ascending: false);
    return (response as List).map((e) => PotongKainModel.fromJson(e)).toList();
  }

  // Menggantikan simpan_sesi_baru()
  Future<void> simpanSesiBaru(PotongKainModel data) async {
    await _supabase.from('potong_kain').insert(data.toJson());
  }

  // Menggantikan update_sesi_spesifik()
  Future<void> updateSesiSpesifik(String tanggal, String sesi, String model, List<PotongKainModel> listBaru) async {
    // Hapus draft lama terlebih dahulu sesuai flow Streamlit
    await _supabase
        .from('potong_kain')
        .delete()
        .eq('tanggal', tanggal)
        .eq('sesi', sesi)
        .eq('model', model)
        .eq('status', 'Draft');
    
    // Insert list detail baru
    final listJson = listBaru.map((e) => e.toJson()).toList();
    if (listJson.isNotEmpty) {
      await _supabase.from('potong_kain').insert(listJson);
    }
  }

  // Menggantikan submit_sesi_final()
  Future<void> submitSesiFinal(String tanggal, String sesi, String model) async {
    await _supabase
        .from('potong_kain')
        .update({'status': 'Selesai'})
        .eq('tanggal', tanggal)
        .eq('sesi', sesi)
        .eq('model', model)
        .eq('status', 'Draft');
  }

  // Menggantikan hapus_sesi_draft()
  Future<void> hapusSesiDraft(String tanggal, String sesi, String model) async {
    await _supabase
        .from('potong_kain')
        .delete()
        .eq('tanggal', tanggal)
        .eq('sesi', sesi)
        .eq('model', model)
        .eq('status', 'Draft');
  }

  // Menggantikan get_data_selesai() & get_sesi_selesai_hari_ini()
  Future<List<PotongKainModel>> getDataSelesai() async {
    final response = await _supabase
        .from('potong_kain')
        .select()
        .eq('status', 'Selesai')
        .order('tanggal', ascending: false);
    return (response as List).map((e) => PotongKainModel.fromJson(e)).toList();
  }

  // Menggantikan get_sesi_belum_bayar()
  Future<List<PotongKainModel>> getSesiBelumBayar() async {
    final response = await _supabase
        .from('potong_kain')
        .select()
        .eq('status', 'Selesai')
        .eq('status_pembayaran', 'Belum')
        .neq('warna', '') // Menghindari record dummy kosong dari flow awal Streamlit
        .order('tanggal', ascending: true);
    return (response as List).map((e) => PotongKainModel.fromJson(e)).toList();
  }
  
  // Menggantikan get_sesi_sudah_bayar()
  Future<List<PotongKainModel>> getSesiSudahBayar() async {
    final response = await _supabase
        .from('potong_kain')
        .select()
        .eq('status', 'Selesai')
        .eq('status_pembayaran', 'Sudah')
        .neq('warna', '')
        .order('tanggal', ascending: false)
        .limit(20);
    return (response as List).map((e) => PotongKainModel.fromJson(e)).toList();
  }

  // Menggantikan bayar_sesi()
  Future<void> bayarSesi(String tanggal, String sesi, String model, double tarifPerPcs) async {
    final records = await _supabase
        .from('potong_kain')
        .select()
        .eq('tanggal', tanggal)
        .eq('sesi', sesi)
        .eq('model', model)
        .eq('status', 'Selesai')
        .eq('status_pembayaran', 'Belum');
    
    for (var record in records) {
      int pcs = record['hasil_pcs'] ?? 0;
      double totalGaji = pcs * tarifPerPcs;
      
      await _supabase
          .from('potong_kain')
          .update({
            'status_pembayaran': 'Sudah',
            'gaji_terbayar': totalGaji
          })
          .eq('id', record['id']);
    }
  }

  // Menggantikan revert_ke_draft()
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
