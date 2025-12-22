# Attendance Automation System

A comprehensive automated attendance system consisting of a Flutter mobile application for students and faculty, and a Python (FastAPI) backend.

## Overview

This system automates the attendance process by allowing faculty to start sessions and students to mark their presence using their mobile devices. Verification is handled via Wi-Fi SSID scanning and potentially geolocation.

The project is divided into two main parts:
*   **Frontend:** A Flutter mobile application (`project_backup/`).
*   **Backend:** A set of Python microservices (`backend/`).

## Architecture

*   **Client:** Flutter App (iOS/Android)
*   **Server:**
    *   **Auth Server (Port 8000):** Manages user authentication (JWT), login, and logout.
    *   **Resource Server (Port 8001):** Handles attendance sessions, student data, and verification logic.
*   **Database:** PostgreSQL (implied by `psycopg2` dependency).

## Prerequisites

*   **Flutter SDK:** [Install Flutter](https://docs.flutter.dev/get-started/install) (Version 3.10.3 or higher recommended)
*   **Python:** Version 3.8+
*   **PostgreSQL:** Database server.

## Setup Instructions

### 1. Backend Setup

The backend is located in the `backend/` directory and consists of two services.

#### Environment Variables
Create a `.env` file in `backend/auth_server/` and `backend/resource_server/` with the necessary configuration (Database URL, JWT Secret, etc.).

#### Auth Server
```bash
cd backend/auth_server
pip install -r requirements.txt
python main.py
```
Runs on `http://localhost:8000`. Documentation at `/docs`.

#### Resource Server
```bash
cd backend/resource_server
pip install -r requirements.txt
python main.py
```
Runs on `http://localhost:8001`. Documentation at `/docs`.

### 2. Frontend Setup

The Flutter application is located in the `project_backup/` directory.

```bash
cd project_backup
flutter pub get
```

#### Running the App
Ensure you have an emulator running or a physical device connected.

```bash
flutter run
```

*   **Note:** You may need to update the API endpoints in the Flutter app to point to your local backend IP address (not `localhost` if running on a physical device/emulator, use your machine's LAN IP).

## Features

*   **Faculty Dashboard:**
    *   Start/Stop attendance sessions.
    *   View attendance records.
    *   Manage settings.
*   **Student Dashboard:**
    *   Mark attendance (verifies Wi-Fi/Location).
    *   View attendance history.
*   **Security:**
    *   JWT-based authentication (Access & Refresh tokens).
    *   Secure storage on mobile devices.

## Project Structure

```
.
├── backend/               # Python FastAPI Backend
│   ├── auth_server/       # Authentication Service
│   └── resource_server/   # Core Business Logic Service
├── project_backup/        # Flutter Mobile Application
│   ├── lib/               # Dart Source Code
│   ├── android/           # Android Native Code
│   └── ios/               # iOS Native Code
└── assets/                # Project Assets & Documentation
```
