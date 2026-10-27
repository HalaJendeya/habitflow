import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'firebase_options.dart';
import 'controllers/achievement_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/habit_controller.dart';
import 'controllers/notification_controller.dart';
import 'controllers/task_controller.dart';
import 'controllers/tip_controller.dart';
import 'routes/app_routes.dart';
import 'screens/add_habit_screen.dart';
import 'screens/habit_details_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  Get.put(AuthController());
  Get.put(HabitController());
  Get.put(TaskController());

  // the notifications must be ready before the habits schedule reminders
  final notificationController = Get.put(NotificationController());

  try {
    await notificationController.init();
  } catch (e) {
    // the app still works without notifications
  }

  // this one uses the habit and the task controllers, so it comes after them
  Get.put(AchievementController());
  Get.put(TipController());

  runApp(const HabitFlowApp());
}

class HabitFlowApp extends StatelessWidget {
  const HabitFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HabitFlow',
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      getPages: [
        GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
        GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
        GetPage(name: AppRoutes.register, page: () => const RegisterScreen()),
        GetPage(name: AppRoutes.home, page: () => const HomeScreen()),
        GetPage(name: AppRoutes.addHabit, page: () => const AddHabitScreen()),
        GetPage(
          name: AppRoutes.habitDetails,
          page: () => const HabitDetailsScreen(),
        ),
        GetPage(name: AppRoutes.profile, page: () => const ProfileScreen()),
      ],
    );
  }
}
