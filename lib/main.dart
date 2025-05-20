import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tuneup_task/services/alert_service.dart';
import 'package:tuneup_task/services/database_services.dart';
import 'package:tuneup_task/services/navigation_service.dart';
import 'package:tuneup_task/services/auth_service.dart';
import 'package:tuneup_task/firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'pages/login_page.dart';

final GetIt sl = GetIt.instance;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseAnalytics.instance.logEvent(name: "app_started");

    final storage = FirebaseStorage.instance;
    storage.setMaxUploadRetryTime(const Duration(seconds: 3));
    storage.setMaxOperationRetryTime(const Duration(seconds: 3));

    try {
      final ref = storage.ref();
    } catch (e) {}

    await setupServiceLocator();

    runApp(const MyApp());
  } catch (e, stackTrace) {
    _showErrorUI();
  }
}

Future<void> setupServiceLocator() async {
  sl.registerSingleton<NavigationService>(NavigationService());
  sl.registerSingleton<AlertService>(AlertService());
  sl.registerSingleton<AuthService>(AuthService());
  sl.registerSingleton<DatabaseService>(DatabaseService());
}

void _showErrorUI() {
  runApp(MaterialApp(
    navigatorKey: navigatorKey,
    home: const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              "Failed to initialize app",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Please restart the app",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    ),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationService = sl.get<NavigationService>();
    final authService = sl.get<AuthService>();

    return MaterialApp(
      navigatorKey: navigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      initialRoute: authService.user != null ? "/home" : "/login",
      routes: navigationService.routes,
    );
  }
}
