import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/features/update/services/update_service.dart';

final updateServiceProvider =
    Provider<UpdateService>((ref) => const UpdateService());

/// Drives the "check for updates" UI. Idle until the user taps check.
class UpdateController extends StateNotifier<AsyncValue<UpdateStatus?>> {
  UpdateController(this._service) : super(const AsyncData(null));

  final UpdateService _service;

  Future<void> check() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.check);
  }

  void applyUpdate() => _service.applyUpdate();
}

final updateControllerProvider =
    StateNotifierProvider<UpdateController, AsyncValue<UpdateStatus?>>((ref) {
  return UpdateController(ref.watch(updateServiceProvider));
});
