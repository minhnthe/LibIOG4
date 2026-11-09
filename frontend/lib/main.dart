import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/constants/app_constants.dart';
import 'core/services/fcm_service.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/screens/admin/admin_dashboard_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/student/student_home_screen.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Chưa nạp được .env asset: $e");
  }
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Khởi tạo Firebase Cloud Messaging (FCM) trên thiết bị di động
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Device Token: $token');
        await FcmService.registerDeviceToken(deviceToken: token);
      }

      messaging.onTokenRefresh.listen((newToken) {
        FcmService.registerDeviceToken(deviceToken: newToken);
      });

      // Hiển thị thông báo nổi (In-App Notification) khi app đang mở
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          final isAlert = message.data['type'] == 'CARD_BLOCKED' ||
              message.data['type'] == 'LIBRARY_CLOSING_ALERT';
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: isAlert ? Colors.red.shade800 : Colors.indigo.shade800,
              duration: const Duration(seconds: 4),
              content: Row(
                children: [
                  Icon(
                    isAlert ? Icons.warning_amber_rounded : Icons.notifications_active_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title ?? 'Thông báo thư viện',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (notification.body != null)
                          Text(
                            notification.body!,
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('[FCM] Bỏ qua khởi tạo Firebase: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (context) => AuthBloc()..add(const AuthCheckStatus()),
      child: MaterialApp(
        title: AppConstants.appName,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
          cardTheme: CardThemeData(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/admin': (context) => const AdminDashboardScreen(),
          '/student': (context) => const StudentHomeScreen(),
        },
      ),
    );
  }
}

/// Điều hướng tự động dựa trên trạng thái xác thực và phân quyền (Role)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) {
        // Không unmount màn hình Login khi đang submit loading hoặc khi đăng nhập thất bại
        if (current is AuthLoading && previous is! AuthInitial) {
          return false;
        }
        if (current is AuthFailure) {
          return false;
        }
        return true;
      },
      builder: (context, state) {
        if (state is AuthInitial || (state is AuthLoading && state is! Authenticated)) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Đang kiểm tra phiên làm việc...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is Authenticated) {
          if (state.isStaff) {
            return const AdminDashboardScreen();
          } else {
            return const StudentHomeScreen();
          }
        }

        return const LoginScreen();
      },
    );
  }
}
