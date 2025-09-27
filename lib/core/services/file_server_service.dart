import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path_helper;
import '../models/file_item.dart';
import '../models/server_config.dart';

class FileServerService {
  HttpServer? _server;
  ServerConfig? _config;
  List<String> _sharedPaths = [];

  bool get isRunning => _server != null;
  ServerConfig? get config => _config;
  List<String> get sharedPaths => List.unmodifiable(_sharedPaths);

  Future<ServerConfig> startServer({
    required String address,
    required int port,
    required List<String> sharedPaths,
    String? password,
  }) async {
    if (_server != null) {
      throw Exception('Server is already running');
    }

    _sharedPaths = List.from(sharedPaths);
    
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware(password))
        .addHandler(_createRouter());

    try {
      _server = await shelf_io.serve(
        handler,
        address,
        port,
      );

      _config = ServerConfig(
        address: address,
        port: port,
        passwordProtected: password != null,
        password: password,
        isRunning: true,
      );

      print('File server started at ${_config!.serverUrl}');
      return _config!;
    } catch (e) {
      _server = null;
      _config = null;
      throw Exception('Failed to start server: $e');
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _config = null;
      _sharedPaths.clear();
      print('File server stopped');
    }
  }

  Handler _createRouter() {
    return (Request request) async {
      final path = request.url.path;

      if (path.isEmpty || path == '/') {
        return _generateDirectoryListing('/', _sharedPaths);
      }

      // Handle file/directory requests
      final decodedPath = Uri.decodeComponent(path);
      final filePath = _findSharedPath(decodedPath);

      if (filePath == null) {
        return Response.notFound('File not found');
      }

      final file = File(filePath);
      final directory = Directory(filePath);

      if (await directory.exists()) {
        return _generateDirectoryListing(decodedPath, [filePath]);
      } else if (await file.exists()) {
        return _serveFile(file);
      }

      return Response.notFound('File not found');
    };
  }

  String? _findSharedPath(String requestPath) {
    // Remove leading slash
    final normalizedPath = requestPath.startsWith('/') 
        ? requestPath.substring(1) 
        : requestPath;

    // Check if it's a direct shared path
    for (final sharedPath in _sharedPaths) {
      final fileName = path_helper.basename(sharedPath);
      if (normalizedPath == fileName || normalizedPath.startsWith('$fileName/')) {
        final remainingPath = normalizedPath.substring(fileName.length);
        return path_helper.join(sharedPath, remainingPath.startsWith('/') 
            ? remainingPath.substring(1) 
            : remainingPath);
      }
    }

    return null;
  }

  Future<Response> _serveFile(File file) async {
    try {
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final bytes = await file.readAsBytes();
      
      return Response.ok(
        bytes,
        headers: {
          'Content-Type': mimeType,
          'Content-Length': bytes.length.toString(),
          'Content-Disposition': 'inline; filename="${path_helper.basename(file.path)}"',
        },
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error reading file: $e');
    }
  }

  Response _generateDirectoryListing(String currentPath, List<String> paths) {
    final html = StringBuffer();
    html.writeln('<!DOCTYPE html>');
    html.writeln('<html>');
    html.writeln('<head>');
    html.writeln('<meta charset="UTF-8">');
    html.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    html.writeln('<title>AirFiles - ${currentPath == '/' ? 'Shared Files' : currentPath}</title>');
    html.writeln('<style>');
    html.writeln(_getCSS());
    html.writeln('</style>');
    html.writeln('</head>');
    html.writeln('<body>');
    html.writeln('<div class="container">');
    html.writeln('<header>');
    html.writeln('<h1>🌬️ AirFiles</h1>');
    html.writeln('<p class="subtitle">${currentPath == '/' ? 'Shared Files' : currentPath}</p>');
    html.writeln('</header>');
    
    html.writeln('<div class="file-list">');

    // Add back navigation if not at root
    if (currentPath != '/') {
      final parentPath = path_helper.dirname(currentPath);
      html.writeln('<div class="file-item directory">');
      html.writeln('<a href="${parentPath == '/' ? '/' : parentPath}">');
      html.writeln('<span class="icon">📁</span>');
      html.writeln('<span class="name">.. (Parent Directory)</span>');
      html.writeln('</a>');
      html.writeln('</div>');
    }

    // List files and directories
    try {
      for (final path in paths) {
        final entity = FileSystemEntity.isDirectorySync(path) 
            ? Directory(path) 
            : File(path);
        
        if (entity is Directory) {
          _addDirectoryEntries(html, entity, currentPath);
        } else if (entity is File) {
          _addFileEntry(html, entity, currentPath);
        }
      }
    } catch (e) {
      html.writeln('<div class="error">Error reading directory: $e</div>');
    }

    html.writeln('</div>');
    html.writeln('</div>');
    html.writeln('</body>');
    html.writeln('</html>');

    return Response.ok(
      html.toString(),
      headers: {'Content-Type': 'text/html'},
    );
  }

  void _addDirectoryEntries(StringBuffer html, Directory directory, String currentPath) {
    try {
      final entries = directory.listSync()
        ..sort((a, b) {
          // Directories first, then files
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return path_helper.basename(a.path)
              .toLowerCase()
              .compareTo(path_helper.basename(b.path).toLowerCase());
        });

      for (final entity in entries) {
        if (entity is Directory) {
          final name = path_helper.basename(entity.path);
          final relativePath = currentPath == '/' ? name : '$currentPath/$name';
          
          html.writeln('<div class="file-item directory">');
          html.writeln('<a href="/$relativePath">');
          html.writeln('<span class="icon">📁</span>');
          html.writeln('<span class="name">${_escapeHtml(name)}</span>');
          html.writeln('<span class="size">-</span>');
          html.writeln('</a>');
          html.writeln('</div>');
        } else if (entity is File) {
          _addFileEntry(html, entity, currentPath);
        }
      }
    } catch (e) {
      html.writeln('<div class="error">Error listing directory contents: $e</div>');
    }
  }

  void _addFileEntry(StringBuffer html, File file, String currentPath) {
    try {
      final name = path_helper.basename(file.path);
      final stat = file.statSync();
      final size = _formatFileSize(stat.size);
      final relativePath = currentPath == '/' ? name : '$currentPath/$name';
      final icon = _getFileIcon(name);

      html.writeln('<div class="file-item file">');
      html.writeln('<a href="/$relativePath" target="_blank">');
      html.writeln('<span class="icon">$icon</span>');
      html.writeln('<span class="name">${_escapeHtml(name)}</span>');
      html.writeln('<span class="size">$size</span>');
      html.writeln('</a>');
      html.writeln('</div>');
    } catch (e) {
      // Skip files that can't be accessed
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getFileIcon(String fileName) {
    final extension = path_helper.extension(fileName).toLowerCase();
    
    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
        return '🖼️';
      case '.mp4':
      case '.avi':
      case '.mov':
      case '.mkv':
      case '.webm':
        return '🎬';
      case '.mp3':
      case '.wav':
      case '.flac':
      case '.aac':
      case '.ogg':
        return '🎵';
      case '.pdf':
        return '📄';
      case '.doc':
      case '.docx':
        return '📝';
      case '.txt':
        return '📄';
      case '.zip':
      case '.rar':
      case '.7z':
        return '📦';
      default:
        return '📄';
    }
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  String _getCSS() {
    return '''
      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }
      
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        min-height: 100vh;
        color: #333;
      }
      
      .container {
        max-width: 800px;
        margin: 0 auto;
        padding: 20px;
      }
      
      header {
        text-align: center;
        margin-bottom: 30px;
        background: rgba(255, 255, 255, 0.9);
        padding: 20px;
        border-radius: 10px;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      }
      
      h1 {
        font-size: 2.5em;
        margin-bottom: 10px;
        color: #4f46e5;
      }
      
      .subtitle {
        color: #6b7280;
        font-size: 1.1em;
      }
      
      .file-list {
        background: rgba(255, 255, 255, 0.95);
        border-radius: 10px;
        overflow: hidden;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      }
      
      .file-item {
        border-bottom: 1px solid #e5e7eb;
        transition: background-color 0.2s;
      }
      
      .file-item:last-child {
        border-bottom: none;
      }
      
      .file-item:hover {
        background-color: #f3f4f6;
      }
      
      .file-item a {
        display: flex;
        align-items: center;
        padding: 15px 20px;
        text-decoration: none;
        color: #374151;
      }
      
      .icon {
        font-size: 1.5em;
        margin-right: 15px;
        width: 30px;
        text-align: center;
      }
      
      .name {
        flex: 1;
        font-weight: 500;
      }
      
      .size {
        color: #6b7280;
        font-size: 0.9em;
        min-width: 80px;
        text-align: right;
      }
      
      .directory .name {
        color: #4f46e5;
        font-weight: 600;
      }
      
      .error {
        color: #dc2626;
        padding: 20px;
        text-align: center;
        background-color: #fef2f2;
        border: 1px solid #fecaca;
        border-radius: 5px;
        margin: 10px;
      }
      
      @media (max-width: 600px) {
        .container {
          padding: 10px;
        }
        
        h1 {
          font-size: 2em;
        }
        
        .file-item a {
          padding: 12px 15px;
        }
        
        .icon {
          margin-right: 10px;
          width: 25px;
        }
        
        .size {
          min-width: 60px;
          font-size: 0.8em;
        }
      }
    ''';
  }

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, X-Auth-Token',
          ...response.headers,
        });
      };
    };
  }

  Middleware _authMiddleware(String? password) {
    return (Handler innerHandler) {
      return (Request request) async {
        if (password == null || password.isEmpty) {
          return innerHandler(request);
        }

        final authHeader = request.headers['authorization'];
        if (authHeader != null && authHeader.startsWith('Basic ')) {
          final credentials = utf8.decode(base64.decode(authHeader.substring(6)));
          final parts = credentials.split(':');
          if (parts.length == 2 && parts[1] == password) {
            return innerHandler(request);
          }
        }

        return Response.unauthorized(
          'Authentication required',
          headers: {'WWW-Authenticate': 'Basic realm="AirFiles"'},
        );
      };
    };
  }
}