import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/providers/auth_provider.dart';
import 'package:inventory_manager_flutter/views/splash_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  final authProvider = AuthProvider();
  await authProvider.init();

  final inventoryProvider = InventoryProvider();
  await inventoryProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: inventoryProvider),
      ],
      child: const AssetFlowApp(),
    ),
  );
}

class AssetFlowApp extends StatelessWidget {
  const AssetFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AssetFlow Mobile',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF111827),
          background: Color(0xFF0B0F19),
          error: Color(0xFFF43F5E),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFFF3F4F6),
          onBackground: Color(0xFFF3F4F6),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, letterSpacing: -0.5),
          titleMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontFamily: 'Inter', color: Color(0xFF9CA3AF)),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1F2937).withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF111827),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1F2937).withOpacity(0.4),
          labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home: const ElegantSplashView(),
    );
  }
}