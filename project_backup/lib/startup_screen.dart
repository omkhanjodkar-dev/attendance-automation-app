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

    // 1. Check if token exists
    final token = await _attendanceService.getToken();
    final role = await _attendanceService.getRole();

    if (token == null || role == null) {
      // No token or role stored - go to login
      _navigateToLogin();
      return;
    }

    // 2. Validate token with API call
    final isValid = await _attendanceService.validateToken();

    if (!isValid) {
      // Token expired or invalid - clear and go to login
      await _attendanceService.logout();
      _navigateToLogin();
      return;
    }

    // 3. Token is valid - navigate to appropriate dashboard
    if (role == 'student') {
      _navigateToStudentDashboard();
    } else if (role == 'faculty') {
      _navigateToFacultyDashboard();
    } else {
      // Unknown role - go to login
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
              'NoProxy Attendance',
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
