# 🌬️ AirFiles - Local File Sharing App

AirFiles is a Flutter-based mobile application that transforms your smartphone into a local file-sharing server. Share files instantly with anyone on the same Wi-Fi network through a simple web interface - no app installation required on the receiving end.

## ✨ Features Implemented

### Core Functionality
- **Local HTTP Server**: Built with Dart's `shelf` package for serving files
- **File Selection**: Pick multiple files using the device's file picker
- **Real-time Server Control**: Start/stop sharing with a single tap
- **Network Detection**: Automatic local IP address discovery
- **Cross-platform**: Works on Android and iOS

### User Interface
- **Modern Material 3 Design**: Beautiful gradient backgrounds and clean UI
- **Dark/Light Theme Support**: Automatically adapts to system preferences
- **Server Status Indicator**: Visual feedback with animated status icons
- **File List Management**: View selected files with type icons and sizes
- **QR Code Sharing**: Generate QR codes for easy URL sharing

### Web Interface
- **Responsive HTML Interface**: Beautiful web UI for file browsing
- **File Type Icons**: Visual indicators for different file types
- **Directory Navigation**: Browse folders and navigate file structures
- **Direct Download**: Click any file to download directly
- **Mobile-friendly**: Works perfectly on phones, tablets, and computers

### Security & Permissions
- **Optional Password Protection**: Secure your shared files (planned)
- **Read-only Access**: Clients can only download, never modify
- **Local Network Only**: Files stay on your local network
- **Proper Permissions**: Handles Android/iOS file access permissions

## 🏗️ Architecture

The app follows a clean, feature-based architecture:

```
lib/
├── core/
│   ├── models/           # Data models (FileItem, ServerConfig)
│   ├── services/         # Business logic services
│   │   ├── file_server_service.dart    # HTTP server management
│   │   ├── network_service.dart        # Network utilities
│   │   └── file_service.dart           # File operations
│   └── theme/            # App theming and colors
├── features/
│   └── home/
│       └── presentation/
│           └── pages/
│               └── home_page.dart      # Main UI
└── main.dart            # App entry point
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.6.0 or higher
- Android Studio / VS Code with Flutter plugin
- Android device/emulator or iOS device/simulator

### Installation
1. Clone this repository
2. Run `flutter pub get` to install dependencies
3. Connect your device or start an emulator
4. Run `flutter run` to start the app

### Usage
1. **Select Files**: Tap "Select Files" to choose files you want to share
2. **Start Server**: Tap "Start Sharing" to begin the local server
3. **Share URL**: Copy the generated URL or share the QR code
4. **Access Files**: Others can visit the URL in any web browser to download files

## 📦 Dependencies

- **shelf**: HTTP server framework
- **shelf_static**: Static file serving
- **qr_flutter**: QR code generation
- **file_picker**: File selection dialog
- **network_info_plus**: Network information
- **permission_handler**: Runtime permissions
- **share_plus**: Native sharing functionality
- **mime**: MIME type detection

## 🔧 Technical Details

### HTTP Server
- Runs on automatically selected available port (starting from 8080)
- Serves files with proper MIME types
- Generates beautiful HTML directory listings
- Supports CORS for web browser compatibility

### Network Discovery
- Automatically detects local IP address
- Prioritizes common local network ranges (192.168.x.x, 10.x.x.x)
- Shows Wi-Fi network name for user confirmation
- Validates network connectivity

### File Management
- Supports all file types
- Handles both individual files and directories
- Calculates and displays file sizes
- Provides file type categorization with icons

### Platform Support
- **Android**: Full functionality with storage permissions
- **iOS**: Full functionality with photo library access
- **Web**: Limited (file picker restrictions)
- **Desktop**: Planned for future releases

## 🎨 Design

The app features a modern design inspired by the "air" theme:
- **Colors**: Indigo and cyan gradient representing airflow
- **Typography**: Clean, readable fonts with proper hierarchy
- **Icons**: Intuitive iconography for different file types
- **Animations**: Subtle animations for server status feedback

## 🔐 Security

- Files are only accessible on the local network
- No data is sent to external servers
- Optional password protection (planned feature)
- Proper permission handling for file access

## 🚀 Future Enhancements

- [ ] Upload functionality (allow clients to upload files)
- [ ] Bluetooth sharing without Wi-Fi
- [ ] Background server mode
- [ ] File encryption for secure transfers
- [ ] Custom server port selection
- [ ] Transfer history and analytics
- [ ] Bulk file operations

## 📱 Screenshots

(Screenshots would be added here showing the app interface, server status, file list, and web interface)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Dart shelf package for HTTP server capabilities
- Material Design team for the beautiful design system

---

**AirFiles** - Making file sharing as easy as breathing! 🌬️