import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';

class DashboardClockBanner extends StatefulWidget {
  const DashboardClockBanner({super.key});

  @override
  State<DashboardClockBanner> createState() => _DashboardClockBannerState();
}

class _DashboardClockBannerState extends State<DashboardClockBanner> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Isolated 1-second clock timer: Only this widget repaints, NEVER the parent screen!
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeString = DateFormat('hh:mm:ss a').format(_currentTime);
    final dateString = DateFormat('EEEE, MMM dd, yyyy').format(_currentTime);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF141E30), Color(0xFF0F1726)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.cyanAccent.withValues(alpha: 0.20),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeString,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 11,
                    color: AppColors.cyanAccent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    dateString,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emeraldGreen.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.emeraldGreen.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.emeraldGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emeraldGreen,
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'ONLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldGreen,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
