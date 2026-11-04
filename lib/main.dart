import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'bloc/splash/splash_bloc.dart';
import 'bloc/dashboard/dashboard_bloc.dart';
import 'bloc/dashboard/dashboard_event.dart';
import 'bloc/staff/staff_bloc.dart';
import 'bloc/staff/staff_event.dart';
import 'core/app_theme.dart';
import 'services/storage_service.dart';
import 'services/ml_service.dart';
import 'services/face_detector_service.dart';
import 'services/anti_spoofing_service.dart';
import 'services/attendance_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Enable Full Edge-to-Edge System UI for both Android & iOS
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 2. Adaptive System Overlays: Transparent status bar & navigation bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS dark background -> light icons
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // 3. Initialize Core Services Architecture Singleton
  final storageService = StorageService();
  final mlService = MLService();
  final faceDetectorService = FaceDetectorService();
  final antiSpoofingService = AntiSpoofingService();

  final attendanceService = AttendanceService(
    storageService: storageService,
    mlService: mlService,
    faceDetectorService: faceDetectorService,
    antiSpoofingService: antiSpoofingService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AttendanceService>.value(
          value: AttendanceService.instance,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SplashBloc>(
            create: (_) => SplashBloc(attendanceService: attendanceService),
          ),
          BlocProvider<DashboardBloc>(
            create: (_) => DashboardBloc(attendanceService: attendanceService)
              ..add(LoadDashboardDataEvent()),
          ),
          BlocProvider<StaffBloc>(
            create: (_) => StaffBloc(attendanceService: attendanceService)
              ..add(LoadStaffListEvent()),
          ),
        ],
        child: const AIFaceAttendanceApp(),
      ),
    ),
  );
}

class AIFaceAttendanceApp extends StatefulWidget {
  const AIFaceAttendanceApp({super.key});

  @override
  State<AIFaceAttendanceApp> createState() => _AIFaceAttendanceAppState();
}

class _AIFaceAttendanceAppState extends State<AIFaceAttendanceApp> {
  @override
  void initState() {
    super.initState();
    // Warm up biometrics asynchronously with idempotency guard
    AttendanceService.instance.initialize().catchError((e) => debugPrint('$e'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Face Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
