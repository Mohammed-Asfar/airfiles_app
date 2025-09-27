import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path_helper;
import 'package:mime/mime.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/file_item.dart';
import 'permission_service.dart';

class FileService {
  final PermissionService _permissionService = PermissionService();
  /// Pick multiple files using the file picker
  Future<List<String>> pickFiles() async {
    try {
      // Request storage permissions first using our permission service
      final hasPermission = await _permissionService.hasStorageAccess();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();
      }

      return [];
    } catch (e) {
      print('Error picking files: $e');
      throw Exception('Failed to pick files: $e');
    }
  }

  /// Pick a directory (Note: This might not work on all platforms)
  Future<String?> pickDirectory() async {
    try {
      // Request storage permissions first using our permission service
      final hasPermission = await _permissionService.hasStorageAccess();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      final result = await FilePicker.platform.getDirectoryPath();
      return result;
    } catch (e) {
      print('Error picking directory: $e');
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

  /// Get common directories (like Downloads, Documents, etc.)
  Future<List<String>> getCommonDirectories() async {
    final directories = <String>[];

    try {
      // Add external storage directories if available
      if (Platform.isAndroid) {
        directories.addAll([
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
          '/storage/emulated/0/Pictures',
          '/storage/emulated/0/DCIM/Camera',
          '/storage/emulated/0/Movies',
          '/storage/emulated/0/Music',
        ]);
      }

      // Filter to only include directories that exist
      final existingDirectories = <String>[];
      for (final dir in directories) {
        if (await Directory(dir).exists()) {
          existingDirectories.add(dir);
        }
      }

      return existingDirectories;
    } catch (e) {
      print('Error getting common directories: $e');
      return [];
    }
  }
}