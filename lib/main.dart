import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/app.dart';
import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/core/storage/local_storage.dart';
import 'package:news_application_maker/core/supabase/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load runtime configuration from the bundled .env asset.
  await dotenv.load(fileName: '.env');

  // Initialise backend + local persistence before the first frame.
  await SupabaseService.initialize();
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
