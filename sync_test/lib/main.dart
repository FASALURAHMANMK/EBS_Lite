import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_providers.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://joouvaddwlpqicptkxyd.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impvb3V2YWRkd2xwcWljcHRreHlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0ODk4NTEsImV4cCI6MjA3MzA2NTg1MX0.R2QfeTBD2OokvbzihW3_81GXY9ArIVASCwAyG7iZp68',
    ),
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo);
    return MaterialApp(
      title: 'Sync Engine Demo',
      theme: theme,
      home: const HomeScreen(),
    );
  }
}
