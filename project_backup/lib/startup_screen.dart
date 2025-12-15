import 'package:flutter/material.dart';
import 'package:attendance_automation/attendance_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'faculty_dashboard_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Small delay for splash effect
    await Future.delayed(const Duration(milliseconds: 500));

    // 1. Check if tokens exist
    final accessToken = await _attendanceService.getToken();
    final refreshToken = await _attendanceService.getRefreshToken();
    final role = await _attendanceService.getRole();

    if (accessToken == null || refreshToken == null || role == null) {
      // No tokens stored - go to login
      _navigateToLogin();
      return;
    }

    // 2. Try to validate access token (lightweight API call)
    final isValid = await _attendanceService.validateToken();

    if (isValid) {
      // Access token is valid - navigate directly
      if (role == 'student') {
        _navigateToStudentDashboard();
      } else if (role == 'faculty') {
        _navigateToFacultyDashboard();
      } else {
        _navigateToLogin();
      }
      return;
    }

    // 3. Access token expired - try to refresh
    print("Access token expired, attempting refresh...");
    final refreshed = await _attendanceService.refreshAccessToken();

    if (refreshed) {
      // Refresh successful - navigate to dashboard
      print("Token refresh successful!");
      if (role == 'student') {
        _navigateToStudentDashboard();
      } else if (role == 'faculty') {
        _navigateToFacultyDashboard();
      } else {
        _navigateToLogin();
      }
    } else {
      // Refresh failed - refresh token likely expired
      print("Token refresh failed - logging out");
      await _attendanceService.logout();
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _navigateToStudentDashboard() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _navigateToFacultyDashboard() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FacultyDashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'WaveLog Attendance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
