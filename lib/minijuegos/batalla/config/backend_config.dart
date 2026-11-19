// Configuración del backend del equipo (ASP.NET en MonsterASP).
//
// Dirección del backend (sin "/" al final y sin "/api"). Se puede cambiar al correr la app:
//   flutter run --dart-define=BACKEND_URL=https://otra-direccion.runasp.net
// Para probar sin internet con los datos falsos de MockBattleBackend:
//   flutter run --dart-define=BACKEND_URL=
const String backendBaseUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'https://backpokemon.runasp.net');

// Usuario de los datos falsos. Con el backend real, el Id sale del login.
const String currentUserId = 'usuario-demo';

// El hosting gratis puede tardar en "despertar" el sitio en la primera llamada
const Duration backendTimeout = Duration(seconds: 30);

const bool useRealBackend = backendBaseUrl != '';
