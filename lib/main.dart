import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/home_screen.dart';
import 'services/accident_service.dart';
import 'services/location_service.dart';
import 'services/camera_service.dart';
import 'providers/accident_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();
  
  // // Firebase messaging background handler
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(MyApp());
}

// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   print("Background message: ${message.notification?.title}");
// }

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccidentProvider()),
        Provider(create: (_) => AccidentService()),
        Provider(create: (_) => LocationService()),
        Provider(create: (_) => CameraService()),
      ],
      child: MaterialApp(
        title: 'AI Замын Ослын Апп',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: Color(0xFF3182CE),
          colorScheme: ColorScheme.fromSeed(
            seedColor: Color(0xFF3182CE),
            error: Color(0xFFE53E3E),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xFF3182CE),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFE53E3E),
            foregroundColor: Colors.white,
          ),
        ),
        home: HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}