// lib/main.dart - IMPROVED VERSION
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/home_screen.dart';
import 'services/accident_service.dart';
import 'services/location_service.dart';
import 'services/camera_service.dart';
import 'services/connectivity_service.dart';
import 'providers/accident_provider.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Firebase (if needed)
  // await Firebase.initializeApp();
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize connectivity service
  await ConnectivityService().initialize();

  print('🚀 Апп эхэллээ - ${ApiConfig.currentEnvironment}');
  print('📡 API: ${ApiConfig.baseUrl}');

  runApp(MyApp());
}

// Firebase background message handler (if using Firebase)
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
        // ✅ State Management
        ChangeNotifierProvider(create: (_) => AccidentProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),

        // ✅ Services
        Provider(create: (_) => AccidentService()),
        Provider(create: (_) => LocationService()),
        Provider(create: (_) => CameraService()),
        Provider(create: (_) => ConnectivityService()),
      ],
      child: Consumer<ConnectivityProvider>(
        builder: (context, connectivity, child) {
          return MaterialApp(
            title: 'AI Замын Ослын Апп',
            debugShowCheckedModeBanner: false,

            // ✅ Theme
            theme: ThemeData(
              useMaterial3: true,

              // Colors
              primarySwatch: Colors.blue,
              primaryColor: Color(0xFF3182CE),
              colorScheme: ColorScheme.fromSeed(
                seedColor: Color(0xFF3182CE),
                error: Color(0xFFE53E3E),
                brightness: Brightness.light,
              ),

              // AppBar
              appBarTheme: AppBarTheme(
                centerTitle: true,
                backgroundColor: Color(0xFF3182CE),
                foregroundColor: Colors.white,
                elevation: 2,
                systemOverlayStyle: SystemUiOverlayStyle.light,
              ),

              // Floating Action Button
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: Color(0xFFE53E3E),
                foregroundColor: Colors.white,
                elevation: 4,
              ),

              // Card
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              // Button
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3182CE),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),

              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF3182CE),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  side: BorderSide(color: Color(0xFF3182CE), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // Input
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),

              // Bottom Navigation Bar
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: Color(0xFF3182CE),
                unselectedItemColor: Colors.grey[600],
                selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: TextStyle(fontSize: 11),
                type: BottomNavigationBarType.fixed,
                elevation: 8,
              ),

              // Snackbar
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentTextStyle: TextStyle(fontSize: 14),
              ),

              // Progress Indicator
              progressIndicatorTheme: ProgressIndicatorThemeData(
                color: Color(0xFF3182CE),
              ),

              // Divider
              dividerTheme: DividerThemeData(
                color: Colors.grey[300],
                thickness: 1,
                space: 1,
              ),
            ),

            // ✅ Home Screen
            home: ConnectivityWrapper(child: HomeScreen()),
          );
        },
      ),
    );
  }
}

// ✅ Connectivity Wrapper - Shows connection status
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _hasShownInitialStatus = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        // Show initial connection status after a delay
        if (!_hasShownInitialStatus) {
          Future.delayed(Duration(seconds: 1), () {
            if (mounted && !connectivity.isConnected) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Интернет холболт байхгүй',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            _hasShownInitialStatus = true;
          });
        }

        return widget.child;
      },
    );
  }
}