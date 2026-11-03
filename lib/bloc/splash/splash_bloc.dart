import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/attendance_service.dart';
import 'splash_event.dart';
import 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  final AttendanceService attendanceService;

  SplashBloc({required this.attendanceService}) : super(SplashInitial()) {
    on<InitializeAppEvent>(_onInitializeApp);
  }

  Future<void> _onInitializeApp(
    InitializeAppEvent event,
    Emitter<SplashState> emit,
  ) async {
    try {
      // Step 1: Starting Biometric Core (~450ms)
      emit(SplashLoading(
        statusMessage: 'Starting Biometric Core...',
        progress: 0.15,
      ));
      await Future.delayed(const Duration(milliseconds: 450));

      // Step 2: Initializing Face Detector (~550ms)
      emit(SplashLoading(
        statusMessage: 'Initializing Face Detector...',
        progress: 0.35,
      ));
      attendanceService.faceDetectorService.initialize();
      await Future.delayed(const Duration(milliseconds: 550));

      // Step 3: Loading MobileFaceNet Neural Engine (~650ms)
      emit(SplashLoading(
        statusMessage: 'Loading MobileFaceNet Neural Engine...',
        progress: 0.60,
      ));
      await attendanceService.mlService.initialize();
      await attendanceService.antiSpoofingService.initialize();
      await Future.delayed(const Duration(milliseconds: 650));

      // Step 4: Reading Staff Embeddings & Records (~650ms)
      emit(SplashLoading(
        statusMessage: 'Reading Staff Embeddings & Records...',
        progress: 0.80,
      ));
      await attendanceService.storageService.init();
      attendanceService.reloadFromStorage();
      await Future.delayed(const Duration(milliseconds: 650));

      // Step 5: Synchronizing System State (~550ms)
      emit(SplashLoading(
        statusMessage: 'Synchronizing System State...',
        progress: 0.95,
      ));
      await Future.delayed(const Duration(milliseconds: 550));

      // Step 6: Ready! Welcome to AI Face Attendance (~850ms)
      emit(SplashLoading(
        statusMessage: 'Ready! Welcome to AI Face Attendance',
        progress: 1.00,
      ));
      await Future.delayed(const Duration(milliseconds: 850));

      // Smooth transition to Dashboard
      emit(SplashSuccess());
    } catch (e) {
      emit(SplashFailure(errorMessage: e.toString()));
    }
  }
}
