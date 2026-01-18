# AirFiles

<p align="center">
  <img src="assets/logo3.png" alt="AirFiles Logo" width="120"/>
</p>

A modern, cross-platform file sharing application built with Flutter. Share files seamlessly between devices on the same network via a beautiful web interface.

## Features

*   **Local Network File Sharing**: Start a local HTTP server to share files with any device on the same Wi-Fi network.
*   **QR Code Access**: Instantly generate QR codes for easy access from mobile devices.
*   **Modern Web Interface**: A sleek, responsive web UI for browsing and downloading shared files.
*   **Cross-Platform**: Runs on Windows and Android.
*   **Responsive Design**: Optimized layouts for both desktop and mobile screens.
*   **Dark/Light Theme**: Automatically adapts to your system theme.

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

## Usage

1.  Launch the app and grant necessary permissions (storage access on Android).
2.  Select files or folders you want to share.
3.  Tap "Start Sharing" to begin the server.
4.  Access shared files from any browser on the same network using the displayed IP address or QR code.

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
│   └── home/           # Home page feature
└── main.dart           # App entry point
```

## License

This project is licensed under the MIT License.
