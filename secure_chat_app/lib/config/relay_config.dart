/// Default relay server URL. Used when the user has not set a custom URL in settings.
/// Set via .env (RELAY_URL) and run with: ./run_with_env.sh
/// Or pass at build/run: flutter run --dart-define=RELAY_URL=https://...
/// If empty, no default relay is used (user must set URL in app settings).
const String kDefaultRelayBaseUrl = String.fromEnvironment(
  'RELAY_URL',
  defaultValue: '',
);
