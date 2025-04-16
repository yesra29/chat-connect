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
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");
  } catch (e) {
    print("Error initializing Firebase: $e");
    rethrow;
  }
}

Future<void> registerServices() async {
  try {
    final GetIt getIt = GetIt.instance;
    
    // Register services in the correct order
    getIt.registerSingleton<NavigationService>(NavigationService());
    getIt.registerSingleton<AlertService>(AlertService());
    getIt.registerSingleton<AuthService>(AuthService());
    getIt.registerSingleton<MediaService>(MediaService());
    getIt.registerSingleton<DatabaseService>(DatabaseService());
    
    print("All services registered successfully");
  } catch (e) {
    print("Error registering services: $e");
    rethrow;
  }
}

String generateChatID({required String uid1, required String uid2}) {
  final List<String> uids = [uid1, uid2];
  uids.sort();
  return uids.join('_');
}

String getRandomAvatarUrl(String name) {
  try {
    if (name.isEmpty) {
      throw ArgumentError("Name cannot be empty");
    }
    
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
  } catch (e) {
    print("Error generating avatar URL: $e");
    // Return a default avatar URL in case of error
    return 'https://ui-avatars.com/api/?name=User&background=0078D7&size=200&color=fff';
  }
}

// Utility function to format timestamp
String formatTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inDays > 7) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  } else if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'Just now';
  }
}

// Utility function to validate email
bool isValidEmail(String email) {
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return emailRegex.hasMatch(email);
}

// Utility function to validate password
bool isValidPassword(String password) {
  // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
  final passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$');
  return passwordRegex.hasMatch(password);
}

// Utility function to get initials from name
String getInitials(String name) {
  if (name.isEmpty) return 'U';
  
  final parts = name.split(' ');
  if (parts.length == 1) {
    return parts[0][0].toUpperCase();
  }
  
  return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
}
