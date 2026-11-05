import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/splash/splash_bloc.dart';
import '../bloc/splash/splash_event.dart';
import '../bloc/splash/splash_state.dart';
import '../core/app_colors.dart';
import 'dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Trigger BLoC initialization event
    context.read<SplashBloc>().add(InitializeAppEvent());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashBloc, SplashState>(
      listener: (context, state) {
        if (state is SplashSuccess) {
          // Smooth fade transition to Dashboard
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
              transitionDuration: const Duration(milliseconds: 600),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background Subtle Mesh / Radial Glow
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyanAccent.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Central Branding & Loading Section
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Glowing Pulsing Logo
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                              blurRadius: 20,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF0EA5E9), Color(0xFF06B6D4)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.face_retouching_natural_rounded,
                                  color: Colors.white,
                                  size: 52,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Brand Title
                    const Text(
                      'AI FACE',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3.0,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'SMART FACE ATTENDANCE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyanAccent,
                        letterSpacing: 2.0,
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Bottom Loading & Status Area
                    BlocBuilder<SplashBloc, SplashState>(
                      builder: (context, state) {
                        if (state is SplashFailure) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Initialization Failed: ${state.errorMessage}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.roseError,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<SplashBloc>().add(InitializeAppEvent());
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          );
                        }

                        final progress = state is SplashLoading ? state.progress : 0.05;
                        final status = state is SplashLoading
                            ? state.statusMessage
                            : 'Starting Biometric Core...';

                        return _SplashProgressSection(
                          progress: progress,
                          status: status,
                        );
                      },
                    ),

                    const Spacer(flex: 1),

                    // Secure Biometric Badge Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.security_rounded,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'On-Device AI Engine • 100% Privacy Protected',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashProgressSection extends StatelessWidget {
  final double progress;
  final String status;

  const _SplashProgressSection({
    required this.progress,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // 6 defined checkpoints corresponding to the 6 steps
    final steps = [0.15, 0.35, 0.60, 0.80, 0.95, 1.00];

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.05, end: progress),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, child) {
        final percentage = (animatedProgress * 100).clamp(0, 100).toInt();
        final isComplete = animatedProgress >= 0.99;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status row with dynamic icon, AnimatedSwitcher status text & percentage
            Row(
              children: [
                // Step Status Icon / Spinner
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isComplete
                        ? AppColors.emeraldGreen.withValues(alpha: 0.2)
                        : AppColors.cyanAccent.withValues(alpha: 0.15),
                    border: Border.all(
                      color: isComplete
                          ? AppColors.emeraldGreen
                          : AppColors.cyanAccent.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: isComplete
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Color(0xFF10B981),
                          )
                        : const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.cyanAccent,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Smooth sliding & fading status text
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: <Widget>[
                          ...previousChildren,
                          ?currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.25),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      status,
                      key: ValueKey<String>(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isComplete
                            ? Colors.white
                            : AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Smooth Counting Percentage
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isComplete ? AppColors.emeraldGreen : AppColors.cyanAccent)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isComplete ? AppColors.emeraldGreen : AppColors.cyanAccent)
                          .withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isComplete
                          ? AppColors.emeraldGreen
                          : AppColors.cyanAccent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Continuous Glowing Progress Bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: animatedProgress.clamp(0.03, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isComplete
                              ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                              : [const Color(0xFF2563EB), const Color(0xFF00F2FE)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: (isComplete
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF00F2FE))
                                .withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 6-Step Visual Segment Indicators
            Row(
              children: List.generate(steps.length, (index) {
                final stepThreshold = steps[index];
                final isStepActive = animatedProgress >= (stepThreshold - 0.02);

                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.only(
                      right: index < steps.length - 1 ? 5 : 0,
                    ),
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isStepActive
                          ? (isComplete
                              ? AppColors.emeraldGreen
                              : AppColors.cyanAccent)
                          : Colors.white.withValues(alpha: 0.1),
                      boxShadow: isStepActive
                          ? [
                              BoxShadow(
                                color: (isComplete
                                        ? AppColors.emeraldGreen
                                        : AppColors.cyanAccent)
                                    .withValues(alpha: 0.4),
                                blurRadius: 4,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
