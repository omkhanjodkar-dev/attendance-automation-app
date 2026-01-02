# Attendance Automation App

A secure, location-aware attendance system built with Flutter. This application automates the attendance process by verifying a student's physical presence in the classroom using **WiFi Proximity Detection** and **Device Fingerprinting**, eliminating the need for manual roll calls or QR codes.

## Overview

Traditional attendance methods are time-consuming and prone to proxy attendance. This app solves that by ensuring students are physically present. The Faculty app broadcasts or designates a "Target WiFi Network" (SSID), and the Student app scans for this network locally. The "Mark Present" button is only enabled if the student's device can physically detect the specific classroom network.

## Tech Stack

*   **Frontend:** Flutter (Dart)
*   **Backend Hosting:** [Render](https://render.com) (REST API)
*   **Database:** PostgreSQL hosted on [Neon](https://neon.tech)
*   **Key Libraries:**
    *   `wifi_scan`: For scanning local networks to verify proximity.
    *   `geolocator`: For GPS validation.
    *   `device_info_plus`: For preventing one student from marking attendance for others on a single phone.
    *   `flutter_secure_storage`: For secure JWT token management.

## Key Features

### For Faculty
*   **Session Management:** Start and stop class sessions instantly.
*   **Dynamic Security:** Set the "Target SSID" (e.g., Classroom Router or Faculty Hotspot) required for attendance.
*   **Real-time Dashboard:** Monitor active sessions.

### For Students
*   **One-Tap Attendance:** Mark attendance seamlessly when in range.
*   **Proximity Validation:** The app automatically scans for the class WiFi signal.
    *   *Note: You do not need to CONNECT to the WiFi, just be near it.*
*   **Security Checks:** Validates Device ID and GPS location to prevent fraud.

## How It Works

1.  **Faculty Login:** The professor logs in and starts a session (e.g., "Advanced Mathematics - Section A").
2.  **SSID Assignment:** The professor designates a WiFi network (e.g., `Classroom_501` or `Prof_Hotspot`) as the anchor.
3.  **Student Verification:**
    *   The student opens the app.
    *   The app passively scans for nearby WiFi networks.
    *   If `Classroom_501` is found in the scan list, the **"MARK PRESENT"** button unlocks.
4.  **Submission:** The student clicks the button. The app sends the User ID, Device ID, and Timestamp to the Render backend, which stores the record in the Neon database.

## Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/attendance-automation-app.git
    cd attendance-automation-app
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the App:**
    Connect your physical device (WiFi scanning works best on physical Android/iOS devices, not emulators).
    ```bash
    flutter run
    ```

## Permissions
To function correctly, the app requires the following permissions to scan for networks and verify location:
*   **Location (Fine/Coarse):** Required by Android/iOS to access WiFi scan results.
*   **WiFi State:** To initiate network scans.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---
*Built using Flutter.*