import 'dart:io';

enum FileItemType {
  file,
  directory,
}

class FileItem {
  final String name;
  final String path;
  final FileItemType type;
  final int size;
  final DateTime lastModified;
  final String? mimeType;

  const FileItem({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.lastModified,
    this.mimeType,
  });

  factory FileItem.fromFileSystemEntity(FileSystemEntity entity, {String? mimeType}) {
    final stat = entity.statSync();
    final isDirectory = entity is Directory;
    
    return FileItem(
      name: entity.path.split(Platform.pathSeparator).last,
      path: entity.path,
      type: isDirectory ? FileItemType.directory : FileItemType.file,
      size: isDirectory ? 0 : stat.size,
      lastModified: stat.modified,
      mimeType: mimeType,
    );
  }

  String get sizeFormatted {
    if (type == FileItemType.directory) return '-';
    
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get extension {
    if (type == FileItemType.directory) return '';
    final dotIndex = name.lastIndexOf('.');
    return dotIndex != -1 ? name.substring(dotIndex + 1).toLowerCase() : '';
  }

  bool get isImage {
    const imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};
    return imageExtensions.contains(extension);
  }

  bool get isVideo {
    const videoExtensions = {'mp4', 'avi', 'mov', 'mkv', 'webm', 'flv'};
    return videoExtensions.contains(extension);
  }

  bool get isAudio {
    const audioExtensions = {'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'};
    return audioExtensions.contains(extension);
  }

  bool get isDocument {
    const docExtensions = {'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt'};
    return docExtensions.contains(extension);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileItem &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() {
    return 'FileItem{name: $name, path: $path, type: $type, size: $size}';
  }
}