import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tuneup_task/services/alert_service.dart';
import 'package:tuneup_task/services/database_services.dart';
import 'package:tuneup_task/services/media_service.dart';
import 'package:tuneup_task/services/navigation_service.dart';
import 'package:tuneup_task/services/auth_service.dart';
import 'package:tuneup_task/theme/app_theme.dart';
import 'package:tuneup_task/pages/login_page.dart';
import 'package:tuneup_task/pages/home_page.dart';
import 'firebase_options.dart';

final GetIt sl = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await setupFirebase();
    await registerServices();
    runApp(const MyApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to initialize app',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> setupFirebase() async {
  await FirebaseAnalytics.instance.logEvent(name: "app_started");
}

Future<void> registerServices() async {
  sl.registerLazySingleton<NavigationService>(() => NavigationService());
  sl.registerLazySingleton<AuthService>(() => AuthService());
  sl.registerLazySingleton<AlertService>(() => AlertService());
  sl.registerLazySingleton<MediaService>(() => MediaService());
  sl.registerLazySingleton<DatabaseService>(() => DatabaseService());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final _navigationService = sl.get<NavigationService>();
    final _authService = sl.get<AuthService>();

    return MaterialApp(
      navigatorKey: _navigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'TuneUp Chat',
      theme: AppTheme.lightTheme,
      initialRoute: _authService.user != null ? "/home" : "/login",
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => LoginPage());
          case '/home':
            return MaterialPageRoute(builder: (_) => HomePage());
          default:
            return MaterialPageRoute(builder: (_) => LoginPage());
        }
      },
    );
  }
}
