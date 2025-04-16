import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';
import 'package:tuneup_task/firebase_options.dart';
import 'package:tuneup_task/services/alert_service.dart';
import 'package:tuneup_task/services/auth_service.dart';
import 'package:tuneup_task/services/database_services.dart';
import 'package:tuneup_task/services/media_service.dart';
import 'package:tuneup_task/services/navigation_service.dart';
import 'dart:math';

Future<void> setupFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> registerServices() async {
  final GetIt getIt = GetIt.instance();
  getIt.registerSingleton<AuthService>(AuthService());
  getIt.registerSingleton<NavigationService>(NavigationService());
  getIt.registerSingleton<AlertService>(AlertService());
  getIt.registerSingleton<MediaService>(MediaService());
  getIt.registerSingleton<DatabaseService>(DatabaseService());
}

String generateChatID({required String uid1,required String uid2}
List uids = [uid1, uid2];
  uids.sort();
  String chatID = uids.fold("",(id, uid) => "$id$uid");
  return chatID;
}


String getRandomAvatarUrl(String name) {
  final random = Random();
  final colors = [
    'FFB900', 'FF8C00', 'F7630C', 'CA5010', 'DA3B01', 'EF6950', 'D13438',
    'FF4343', 'E74856', 'E81123', 'EA005E', 'C30052', 'E3008C', 'BF0077',
    'C239B3', '9A0089', '881798', '744DA9', 'B146C2', '8764B8', '5C2D91',
    '0078D7', '0099BC', '2D7D9A', '00B7C3', '038387', '00B294', '018574',
    '00CC6A', '10893E', '7A7574', '5D5A58', '68768A', '515C6B', '567C73',
    '486860', '498205', '107C10', '767676', '4C4A48', '69797E', '4A5459',
  ];
  
  final color = colors[random.nextInt(colors.length)];
  final size = 200;
  
  return 'https://ui-avatars.com/api/?name=$name&background=$color&size=$size&color=fff';
}
