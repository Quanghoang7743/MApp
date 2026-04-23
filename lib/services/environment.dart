import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get baseUrl => "${dotenv.env['API_URL']}/api";

  static String get realtimeKey =>
      dotenv.env['REALTIME_KEY'] ?? dotenv.env['VITE_PUSHER_APP_KEY'] ?? '';

  static String get realtimeCluster =>
      dotenv.env['REALTIME_CLUSTER'] ??
      dotenv.env['VITE_PUSHER_APP_CLUSTER'] ??
      '';

  static String get realtimeHost =>
      dotenv.env['REALTIME_HOST'] ?? dotenv.env['VITE_PUSHER_HOST'] ?? '';

  static int get realtimePort {
    final raw = dotenv.env['REALTIME_PORT'] ?? dotenv.env['VITE_PUSHER_PORT'];
    return int.tryParse(raw ?? '') ?? 443;
  }

  static bool get realtimeUseTLS {
    final raw =
        (dotenv.env['REALTIME_USE_TLS'] ??
                dotenv.env['VITE_PUSHER_SCHEME'] ??
                'https')
            .toLowerCase();
    return raw == 'true' || raw == 'https' || raw == 'tls';
  }

  static String get broadcastingAuthEndpoint => '$baseUrl/broadcasting/auth';

  // Conversations
  static String get conversations => "$baseUrl/conversations";
}
