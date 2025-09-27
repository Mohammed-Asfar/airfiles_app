# 🔐 AirFiles Permission System

This document describes the comprehensive permission system implemented in AirFiles to ensure secure and proper access to device resources.

## 📱 Platform-Specific Permissions

### Android Permissions

#### **Required Permissions** (AndroidManifest.xml)
```xml
<!-- Network permissions for HTTP server -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Storage permissions for file access -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" 
                 android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
                 android:maxSdkVersion="28" />

<!-- Scoped storage permissions for Android 13+ (API 33+) -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

<!-- File management permissions -->
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />

<!-- Camera and recording permissions -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- Notification permissions for Android 13+ -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Wake lock for keeping server running -->
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Foreground service for background operation -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
```

#### **Android Version Compatibility**
- **Android 6.0+ (API 23+)**: Runtime permission requests
- **Android 10+ (API 29+)**: Scoped storage enforcement
- **Android 11+ (API 30+)**: MANAGE_EXTERNAL_STORAGE required for full access
- **Android 13+ (API 33+)**: Granular media permissions and POST_NOTIFICATIONS

### iOS Permissions

#### **Required Permissions** (Info.plist)
```xml
<!-- File access permissions -->
<key>NSPhotoLibraryUsageDescription</key>
<string>AirFiles needs access to your photos to share them over the local network.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>AirFiles may save shared files to your photo library.</string>

<key>NSCameraUsageDescription</key>
<string>AirFiles needs access to your camera to share photos and videos.</string>

<key>NSMicrophoneUsageDescription</key>
<string>AirFiles needs access to your microphone to share audio files.</string>

<key>NSDocumentsFolderUsageDescription</key>
<string>AirFiles needs access to your documents to share files.</string>

<key>NSDownloadsFolderUsageDescription</key>
<string>AirFiles needs access to your downloads folder to share files.</string>

<!-- Network permissions -->
<key>NSLocalNetworkUsageDescription</key>
<string>AirFiles uses the local network to create a file sharing server and discover devices.</string>

<key>NSBonjourServices</key>
<array>
    <string>_http._tcp.</string>
    <string>_airfiles._tcp.</string>
</array>

<!-- Location permission for WiFi info -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>AirFiles needs location access to determine WiFi network information for secure local sharing.</string>
```

## 🔧 Permission Service Architecture

### Core Components

1. **PermissionService** - Central permission management
2. **PermissionCheckWidget** - UI for permission requests
3. **Runtime Permission Requests** - Dynamic permission handling

### Permission Types

```dart
enum PermissionType {
  storage,           // File system access
  camera,            // Camera access for photos/videos
  microphone,        // Audio recording access
  location,          // Network/WiFi information
  notification,      // Push notifications
  manageExternalStorage, // Full storage access (Android 11+)
  photos,            // Photo library access
  videos,            // Video library access
  audio,             // Audio library access
}
```

### Permission Criticality

#### **Critical Permissions** (Required for core functionality)
- **Storage/Media Access**: Essential for file selection and sharing
  - Android: `READ_EXTERNAL_STORAGE`, `READ_MEDIA_*` permissions
  - iOS: `NSPhotoLibraryUsageDescription`

#### **Optional Permissions** (Enhanced functionality)
- **Location**: For WiFi network information display
- **Camera/Microphone**: For capturing and sharing media
- **Notifications**: For server status updates

## 📋 Permission Request Flow

### 1. App Launch
```
App Start → PermissionCheckWidget → Check Required Permissions
    ↓
If Missing → Show Permission Request UI
    ↓
User Grants → Continue to HomePage
    ↓
User Denies → Show Rationale Dialog
```

### 2. Feature Usage
```
User Action (e.g., Select Files) → Check Storage Permissions
    ↓
If Missing → Request with Rationale
    ↓
If Granted → Proceed with Action
    ↓
If Denied → Show Error Message
```

### 3. Permission Request Strategy

#### **Storage Permissions**
```dart
// For Android 13+ (API 33+)
- Request READ_MEDIA_IMAGES
- Request READ_MEDIA_VIDEO
- Request READ_MEDIA_AUDIO

// For Android 12 and below
- Request READ_EXTERNAL_STORAGE

// For iOS
- Request Photo Library Access
```

#### **Network Permissions**
```dart
// Android: Location permission for WiFi info
await Permission.location.request();

// iOS: Built-in network access
// No runtime permission needed
```

## 🛡️ Security Considerations

### 1. **Minimal Permission Principle**
- Only request permissions actually needed
- Request permissions when required, not at app start
- Provide clear rationale for each permission

### 2. **Graceful Degradation**
- Core functionality works with minimal permissions
- Enhanced features available with additional permissions
- Clear indication of missing permissions

### 3. **User Control**
- Easy access to permission settings
- Clear explanation of what each permission enables
- Option to continue with limited functionality

## 🎯 User Experience

### Permission Request UI Features

1. **Visual Permission Status**
   - Green checkmarks for granted permissions
   - Red warnings for critical missing permissions
   - Clear descriptions for each permission

2. **Rationale Dialogs**
   - Explain why permission is needed
   - Context-specific explanations
   - Non-intrusive optional permissions

3. **Settings Integration**
   - Direct links to app settings
   - Guidance for manual permission enabling
   - Fallback options for denied permissions

### Status Indicators

- **Permission Warning Banner**: Shows when critical permissions are missing
- **Feature Availability**: Grays out unavailable features
- **Error Messages**: Clear guidance when permissions prevent actions

## 🔄 Permission Monitoring

### Runtime Checks
```dart
// Before critical operations
final hasPermission = await PermissionService().requestStoragePermissions(
  context: context,
  showRationale: true,
);

if (!hasPermission) {
  // Show error or alternative flow
  return;
}

// Proceed with operation
```

### Continuous Monitoring
- Check permissions on app resume
- Monitor permission changes
- Update UI based on permission status

## 🧪 Testing Permissions

### Test Scenarios

1. **Fresh Install**: All permissions denied initially
2. **Partial Permissions**: Some granted, some denied
3. **Permission Revocation**: User revokes permissions
4. **Settings Return**: User returns from settings with changed permissions

### Testing Commands
```bash
# Reset all permissions (Android)
adb shell pm reset-permissions com.example.airfiles_app

# Grant specific permission (Android)
adb shell pm grant com.example.airfiles_app android.permission.READ_EXTERNAL_STORAGE

# Revoke permission (Android)
adb shell pm revoke com.example.airfiles_app android.permission.CAMERA
```

## 📊 Permission Analytics

Track permission request outcomes:
- Grant rate per permission type
- Common denial patterns
- User journey through permission requests
- Impact of rationale dialogs

## 🔮 Future Enhancements

### Planned Permission Features
1. **Background Location**: For hotspot mode
2. **Device Admin**: For advanced networking
3. **Accessibility**: For enhanced file management
4. **Biometric**: For secure file access

### Platform Updates
- Stay updated with Android/iOS permission changes
- Adapt to new privacy requirements
- Implement new permission best practices

---

This comprehensive permission system ensures AirFiles operates securely while providing the best possible user experience across all supported platforms.