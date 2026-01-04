# Java Version Issue - Build Error Fix

## Problem
```
java.lang.IllegalArgumentException: 25
at org.jetbrains.kotlin.com.intellij.util.lang.JavaVersion.parse
```

You're using **Java 25**, which is too new for the current Gradle/Kotlin toolchain.

## Solution - Downgrade to Java 17 or 21

### Option 1: Download Java 17 (Recommended - LTS)
1. Download: https://adoptium.net/temurin/releases/?version=17
2. Install Java 17
3. Update JAVA_HOME:
   ```powershell
   # Set system environment variable
   [Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot", "Machine")
   
   # Or add to Path in System Settings
   ```

### Option 2: Use Java 21 (Newer LTS)
1. Download: https://adoptium.net/temurin/releases/?version=21
2. Same installation steps as above

### After Installing:
```powershell
# Verify
java -version
# Should show: openjdk version "17.x.x" or "21.x.x"

# Clean and rebuild
cd c:\Proj_flut\new_app\project_backup
flutter clean
flutter run
```

## Quick Check
Run `java -version` to see your current version.

## Why This Happens
- Java 25 is cutting-edge (early access)
- Kotlin 2.2.20 and Gradle 8.14 don't fully support its version format yet
- Java 17 and 21 are Long-Term Support (LTS) versions - stable and well-supported
