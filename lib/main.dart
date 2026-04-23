import 'package:flutter/material.dart';
import 'package:mess_app/Views/app_home_login_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'providers/friend_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, FriendProvider>(
          create: (_) => FriendProvider(),
          update: (_, authProvider, friendProvider) {
            final provider = friendProvider ?? FriendProvider();
            provider.bindApi(authProvider.api);
            return provider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoxChat',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeLoginScreen(),
    );
  }
}
