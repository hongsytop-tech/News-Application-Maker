import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:news_application_maker/features/update/services/reload.dart';

/// Result of an update check.
class UpdateStatus {
  const UpdateStatus({
    required this.current,
    this.latest,
    this.available = false,
  });

  /// Build id compiled into the running app.
  final String current;

  /// Build id currently deployed on the server (null if it couldn't be read).
  final String? latest;

  /// True when a newer build is available to load.
  final bool available;

  String get currentShort => _short(current);
  String? get latestShort => latest == null ? null : _short(latest!);

  static String _short(String v) => v.length > 7 ? v.substring(0, 7) : v;
}

/// Checks whether the deployed web build is newer than the running one, and
/// applies the update by reloading.
///
/// The build id is injected at build time via `--dart-define=BUILD_ID=<sha>`,
/// and CI writes the same value to `version-info.json` next to the app. The
/// service worker is disabled, so reloading fetches the new build.
class UpdateService {
  const UpdateService();

  static const currentBuild =
      String.fromEnvironment('BUILD_ID', defaultValue: 'dev');

  Future<UpdateStatus> check() async {
    final latest = await _fetchLatest();
    final available =
        latest != null && currentBuild != 'dev' && latest != currentBuild;
    return UpdateStatus(
      current: currentBuild,
      latest: latest,
      available: available,
    );
  }

  Future<String?> _fetchLatest() async {
    try {
      final uri = Uri.base.resolve('version-info.json').replace(
        queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final res = await http.get(uri, headers: {'cache-control': 'no-cache'});
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is Map && body['build'] is String) return body['build'] as String;
    } catch (_) {/* offline or not deployed yet */}
    return null;
  }

  void applyUpdate() => reloadApp();

  /// Checks for a newer deployed build and, if found, reloads automatically to
  /// apply it (guarded against reload loops). Call once at app start.
  Future<void> autoApplyIfAvailable() async {
    final status = await check();
    if (status.available && status.latest != null) {
      tryAutoReload(status.latest!);
    }
  }
}
