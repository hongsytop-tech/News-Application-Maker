import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/app.dart';
import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/core/storage/local_storage.dart';
import 'package:news_application_maker/core/supabase/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load runtime configuration from the bundled .env asset. This is best-effort:
  // on some platforms a dot-prefixed asset may be missing, and the app must
  // still boot (in degraded mode) rather than show a blank screen.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Initialise an empty environment so Env.* lookups return null safely.
    dotenv.testLoad(fileInput: '');
  }

  // Initialise backend + local persistence. Backend init is a no-op when the
  // Supabase credentials are absent.
  try {
    await SupabaseService.initialize();
  } catch (error, stack) {
    debugPrint('Supabase init failed: $error\n$stack');
  }

  final localStorage = await LocalStorage.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(localStorage),
      ],
      child: const NewsApp(),
    ),
  );
}
