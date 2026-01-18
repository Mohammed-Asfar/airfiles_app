# AirFiles

<p align="center">
  <img src="assets/logo3.png" alt="AirFiles Logo" width="120"/>
</p>

A modern, cross-platform file sharing application built with Flutter. Share files seamlessly between devices on the same network via a beautiful web interface.

---

## ✨ The Problem We Solve

**Traditional file sharing apps require installation on BOTH devices.** This creates friction:
- Recipients need to download and install an app
- Different apps for different platforms
- Account creation or pairing hassles

## 🎯 Our Solution

**AirFiles requires NO installation on receiving devices!**

Recipients simply open a web browser and access your shared files instantly. Any device with a browser works - phones, tablets, laptops, smart TVs, or any other device on the same network.

---

## Features

*   **No App Required on Receiving Device**: Recipients access files through any web browser - zero installation needed
*   **Local Network File Sharing**: Start a local HTTP server to share files with any device on the same Wi-Fi network
*   **QR Code Access**: Instantly generate QR codes for easy access from mobile devices
*   **Modern Web Interface**: A sleek, responsive web UI for browsing and downloading shared files
*   **Cross-Platform**: Runs on Windows and Android
*   **Responsive Design**: Optimized layouts for both desktop and mobile screens
*   **Dark/Light Theme**: Automatically adapts to your system theme

## Screenshots

*(Add screenshots here)*

## Getting Started

### Prerequisites

*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.6.0 or higher)

### Installation

1.  Clone the repository:
    ```bash
    git clone <repository-url>
    cd airfiles_app
    ```

2.  Get dependencies:
    ```bash
    flutter pub get
    ```

3.  Run the app:
    ```bash
    flutter run
    ```

### Building

**Android:**
```bash
flutter build apk
```

**Windows:**
```bash
flutter build windows
```

## How to Use

### On Android

1.  **Grant Permissions**: Allow storage access when prompted.
2.  **Select Files**: Tap "Select Files" or "Add More Files" to pick files from your device.
    - **Recommended locations**: Downloads, Documents, Pictures/DCIM, Movies, Music
    - **Avoid**: "Recent files" section, Google Drive, third-party app folders, system directories
3.  **Start Sharing**: Tap "Start Sharing" to begin the server.
4.  **Share Access**: 
    - Show the QR code to others on the same network
    - Or share the displayed IP address link
5.  **Access Files**: Recipients open the link in **any browser** to download files - no app needed!

### On Windows

1.  **Select Files**: Click "Select Files" to choose files or folders.
2.  **Start Sharing**: Click "Start Sharing" to begin the server.
3.  **Share Access**: Share the displayed IP address or QR code with others on your network.
4.  **Access Files**: Recipients open the link in **any browser** to download files - no app needed!

### Tips

*   Both devices must be on the **same Wi-Fi network**.
*   The sharing stops when you close the app or tap "Stop Sharing".
*   For Android file access issues, copy files to the Downloads folder first.

## Tech Stack

*   **Flutter** - Cross-platform UI framework
*   **Shelf** - HTTP server for file sharing
*   **QR Flutter** - QR code generation
*   **Permission Handler** - Managing platform permissions

## Project Structure

```
lib/
├── core/
│   ├── models/         # Data models
│   ├── services/       # Business logic (FileService, FileServerService)
│   ├── theme/          # App theming
│   └── widgets/        # Reusable widgets
├── features/
│   ├── home/           # Home page feature
│   └── onboarding/     # Onboarding screens
└── main.dart           # App entry point
```

## License

This project is licensed under the MIT License.
