import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/potong_kain_model.dart';
import '../repositories/cutting_repository.dart';

// Provider Repository Database
final cuttingRepositoryProvider = Provider<CuttingRepository>((ref) {
  return CuttingRepository(Supabase.instance.client);
});

// Stream Provider untuk Data Laporan (Realtime secara simulasi / load per request)
final draftSesiProvider = FutureProvider<List<PotongKainModel>>((ref) async {
  return ref.read(cuttingRepositoryProvider).getDrafts();
});

final laporanSelesaiProvider = FutureProvider<List<PotongKainModel>>((ref) async {
  return ref.read(cuttingRepositoryProvider).getDataSelesai();
});

final belumBayarProvider = FutureProvider<List<PotongKainModel>>((ref) async {
  return ref.read(cuttingRepositoryProvider).getSesiBelumBayar();
});

// StateNotifier untuk mengendalikan logika form dan tombol (Loading / Success / Error)
class CuttingController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  CuttingController(this.ref) : super(const AsyncValue.data(null));

  Future<void> simpanSesiBaru(PotongKainModel data) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(cuttingRepositoryProvider).simpanSesiBaru(data);
      state = const AsyncValue.data(null);
      refreshData();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> submitSesiFinal(String tanggal, String sesi, String model) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(cuttingRepositoryProvider).submitSesiFinal(tanggal, sesi, model);
      state = const AsyncValue.data(null);
      refreshData();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> bayarSesi(String tanggal, String sesi, String model, double tarifPerPcs) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(cuttingRepositoryProvider).bayarSesi(tanggal, sesi, model, tarifPerPcs);
      state = const AsyncValue.data(null);
      refreshData();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // Fungsi untuk me-refresh ulang semua data di UI jika terjadi perubahan
  void refreshData() {
    ref.invalidate(draftSesiProvider);
    ref.invalidate(laporanSelesaiProvider);
    ref.invalidate(belumBayarProvider);
  }
}

// Provider Global untuk dipakai oleh Tombol/Form di UI
final cuttingControllerProvider = StateNotifierProvider<CuttingController, AsyncValue<void>>((ref) {
  return CuttingController(ref);
});
