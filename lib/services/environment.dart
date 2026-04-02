import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get baseUrl => "${dotenv.env['API_URL']}/api";

  // Conversations
  static String get conversations => "$baseUrl/conversations";
}
