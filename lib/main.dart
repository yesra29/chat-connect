import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tuneup_task/services/alert_service.dart';
import 'package:tuneup_task/services/navigation_service.dart';
import 'package:tuneup_task/services/auth_service.dart';

final GetIt sl = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupFirebase();
  await registerServices();

  runApp(MyApp());
}

Future<void> setupFirebase() async {
  await FirebaseAnalytics.instance.logEvent(name: "app_started");
}

Future<void> registerServices() async {
  sl.registerLazySingleton<NavigationService>(() => NavigationService());
  sl.registerLazySingleton<AuthService>(() => AuthService());
  sl.registerLazySingleton<AlertService>(() => AlertService());
}

class MyApp extends StatelessWidget {
  final GetIt _getIt  = GetIt.instance;
  late NavigationService _navigationService;
  late AuthService _authService;
  MyApp({super.key}){
_navigationService = _getIt.get<NavigationService>();
_authService = _getIt.get<AuthService>();
  }

  @override
  Widget build(BuildContext context) {


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
