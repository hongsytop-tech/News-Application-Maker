// Non-web fallback: there is no in-app reload concept on native platforms
// (updates ship through the app stores).
void reloadApp() {}

bool tryAutoReload(String latest) => false;
