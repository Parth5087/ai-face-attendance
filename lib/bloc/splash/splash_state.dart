abstract class SplashState {}

class SplashInitial extends SplashState {}

class SplashLoading extends SplashState {
  final String statusMessage;
  final double progress; // 0.0 to 1.0

  SplashLoading({
    required this.statusMessage,
    required this.progress,
  });
}

class SplashSuccess extends SplashState {}

class SplashFailure extends SplashState {
  final String errorMessage;

  SplashFailure({required this.errorMessage});
}
