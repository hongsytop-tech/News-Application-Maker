import 'package:web/web.dart' as web;

/// Forces the browser to reload the page, fetching the freshly deployed assets.
/// The service worker is disabled, so a reload pulls the latest build.
void reloadApp() => web.window.location.reload();

/// Reloads once to pick up build [latest]. Guarded by sessionStorage so a stale
/// cache can't cause an infinite reload loop: if we already auto-applied this
/// build in this tab session, we stop and leave it to the manual button.
bool tryAutoReload(String latest) {
  final ss = web.window.sessionStorage;
  const key = 'autoUpdateApplied';
  if (ss.getItem(key) == latest) return false;
  ss.setItem(key, latest);
  web.window.location.reload();
  return true;
}
