# News Application Maker

A Flutter news reader: a **news feed** aggregated from RSS/Atom sources and a
**bookmarks** module, with Supabase auth + cross-device sync and a server-side
crawling proxy.

The architecture mirrors the methodology used in
`hongsytop-tech/mobile-application-maker`:

- **Feature-first modules** — each feature is self-contained under
  `lib/features/<feature>/{models,services,providers,screens,widgets}`.
- **Riverpod** for state management.
- **SharedPreferences** as the offline-first local store (see
  `core/storage/local_storage.dart`).
- **Supabase** for authentication and data sync.
- **Edge Function crawling proxy** (`supabase/functions/crawl-proxy`) to bypass
  browser CORS and cache fetched feeds/articles in Postgres.
- **GitHub Actions** for web deployment (GitHub Pages) and signed APK releases.
- **devcontainer** + **dotenv** for reproducible setup and config.

Android package id: `com.hongsytop.news`.

## Project layout

```
lib/
  main.dart                     # bootstraps dotenv, Supabase, local storage
  app.dart                      # MaterialApp.router
  core/
    config/env.dart             # typed access to .env
    supabase/supabase_service.dart
    storage/local_storage.dart  # SharedPreferences facade
    providers/core_providers.dart
    theme/app_theme.dart
    router/                     # GoRouter + auth-aware redirects
  features/
    auth/      {models,services,providers,screens}
    news_feed/ {models,services,providers,screens,widgets}
    bookmarks/ {models,services,providers,screens,widgets}
    shell/     home_shell.dart  # bottom navigation
supabase/
  functions/crawl-proxy/index.ts
  migrations/0001_init.sql
  config.toml
.github/workflows/             # deploy-web.yml, release-apk.yml
.devcontainer/                  # Flutter SDK provisioning
```

## Getting started

1. **Configure environment**

   ```bash
   cp .env.example .env
   # fill in SUPABASE_URL and SUPABASE_ANON_KEY
   ```

2. **Provision platform tooling.** This repo ships the hand-written platform
   scaffolding (Android `com.hongsytop.news`, web). Run the following once to
   regenerate any binary tooling Flutter expects (Gradle wrapper jar, launcher
   icons, optional iOS):

   ```bash
   flutter create . --org com.hongsytop --project-name news_application_maker \
     --platforms=android,web,ios
   ```

   (Re-running `flutter create .` is non-destructive to existing source.)

3. **Run**

   ```bash
   flutter pub get
   flutter run -d chrome     # web
   flutter run -d <device>   # android
   ```

   Or open the repo in the dev container, which installs Flutter automatically.

## Supabase backend

```bash
supabase db push                       # apply migrations/0001_init.sql
supabase functions deploy crawl-proxy  # deploy the crawling proxy
```

The `crawl-proxy` function uses the service role key (set automatically in the
Supabase Functions environment) to write the `crawl_cache` table. The Flutter
client calls it with the user's JWT (or anon key).

## CI/CD

| Workflow | Trigger | Output |
| --- | --- | --- |
| `deploy-web.yml` | push to `main` | builds web, publishes to GitHub Pages |
| `release-apk.yml` | push tag `v*` | builds a **signed** APK, attaches it to a GitHub Release |

Required repository **secrets**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`CRAWL_PROXY_URL` (optional), and for releases `KEYSTORE_BASE64`,
`KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

For Pages, set **Settings → Pages → Source → GitHub Actions**.
