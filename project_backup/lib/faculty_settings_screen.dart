import 'package:flutter/material.dart';
import 'package:attendance_automation/attendance_service.dart';

class FacultySettingsScreen extends StatefulWidget {
  const FacultySettingsScreen({super.key});

  @override
  State<FacultySettingsScreen> createState() => _FacultySettingsScreenState();
}

class _FacultySettingsScreenState extends State<FacultySettingsScreen> {
  final AttendanceService _attendanceService = AttendanceService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _attendanceService.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // System Info Card
            Card(
              elevation: 4,
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Nearby Connections System',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This app uses Google\'s Nearby Connections API for proximity-based attendance marking via Bluetooth and WiFi Direct.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // How It Works Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'How to Start a Session',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStepTile(1, 'Select your class from the dashboard'),
                    _buildStepTile(2, 'Tap "Start Attendance"'),
                    _buildStepTile(3, 'OTP is generated automatically'),
                    _buildStepTile(4, 'Students connect and receive OTP'),
                    _buildStepTile(5, 'Tap "Stop" when attendance is complete'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // System Details Card
            Card(
              elevation: 4,
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'System Features',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureTile(Icons.timer, 'OTP expires after 10 minutes'),
                    _buildFeatureTile(Icons.group, 'Handles up to 8 students at once'),
                    _buildFeatureTile(Icons.security, 'Secure OTP validation'),
                    _buildFeatureTile(Icons.check_circle, 'Duplicate prevention'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.amber.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Ensure Bluetooth & Location are enabled before starting!',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStepTile(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
  
  Widget _buildFeatureTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
