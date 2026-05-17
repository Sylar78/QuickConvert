import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/premium/premium_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String auth = '/auth';
  static const String premium = '/premium';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _buildRoute(const HomeScreen(), settings);
      case auth:
        return _buildRoute(const AuthScreen(), settings);
      case premium:
        return _buildRoute(const PremiumScreen(), settings);
      default:
        return _buildRoute(const HomeScreen(), settings);
    }
  }

  static MaterialPageRoute _buildRoute(Widget page, RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
