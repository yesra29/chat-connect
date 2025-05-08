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
import 'package:tuneup_task/firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';

final GetIt sl = GetIt.instance;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase first
  print("Initializing Firebase...");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");

    // Initialize Firebase Storage
    final storage = FirebaseStorage.instance;
    storage.setMaxUploadRetryTime(const Duration(seconds: 3));
    storage.setMaxOperationRetryTime(const Duration(seconds: 3));
    
    // Test storage connection
    try {
      final ref = storage.ref();
      print("Storage bucket: ${ref.bucket}");
      print("Storage initialized successfully");
    } catch (e) {
      print("Error initializing storage: $e");
    }

    print("Setting up Firebase...");
    await setupFirebase();
    print("Firebase setup completed");

    // Register services after Firebase is initialized
    print("Registering services...");
    sl.registerSingleton<NavigationService>(NavigationService());
    sl.registerSingleton<AlertService>(AlertService());
    sl.registerSingleton<AuthService>(AuthService());
    sl.registerSingleton<MediaService>(MediaService());
    sl.registerSingleton<DatabaseService>(DatabaseService());
    print("All services registered successfully");

    runApp(const MyApp());
  } catch (e, stackTrace) {
    print("Error during initialization: $e");
    print("Stack trace: $stackTrace");
    _showErrorUI();
  }
}

Future<void> setupFirebase() async {
  await FirebaseAnalytics.instance.logEvent(name: "app_started");
}

void _showErrorUI() {
  runApp(MaterialApp(
    navigatorKey: navigatorKey,
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Failed to initialize app",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
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
    final _navigationService = sl.get<NavigationService>();
    final _authService = sl.get<AuthService>();

    return MaterialApp(
      navigatorKey: _navigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      initialRoute: _authService.user != null ? "/home" : "/login",
      routes: _navigationService.routes,
    );
  }
}
