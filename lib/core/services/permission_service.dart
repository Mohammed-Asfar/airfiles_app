import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

enum PermissionType {
  storage,
  camera,
  microphone,
  location,
  notification,
  manageExternalStorage,
  photos,
  videos,
  audio,
}

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Check if all required permissions are granted
  Future<bool> hasAllRequiredPermissions() async {
    try {
      // Only check critical permissions (storage) for the main permission banner
      // Other permissions are optional and shouldn't block the app
      return await hasStorageAccess();
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }
  
  /// Check if all permissions (including optional ones) are granted
  Future<bool> hasAllOptionalPermissions() async {
    try {
      final requiredPermissions = await _getRequiredPermissions();
      
      for (final permission in requiredPermissions) {
        final status = await permission.status;
        if (status != PermissionStatus.granted) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  /// Request all required permissions
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    try {
      final requiredPermissions = await _getRequiredPermissions();
      return await requiredPermissions.request();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return {};
    }
  }

  /// Request specific permission type
  Future<PermissionStatus> requestPermission(PermissionType type) async {
    try {
      final permission = _getPermissionByType(type);
      if (permission == null) {
        return PermissionStatus.denied;
      }

      final status = await permission.status;
      if (status == PermissionStatus.granted) {
        return status;
      }

      return await permission.request();
    } catch (e) {
      debugPrint('Error requesting $type permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check specific permission status
  Future<PermissionStatus> checkPermission(PermissionType type) async {
    try {
      final permission = _getPermissionByType(type);
      if (permission == null) {
        return PermissionStatus.denied;
      }

      return await permission.status;
    } catch (e) {
      debugPrint('Error checking $type permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request storage permissions with explanation
  Future<bool> requestStoragePermissions({
    required BuildContext context,
    bool showRationale = true,
  }) async {
    try {
      // Get Android version for proper permission handling
      final androidVersion = await _getAndroidVersion();
      
      if (Platform.isAndroid && androidVersion >= 33) {
        // Android 13+ uses granular media permissions
        return await _requestAndroid13StoragePermissions(context, showRationale);
      } else if (Platform.isAndroid) {
        // Android 12 and below use legacy storage permission
        return await _requestLegacyStoragePermissions(context, showRationale);
      } else if (Platform.isIOS) {
        // iOS uses photo library permission
        return await _requestIOSStoragePermissions(context, showRationale);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error requesting storage permissions: $e');
      return false;
    }
  }
  
  /// Request Android 13+ granular media permissions
  Future<bool> _requestAndroid13StoragePermissions(
    BuildContext context, 
    bool showRationale,
  ) async {
    try {
      final androidVersion = await _getAndroidVersion();
      
      // Check current permissions
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;
      final audioStatus = await Permission.audio.status;
      
      // For Android 14+, check for partial access as well
      if (androidVersion >= 34) {
        // Android 14 introduced "Selected Photos Access"
        if (photosStatus == PermissionStatus.granted ||
            photosStatus == PermissionStatus.limited ||
            videosStatus == PermissionStatus.granted ||
            videosStatus == PermissionStatus.limited ||
            audioStatus == PermissionStatus.granted) {
          return true;
        }
      } else {
        // For Android 13, standard granted check
        if (photosStatus == PermissionStatus.granted ||
            videosStatus == PermissionStatus.granted ||
            audioStatus == PermissionStatus.granted) {
          return true;
        }
      }
      
      // Show rationale if needed
      if (showRationale && context.mounted) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Media Access Required',
          androidVersion >= 34 
              ? 'AirFiles needs access to your photos, videos, or audio files to share them. '
                'On Android 14+, you can choose to grant access to all media or select specific items.'
              : 'AirFiles needs access to your photos, videos, or audio files to share them. '
                'You can grant access to specific media types.',
          'Grant Access',
        );
        
        if (!shouldRequest) {
          return false;
        }
      }
      
      // Request media permissions one by one for better compatibility
      Permission? requestedPermission;
      
      // Try photos first
      if (photosStatus != PermissionStatus.granted && photosStatus != PermissionStatus.limited) {
        requestedPermission = Permission.photos;
        final result = await requestedPermission.request();
        if (result == PermissionStatus.granted || result == PermissionStatus.limited) {
          return true;
        }
      }
      
      // Try videos next
      if (videosStatus != PermissionStatus.granted && videosStatus != PermissionStatus.limited) {
        requestedPermission = Permission.videos;
        final result = await requestedPermission.request();
        if (result == PermissionStatus.granted || result == PermissionStatus.limited) {
          return true;
        }
      }
      
      // Try audio last
      if (audioStatus != PermissionStatus.granted) {
        requestedPermission = Permission.audio;
        final result = await requestedPermission.request();
        if (result == PermissionStatus.granted) {
          return true;
        }
      }
      
      // If none granted, check if at least limited access is available
      final finalPhotosStatus = await Permission.photos.status;
      final finalVideosStatus = await Permission.videos.status;
      
      return finalPhotosStatus == PermissionStatus.limited ||
             finalVideosStatus == PermissionStatus.limited ||
             finalPhotosStatus == PermissionStatus.granted ||
             finalVideosStatus == PermissionStatus.granted ||
             audioStatus == PermissionStatus.granted;
             
    } catch (e) {
      debugPrint('Error requesting Android 13+ storage permissions: $e');
      return false;
    }
  }
  
  /// Request legacy storage permissions for Android 12 and below
  Future<bool> _requestLegacyStoragePermissions(
    BuildContext context,
    bool showRationale,
  ) async {
    try {
      // Check current permission
      final storageStatus = await Permission.storage.status;
      
      if (storageStatus == PermissionStatus.granted) {
        return true;
      }
      
      // Show rationale if needed
      if (showRationale && context.mounted) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Storage Access Required',
          'AirFiles needs access to your device storage to select and share files.',
          'Grant Access',
        );
        
        if (!shouldRequest) {
          return false;
        }
      }
      
      // Request storage permission
      final result = await Permission.storage.request();
      return result == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error requesting legacy storage permissions: $e');
      return false;
    }
  }
  
  /// Request iOS storage permissions
  Future<bool> _requestIOSStoragePermissions(
    BuildContext context,
    bool showRationale,
  ) async {
    try {
      // Check current permission
      final photosStatus = await Permission.photos.status;
      
      if (photosStatus == PermissionStatus.granted) {
        return true;
      }
      
      // Show rationale if needed
      if (showRationale && context.mounted) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Photo Library Access Required',
          'AirFiles needs access to your photo library to share photos and videos.',
          'Grant Access',
        );
        
        if (!shouldRequest) {
          return false;
        }
      }
      
      // Request photos permission
      final result = await Permission.photos.request();
      return result == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error requesting iOS storage permissions: $e');
      return false;
    }
  }

  /// Request network permissions
  Future<bool> requestNetworkPermissions({
    required BuildContext context,
    bool showRationale = true,
  }) async {
    try {
      if (Platform.isIOS) {
        // iOS doesn't require runtime permission for network access
        return true;
      }

      // For Android, check location permission (needed for WiFi info)
      final locationStatus = await Permission.location.status;
      if (locationStatus == PermissionStatus.granted) {
        return true;
      }

      // Show rationale if needed
      if (showRationale && context.mounted) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Location Access Required',
          'AirFiles needs location access to determine your WiFi network information. '
          'This helps ensure secure local file sharing within your network.',
          'Grant Access',
        );

        if (!shouldRequest) {
          return false;
        }
      }

      final result = await Permission.location.request();
      return result == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error requesting network permissions: $e');
      return false;
    }
  }

  /// Request camera and microphone permissions
  Future<bool> requestMediaPermissions({
    required BuildContext context,
    bool showRationale = true,
  }) async {
    try {
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;

      if (cameraStatus == PermissionStatus.granted && microphoneStatus == PermissionStatus.granted) {
        return true;
      }

      // Show rationale if needed
      if (showRationale && context.mounted) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Camera & Microphone Access',
          'AirFiles can access your camera and microphone to share photos, videos, and audio files. '
          'This is optional and only used when you choose to share media files.',
          'Grant Access',
        );

        if (!shouldRequest) {
          return false;
        }
      }

      final results = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      return results.values.every((status) => status == PermissionStatus.granted || status == PermissionStatus.denied);
    } catch (e) {
      debugPrint('Error requesting media permissions: $e');
      return false;
    }
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestNotificationPermission({
    required BuildContext context,
    bool showRationale = true,
  }) async {
    try {
      if (Platform.isIOS) {
        // iOS handles notification permissions differently
        return true;
      }

      final status = await Permission.notification.status;
      if (status == PermissionStatus.granted) {
        return true;
      }

      // Show rationale if needed
      if (showRationale && context.mounted) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Notification Permission',
          'AirFiles can send notifications to keep you informed about server status and file transfers. '
          'This helps you know when your files are being accessed.',
          'Allow Notifications',
        );

        if (!shouldRequest) {
          return false;
        }
      }

      final result = await Permission.notification.request();
      return result == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Show permission settings dialog
  Future<bool> showPermissionSettings({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Get required permissions based on platform
  Future<List<Permission>> _getRequiredPermissions() async {
    final permissions = <Permission>[];

    if (Platform.isAndroid) {
      permissions.addAll([
        Permission.storage,
        Permission.location,
      ]);

      // Add Android 13+ permissions
      final isAndroid13Plus = await _isAndroid13OrHigher();
      if (isAndroid13Plus) {
        permissions.addAll([
          Permission.photos,
          Permission.videos,
          Permission.audio,
          Permission.notification,
        ]);
      }
    } else if (Platform.isIOS) {
      permissions.addAll([
        Permission.photos,
        Permission.camera,
        Permission.microphone,
        Permission.locationWhenInUse,
      ]);
    }

    return permissions;
  }

  
  /// Check if storage permissions are available (granted or limited) - Android only
  Future<bool> hasStorageAccess() async {
    try {
      final androidVersion = await _getAndroidVersion();
      
      if (androidVersion >= 33) {
        // Android 13+ - check media permissions
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;
        final audioStatus = await Permission.audio.status;
        
        // Accept granted or limited (Android 14+)
        return photosStatus == PermissionStatus.granted ||
               photosStatus == PermissionStatus.limited ||
               videosStatus == PermissionStatus.granted ||
               videosStatus == PermissionStatus.limited ||
               audioStatus == PermissionStatus.granted;
      } else {
        // Android 12 and below - legacy storage
        final storageStatus = await Permission.storage.status;
        return storageStatus == PermissionStatus.granted;
      }
    } catch (e) {
      debugPrint('Error checking storage access: $e');
      return false;
    }
  }

  /// Get permission by type
  Permission? _getPermissionByType(PermissionType type) {
    switch (type) {
      case PermissionType.storage:
        return Permission.storage;
      case PermissionType.camera:
        return Permission.camera;
      case PermissionType.microphone:
        return Permission.microphone;
      case PermissionType.location:
        return Platform.isIOS ? Permission.locationWhenInUse : Permission.location;
      case PermissionType.notification:
        return Permission.notification;
      case PermissionType.manageExternalStorage:
        return Permission.manageExternalStorage;
      case PermissionType.photos:
        return Permission.photos;
      case PermissionType.videos:
        return Permission.videos;
      case PermissionType.audio:
        return Permission.audio;
    }
  }

  /// Show permission rationale dialog
  Future<bool> _showPermissionRationale(
    BuildContext context,
    String title,
    String message,
    String positiveAction,
  ) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(positiveAction),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Check if Android version is 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    try {
      final androidVersion = await _getAndroidVersion();
      return androidVersion >= 33;
    } catch (e) {
      return Platform.isAndroid; // Default fallback
    }
  }
  
  /// Get Android SDK version
  Future<int> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.version.sdkInt;
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting Android version: $e');
      return 30; // Default to Android 11 (API 30)
    }
  }

  /// Get permission status description
  String getPermissionStatusDescription(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.provisional:
        return 'Provisional';
    }
  }

  /// Check if permission is critical for app functionality
  bool isCriticalPermission(PermissionType type) {
    switch (type) {
      case PermissionType.storage:
      case PermissionType.photos:
      case PermissionType.videos:
      case PermissionType.audio:
        return true;
      case PermissionType.camera:
      case PermissionType.microphone:
      case PermissionType.location:
      case PermissionType.notification:
      case PermissionType.manageExternalStorage:
        return false;
    }
  }
}