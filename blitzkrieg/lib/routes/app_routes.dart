import 'package:flutter/material.dart';
import '../pages/landing_page.dart';
import '../pages/phone_login_page.dart';
import '../pages/otp_verification_page.dart';
import '../pages/profile_setup_page.dart';
import '../pages/home_page.dart';

class AppRoutes {
  static const String landing = '/';
  static const String phoneLogin = '/phone-login';
  static const String otpVerification = '/otp-verification';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case landing:
        return _buildRoute(const LandingPage(), settings);
      case phoneLogin:
        return _buildRoute(const PhoneLoginPage(), settings);
      case otpVerification:
        final phoneNumber = settings.arguments as String? ?? '';
        return _buildRoute(
          OtpVerificationPage(phoneNumber: phoneNumber),
          settings,
        );
      case profileSetup:
        return _buildRoute(const ProfileSetupPage(), settings);
      case home:
        return _buildRoute(const HomePage(), settings);
      default:
        return _buildRoute(const LandingPage(), settings);
    }
  }

  static PageRouteBuilder _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
