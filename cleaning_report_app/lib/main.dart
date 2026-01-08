import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'core/api/gas_api_client.dart';
import 'features/auth/presentation/pin_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/report/presentation/cleaning_report_screen.dart';
import 'features/report/presentation/expense_report_screen.dart';
import 'features/history/presentation/history_screen.dart';

void main() {
  runApp(const ProviderScope(child: CleaningReportApp()));
}

class CleaningReportApp extends StatelessWidget {
  const CleaningReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'かんたん清掃報告',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const PinScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/report/cleaning',
      builder: (context, state) => const CleaningReportScreen(),
    ),
    GoRoute(
      path: '/report/expense',
      builder: (context, state) => const ExpenseReportScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
  ],
);
