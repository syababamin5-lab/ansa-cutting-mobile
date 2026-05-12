import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'features/dashboard/views/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Ganti dengan URL & Anon Key dari project Supabase Anda nantinya
  // Saat ini dibiarkan kosong agar UI tetap bisa di-build saat testing
  try {
    await Supabase.initialize(
      url: 'https://placeholder-project-id.supabase.co',
      anonKey: 'placeholder-anon-key',
    );
  } catch (e) {
    debugPrint("Supabase init error: $e");
  }

  runApp(
    const ProviderScope(
      child: AnsaApp(),
    ),
  );
}

class AnsaApp extends StatelessWidget {
  const AnsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ansa Cutting App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          background: AppColors.background,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
