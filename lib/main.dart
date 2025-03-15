import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:tuneup_task/pages/login_page.dart';
import 'package:google_fonts/google_fonts.dart';


void main() async{

  runApp(const MyApp());
  await setupFirebase();
}

Future<void> setupFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupFirebase();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
          textTheme: GoogleFonts.montserratTextTheme(),
      ),
      home: const LoginPage(),
    );
  }
}

