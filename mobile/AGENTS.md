# Project Guidelines

## Scope
These instructions apply to work under this directory tree.

## Code Style
- Follow Flutter and Dart lints from `analysis_options.yaml`.
- Keep state in providers and keep widgets focused on UI and user interaction.
- Reuse app theme tokens from `lib/theme/app_theme.dart` instead of hardcoding colors and typography.
- Keep async error messages user-friendly and avoid exposing raw backend errors in UI text.

## Architecture
- Use this flow: screens -> providers -> services -> Supabase or HTTP APIs.
- Put screen-level behavior in `lib/screens/**`, shared state in `lib/providers/**`, and I/O logic in `lib/services/**`.
- Use `Provider` + `ChangeNotifier` for app state and `GoRouter` for route definitions.
- For auth and realtime behavior, follow patterns in `lib/providers/auth_provider.dart` and `lib/providers/reports_provider.dart`.

## Build and Test
- Install dependencies: `flutter pub get`
- Run app: `flutter run`
- Static analysis: `flutter analyze`
- Tests: `flutter test`
- Release build: `flutter build apk --release`

## Conventions
- Load environment values from `.env` with `flutter_dotenv`; do not hardcode secrets.
- Keep backend JWT configuration aligned with Supabase project JWT settings.
- Cancel stream subscriptions in `dispose()` for screen/provider lifecycles.
- Use timeouts and graceful fallback messages for slow AI or network calls.
- Preserve route auth behavior defined in `lib/main.dart` redirects.

## Key References
- Architecture overview: `../context/00_ARCHITECTURE.md`
- API contract details: `../context/02_API_REFERENCE.md`
- Flutter implementation guide: `../context/04_FLUTTER_GUIDE.md`
- Testing and debugging guide: `../context/08_TESTING.md`