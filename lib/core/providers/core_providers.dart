import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/storage/local_storage.dart';

/// Exposes the shared [LocalStorage] instance to the widget tree.
///
/// Overridden with a concrete value in `main()` after the instance has been
/// asynchronously created, so feature providers can read it synchronously.
final localStorageProvider = Provider<LocalStorage>(
  (ref) => throw UnimplementedError(
    'localStorageProvider must be overridden in ProviderScope.',
  ),
);
