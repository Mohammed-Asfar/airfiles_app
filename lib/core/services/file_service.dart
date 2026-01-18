import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';
import 'permission_service.dart';

class FileService {
  final PermissionService _permissionService = PermissionService();
  
  // Global navigator key for accessing context
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  /// Pick multiple files using the file picker with enhanced scoped storage handling
  Future<List<String>> pickFiles() async {
    try {
      // Request storage permissions first using our permission service
      final hasPermission = await _permissionService.hasStorageAccess();
      if (!hasPermission) {
        // Try to request permissions if context is available
        final context = navigatorKey.currentContext;
        if (context != null) {
          final permissionGranted = await _permissionService.requestStoragePermissions(
            context: context,
            showRationale: true,
          );
          if (!permissionGranted) {
            throw Exception('Storage permission denied');
          }
        } else {
          throw Exception('Storage permission required. Please grant permission in app settings.');
        }
      }

      // Try multiple picker strategies for better compatibility
      List<String> validPaths = [];
      
      // Strategy 1: Standard file picker with stream support
      try {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.any,
          allowCompression: false,
          withData: false, // Don't load file data into memory for performance
          withReadStream: true, // Use read stream for large files
        );

        if (result != null && result.files.isNotEmpty) {
          validPaths = await _processPickedFiles(result.files, useStreams: true);
        }
      } catch (e) {
        print('Stream-based picker failed: $e');
        
        // Strategy 2: Fallback to data-based picker for scoped storage compatibility
        try {
          final result = await FilePicker.platform.pickFiles(
            allowMultiple: true,
            type: FileType.any,
            allowCompression: false,
            withData: true, // Load file data to handle content URIs
            withReadStream: false,
          );

          if (result != null && result.files.isNotEmpty) {
            validPaths = await _processPickedFiles(result.files, useStreams: false);
          }
        } catch (e2) {
          print('Data-based picker also failed: $e2');
          throw Exception(
              'Unable to access files. This may be due to Android scoped storage restrictions. '
              'Try selecting files from the following locations:\n'
              '• Downloads folder\n'
              '• Documents folder\n'
              '• Pictures/DCIM folder\n'
              '• App-specific directories\n'
              'Avoid selecting from: Recent files, Google Drive, or other cloud storage.'
          );
        }
      }

      if (validPaths.isEmpty) {
        throw Exception(
            'No accessible files were selected. '
            'On Android 10+, some file locations may not be accessible due to scoped storage. '
            'Try selecting files from Downloads, Documents, or Pictures folders.'
        );
      }

      return validPaths;
    } catch (e) {
      print('Error picking files: $e');
      rethrow;
    }
  }

  /// Process picked files with different strategies
  Future<List<String>> _processPickedFiles(List<PlatformFile> files, {required bool useStreams}) async {
    final validPaths = <String>[];
    
    for (final file in files) {
      try {
        // Strategy 1: Direct path access (works for most local files)
        if (file.path != null && file.path!.isNotEmpty) {
          final fileEntity = File(file.path!);
          if (await fileEntity.exists() && await _canAccessFile(fileEntity)) {
            validPaths.add(file.path!);
            continue;
          }
        }
        
        // Strategy 2: Handle content URIs by creating temporary files
        if (!useStreams && file.bytes != null) {
          final tempPath = await _createTempFileFromBytes(file);
          if (tempPath != null) {
            validPaths.add(tempPath);
            continue;
          }
        }
        
        // Strategy 3: Use read stream if available (for large files)
        if (useStreams && file.readStream != null) {
          final tempPath = await _createTempFileFromStream(file);
          if (tempPath != null) {
            validPaths.add(tempPath);
            continue;
          }
        }
        
        print('Unable to process file: ${file.name} (path: ${file.path})');
      } catch (e) {
        print('Error processing file ${file.name}: $e');
      }
    }
    
    return validPaths;
  }

  /// Check if we can actually access and read a file
  Future<bool> _canAccessFile(File file) async {
    try {
      final stat = await file.stat();
      return stat.size >= 0; // File exists and is readable
    } catch (e) {
      return false;
    }
  }

  /// Create temporary file from read stream
  Future<String?> _createTempFileFromStream(PlatformFile file) async {
    try {
      if (file.readStream == null) return null;
      
      final tempDir = await getTemporaryDirectory();
      final fileName = file.name.isNotEmpty ? file.name : 'temp_file_${DateTime.now().millisecondsSinceEpoch}';
      final tempFile = File('${tempDir.path}/$fileName');
      
      final sink = tempFile.openWrite();
      await sink.addStream(file.readStream!);
      await sink.close();
      
      return tempFile.path;
    } catch (e) {
      print('Error creating temp file from stream: $e');
      return null;
    }
  }

  /// Create temporary file from file bytes (for content URIs)
  Future<String?> _createTempFileFromBytes(PlatformFile file) async {
    try {
      if (file.bytes == null) return null;
      
      final tempDir = await getTemporaryDirectory();
      final fileName = file.name.isNotEmpty ? file.name : 'temp_file';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(file.bytes!);
      
      return tempFile.path;
    } catch (e) {
      print('Error creating temp file: $e');
      return null;
    }
  }

  /// Pick a directory (Note: This might not work on all platforms)
  Future<String?> pickDirectory() async {
    try {
      // Request storage permissions first using our permission service
      final hasPermission = await _permissionService.hasStorageAccess();
      if (!hasPermission) {
        // Try to request permissions if context is available
        final context = navigatorKey.currentContext;
        if (context != null) {
          final permissionGranted = await _permissionService.requestStoragePermissions(
            context: context,
            showRationale: true,
          );
          if (!permissionGranted) {
            throw Exception('Storage permission denied');
          }
        } else {
          throw Exception('Storage permission required. Please grant permission in app settings.');
        }
      }

      final result = await FilePicker.platform.getDirectoryPath();
      
      if (result != null) {
        // Verify directory exists and is accessible
        try {
          final directory = Directory(result);
          if (await directory.exists()) {
            return result;
          } else {
            print('Directory not accessible: $result');
            return null;
          }
        } catch (e) {
          print('Error verifying directory $result: $e');
          return null;
        }
      }
      
      return result;
    } catch (e) {
      print('Error picking directory: $e');
      if (e.toString().contains('unknown_path') || e.toString().contains('failed to retrieve path')) {
        throw Exception('Unable to access directory paths. This may be due to Android scoped storage restrictions.');
      }
      throw Exception('Failed to pick directory: $e');
    }
  }

  /// Get file items from a list of paths
  Future<List<FileItem>> getFileItems(List<String> paths) async {
    final items = <FileItem>[];

    for (final path in paths) {
      try {
        final entity = await FileSystemEntity.type(path);
        
        if (entity == FileSystemEntityType.file) {
          final file = File(path);
          if (await file.exists()) {
            final mimeType = lookupMimeType(path);
            items.add(FileItem.fromFileSystemEntity(file, mimeType: mimeType));
          }
        } else if (entity == FileSystemEntityType.directory) {
          final directory = Directory(path);
          if (await directory.exists()) {
            items.add(FileItem.fromFileSystemEntity(directory));
          }
        }
      } catch (e) {
        print('Error processing path $path: $e');
        // Continue with other files
      }
    }

    return items;
  }

  /// Get files in a directory
  Future<List<FileItem>> getDirectoryContents(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        throw Exception('Directory does not exist: $directoryPath');
      }

      final entities = await directory.list().toList();
      final items = <FileItem>[];

      for (final entity in entities) {
        try {
          if (entity is File) {
            final mimeType = lookupMimeType(entity.path);
            items.add(FileItem.fromFileSystemEntity(entity, mimeType: mimeType));
          } else if (entity is Directory) {
            items.add(FileItem.fromFileSystemEntity(entity));
          }
        } catch (e) {
          print('Error processing entity ${entity.path}: $e');
          // Continue with other entities
        }
      }

      // Sort: directories first, then files, both alphabetically
      items.sort((a, b) {
        if (a.type != b.type) {
          return a.type == FileItemType.directory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return items;
    } catch (e) {
      print('Error getting directory contents: $e');
      throw Exception('Failed to read directory: $e');
    }
  }

  /// Get total size of files and directories
  Future<int> getTotalSize(List<String> paths) async {
    int totalSize = 0;

    for (final path in paths) {
      try {
        totalSize += await _getPathSize(path);
      } catch (e) {
        print('Error calculating size for $path: $e');
        // Continue with other paths
      }
    }

    return totalSize;
  }

  /// Get size of a single path (file or directory)
  Future<int> _getPathSize(String path) async {
    final entity = await FileSystemEntity.type(path);
    
    if (entity == FileSystemEntityType.file) {
      final file = File(path);
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.size;
      }
    } else if (entity == FileSystemEntityType.directory) {
      return await _getDirectorySize(Directory(path));
    }

    return 0;
  }

  /// Calculate directory size recursively
  Future<int> _getDirectorySize(Directory directory) async {
    int size = 0;

    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            size += stat.size;
          } catch (e) {
            // Skip files that can't be accessed
          }
        }
      }
    } catch (e) {
      print('Error calculating directory size: $e');
    }

    return size;
  }

  /// Validate if paths exist and are accessible
  Future<List<String>> validatePaths(List<String> paths) async {
    final validPaths = <String>[];

    for (final path in paths) {
      try {
        if (await FileSystemEntity.isFile(path) || await FileSystemEntity.isDirectory(path)) {
          validPaths.add(path);
        }
      } catch (e) {
        print('Path validation failed for $path: $e');
        // Skip invalid paths
      }
    }

    return validPaths;
  }

  /// Get file type category
  String getFileCategory(FileItem item) {
    if (item.type == FileItemType.directory) {
      return 'Folder';
    }

    if (item.isImage) return 'Image';
    if (item.isVideo) return 'Video';
    if (item.isAudio) return 'Audio';
    if (item.isDocument) return 'Document';

    return 'File';
  }

  /// Format file size in human readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Check if we have permission to access storage
  Future<bool> hasStoragePermission() async {
    return await _permissionService.hasStorageAccess();
  }

  /// Get common directories (like Downloads, Documents, etc.) with scoped storage compatibility info
  Future<List<Map<String, dynamic>>> getCommonDirectoriesWithInfo() async {
    final directoriesInfo = <Map<String, dynamic>>[];

    try {
      // Add external storage directories if available
      if (Platform.isAndroid) {
        final candidateDirs = [
          {
            'path': '/storage/emulated/0/Download',
            'name': 'Downloads',
            'description': 'Best compatibility - Files downloaded from browsers/apps',
            'compatibility': 'excellent'
          },
          {
            'path': '/storage/emulated/0/Documents',
            'name': 'Documents',
            'description': 'Good compatibility - User documents',
            'compatibility': 'good'
          },
          {
            'path': '/storage/emulated/0/Pictures',
            'name': 'Pictures',
            'description': 'Good compatibility - User photos',
            'compatibility': 'good'
          },
          {
            'path': '/storage/emulated/0/DCIM/Camera',
            'name': 'Camera Photos',
            'description': 'Good compatibility - Camera photos',
            'compatibility': 'good'
          },
          {
            'path': '/storage/emulated/0/Movies',
            'name': 'Movies',
            'description': 'Good compatibility - User videos',
            'compatibility': 'good'
          },
          {
            'path': '/storage/emulated/0/Music',
            'name': 'Music',
            'description': 'Good compatibility - Music files',
            'compatibility': 'good'
          },
        ];

        // Check which directories exist and are accessible
        for (final dirInfo in candidateDirs) {
          final path = dirInfo['path'] as String;
          try {
            final dir = Directory(path);
            if (await dir.exists()) {
              directoriesInfo.add({
                ...dirInfo,
                'exists': true,
                'accessible': await _canAccessDirectory(dir),
              });
            } else {
              directoriesInfo.add({
                ...dirInfo,
                'exists': false,
                'accessible': false,
              });
            }
          } catch (e) {
            directoriesInfo.add({
              ...dirInfo,
              'exists': false,
              'accessible': false,
              'error': e.toString(),
            });
          }
        }
      }

      return directoriesInfo;
    } catch (e) {
      print('Error getting common directories info: $e');
      return [];
    }
  }

  /// Check if we can access a directory
  Future<bool> _canAccessDirectory(Directory directory) async {
    try {
      await directory.list().take(1).toList();
      return true; // If we can list contents, we have access
    } catch (e) {
      return false;
    }
  }

  /// Get user-friendly tips for file selection based on Android version
  Future<String> getFileSelectionTips() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 30) { // Android 11+
        return '''
Android 11+ File Selection Tips:

✅ RECOMMENDED LOCATIONS:
• Downloads folder - Best compatibility
• Documents folder - Good for documents
• Pictures/DCIM - Good for photos
• Movies - Good for videos
• Music - Good for audio files

❌ AVOID THESE LOCATIONS:
• Recent files (may use content URIs)
• Google Drive or cloud storage
• Third-party file manager "Recent" sections
• App-specific folders of other apps

💡 TIP: If file selection fails, try:
1. Use a file manager to copy files to Downloads
2. Select files directly from folders, not from "Recent"
3. Avoid selecting from cloud storage providers''';
      } else if (sdkInt >= 29) { // Android 10
        return '''
Android 10 File Selection Tips:

✅ RECOMMENDED LOCATIONS:
• Downloads folder - Best compatibility
• External storage public folders
• Media folders (Pictures, Movies, Music)

❌ AVOID THESE LOCATIONS:
• App-specific private folders
• System directories
• Some third-party app folders

💡 TIP: Scoped storage is enforced - stick to public directories''';
      } else {
        return '''
Android 9 and below:

✅ Most file locations should work with proper permissions
• Internal storage
• External storage (SD card)
• All public directories

💡 TIP: Fewer restrictions on older Android versions''';
      }
    } catch (e) {
      return 'For best results, select files from Downloads, Documents, or Pictures folders.';
    }
  }
}