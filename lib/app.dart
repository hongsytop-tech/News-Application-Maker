import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/router/app_router.dart';
import 'package:news_application_maker/core/theme/app_theme.dart';
import 'package:news_application_maker/features/update/providers/update_provider.dart';

class NewsApp extends ConsumerStatefulWidget {
  const NewsApp({super.key});

  @override
  ConsumerState<NewsApp> createState() => _NewsAppState();
}

class _NewsAppState extends ConsumerState<NewsApp> {
  @override
  void initState() {
    super.initState();
    // On the web, automatically pick up a newly deployed build at launch
    // (reload is guarded against loops). Native apps update via the stores.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(updateServiceProvider).autoApplyIfAvailable();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'News',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
