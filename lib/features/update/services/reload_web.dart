import 'package:web/web.dart' as web;

/// Forces the browser to reload the page, fetching the freshly deployed assets.
/// The service worker is disabled, so a reload pulls the latest build.
void reloadApp() => web.window.location.reload();
