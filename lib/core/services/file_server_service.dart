import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path_helper;
import 'package:flutter/services.dart' show rootBundle;
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
        shared: true, // Allow multiple connections
      );
      
      // Optimize for large file transfers
      _server!.defaultResponseHeaders.set('Server', 'AirFiles/1.0');
      _server!.defaultResponseHeaders.set('Connection', 'keep-alive');

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

      if (path == '/logo.png') {
        try {
          final data = await rootBundle.load('assets/logo3.png');
          return Response.ok(
            data.buffer.asUint8List(),
            headers: {'Content-Type': 'image/png'},
          );
        } catch (e) {
          print('Error loading logo: $e');
          return Response.notFound('Logo not found');
        }
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
        // Serve file directly without loading into app memory
        return _serveFileDirectly(file, request);
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

  /// Serve file directly from disk without loading into app memory
  Future<Response> _serveFileDirectly(File file, Request request) async {
    try {
      final stat = await file.stat();
      final fileSize = stat.size;
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final fileName = path_helper.basename(file.path);
      
      // Check for Range header to support partial content requests
      final rangeHeader = request.headers['range'];
      
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        return _servePartialFileDirect(file, mimeType, fileSize, rangeHeader, fileName);
      }
      
      // Always use streaming for direct access (no memory loading)
      final stream = file.openRead();
      
      return Response.ok(
        stream,
        headers: {
          'Content-Type': mimeType,
          'Content-Length': fileSize.toString(),
          'Content-Disposition': _getContentDisposition(mimeType, fileName),
          'Accept-Ranges': 'bytes',
          'Cache-Control': 'public, max-age=3600',
          'Last-Modified': HttpDate.format(stat.modified),
          'ETag': '"${stat.modified.millisecondsSinceEpoch}-${stat.size}"',
        },
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error accessing file: $e');
    }
  }

  /// Serve partial file content directly for range requests
  Future<Response> _servePartialFileDirect(File file, String mimeType, int fileSize, String rangeHeader, String fileName) async {
    try {
      // Parse range header (e.g., "bytes=0-1023" or "bytes=1024-")
      final rangeMatch = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
      if (rangeMatch == null) {
        return Response(416, body: 'Invalid range header');
      }
      
      final start = int.parse(rangeMatch.group(1)!);
      final endStr = rangeMatch.group(2);
      final end = endStr?.isNotEmpty == true ? int.parse(endStr!) : fileSize - 1;
      
      // Validate range
      if (start >= fileSize || end >= fileSize || start > end) {
        return Response(416, 
          body: 'Range not satisfiable',
          headers: {'Content-Range': 'bytes */$fileSize'}
        );
      }
      
      final contentLength = end - start + 1;
      final stream = file.openRead(start, end + 1);
      
      return Response(206, // Partial Content
        body: stream,
        headers: {
          'Content-Type': mimeType,
          'Content-Length': contentLength.toString(),
          'Content-Range': 'bytes $start-$end/$fileSize',
          'Accept-Ranges': 'bytes',
          'Content-Disposition': _getContentDisposition(mimeType, fileName),
          'Cache-Control': 'public, max-age=3600',
        },
      );
    } catch (e) {
      return Response.internalServerError(body: 'Error serving partial file: $e');
    }
  }

  /// Get appropriate content disposition based on file type
  String _getContentDisposition(String mimeType, String fileName) {
    // For media files and PDFs, display inline in browser
    if (mimeType.startsWith('image/') ||
        mimeType.startsWith('video/') ||
        mimeType.startsWith('audio/') ||
        mimeType == 'application/pdf' ||
        mimeType.startsWith('text/')) {
      return 'inline; filename="$fileName"';
    }
    
    // For other files, force download
    return 'attachment; filename="$fileName"';
  }

  Response _generateDirectoryListing(String currentPath, List<String> paths) {
    final html = StringBuffer();
    final displayPath = currentPath == '/' ? 'Shared Files' : path_helper.basename(currentPath);
    final breadcrumbs = _generateBreadcrumbs(currentPath);
    
    html.writeln('<!DOCTYPE html>');
    html.writeln('<html lang="en">');
    html.writeln('<head>');
    html.writeln('<meta charset="UTF-8">');
    html.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    html.writeln('<title>AirFiles</title>');
    html.writeln('<link rel="preconnect" href="https://fonts.googleapis.com">');
    html.writeln('<link href="https://fonts.googleapis.com/css2?family=SF+Pro+Display:wght@400;500;600&display=swap" rel="stylesheet">');
    html.writeln('<style>');
    html.writeln(_getCSS());
    html.writeln('</style>');
    html.writeln('</head>');
    html.writeln('<body>');
    
    // macOS Window Container
    html.writeln('<div class="finder-window">');
    
    // Title Bar
    html.writeln('<div class="title-bar">');
    html.writeln('<div class="title-center">');
    html.writeln('<span class="title-brand">AirFiles</span>');
    html.writeln('<span class="title-sep">—</span>');
    html.writeln('<span class="title-path">$displayPath</span>');
    html.writeln('</div>');
    html.writeln('</div>');
    
    // Toolbar
    html.writeln('<div class="toolbar">');
    html.writeln('<div class="toolbar-left">');
    if (currentPath != '/') {
      final parentPath = path_helper.dirname(currentPath);
      html.writeln('<a href="${parentPath == '/' ? '/' : parentPath}" class="nav-btn" title="Go Back">');
      html.writeln('<svg width="12" height="12" viewBox="0 0 12 12"><path d="M7.5 2L3.5 6L7.5 10" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>');
      html.writeln('</a>');
    } else {
      html.writeln('<span class="nav-btn disabled"><svg width="12" height="12" viewBox="0 0 12 12"><path d="M7.5 2L3.5 6L7.5 10" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg></span>');
    }
    html.writeln('<span class="nav-btn disabled"><svg width="12" height="12" viewBox="0 0 12 12"><path d="M4.5 2L8.5 6L4.5 10" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg></span>');
    html.writeln('</div>');
    html.writeln('<div class="breadcrumbs">$breadcrumbs</div>');
    html.writeln('<div class="toolbar-right"></div>');
    html.writeln('</div>');
    
    // Column Headers
    html.writeln('<div class="column-headers">');
    html.writeln('<div class="col-name">Name</div>');
    html.writeln('<div class="col-date">Date Modified</div>');
    html.writeln('<div class="col-size">Size</div>');
    html.writeln('<div class="col-kind">Kind</div>');
    html.writeln('</div>');
    
    // File List Container
    html.writeln('<div class="file-list">');

    // Add back navigation if not at root
    if (currentPath != '/') {
      final parentPath = path_helper.dirname(currentPath);
      html.writeln('<a href="${parentPath == '/' ? '/' : parentPath}" class="file-row directory">');
      html.writeln('<div class="col-name"><span class="file-icon folder-icon-blue"></span><span class="file-name">..</span></div>');
      html.writeln('<div class="col-date">--</div>');
      html.writeln('<div class="col-size">--</div>');
      html.writeln('<div class="col-kind">Parent Folder</div>');
      html.writeln('</a>');
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
      html.writeln('<div class="error-message">Error reading directory: $e</div>');
    }

    html.writeln('</div>');
    
    // Status Bar
    html.writeln('<div class="status-bar">');
    html.writeln('<span class="item-count">${_getItemCount(paths)} items</span>');
    html.writeln('<span class="airfiles-badge">Powered by AirFiles</span>');
    html.writeln('</div>');
    
    html.writeln('</div>'); // finder-window
    
    // Preview Modal
    html.writeln('<div id="previewModal" class="preview-modal" onclick="closePreview(event)">');
    html.writeln('<div class="preview-content" onclick="event.stopPropagation()">');
    html.writeln('<div class="preview-header">');
    html.writeln('<span id="previewFileName" class="preview-file-name"></span>');
    html.writeln('<button class="preview-close" onclick="closePreview()">&times;</button>');
    html.writeln('</div>');
    html.writeln('<div id="previewBody" class="preview-body"></div>');
    html.writeln('<div class="preview-actions">');
    html.writeln('<a id="previewDownload" href="#" download class="preview-btn download">Download</a>');
    html.writeln('<a id="previewOpen" href="#" target="_blank" class="preview-btn open">Open in New Tab</a>');
    html.writeln('</div>');
    html.writeln('</div>');
    html.writeln('</div>');
    
    // JavaScript for preview
    html.writeln('<script>');
    html.writeln('''
      function openPreview(url, name, type) {
        const modal = document.getElementById('previewModal');
        const body = document.getElementById('previewBody');
        const fileName = document.getElementById('previewFileName');
        const downloadBtn = document.getElementById('previewDownload');
        const openBtn = document.getElementById('previewOpen');
        
        fileName.textContent = name;
        downloadBtn.href = url;
        downloadBtn.download = name;
        openBtn.href = url;
        body.innerHTML = '';
        
        if (type === 'image') {
          body.innerHTML = '<img src="' + url + '" alt="' + name + '" class="preview-image">';
        } else if (type === 'video') {
          body.innerHTML = '<video controls autoplay class="preview-video"><source src="' + url + '">Your browser does not support video.</video>';
        } else if (type === 'audio') {
          body.innerHTML = '<div class="audio-preview"><div class="audio-icon">🎵</div><audio controls autoplay><source src="' + url + '">Your browser does not support audio.</audio></div>';
        } else if (type === 'pdf') {
          body.innerHTML = '<iframe src="' + url + '" class="preview-pdf"></iframe>';
        } else {
          body.innerHTML = '<div class="preview-unsupported"><div class="unsupported-icon">📄</div><p>Preview not available for this file type</p><p class="hint">Click "Open in New Tab" or "Download" to view</p></div>';
        }
        
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
      }
      
      function closePreview(event) {
        if (event && event.target !== document.getElementById('previewModal')) return;
        const modal = document.getElementById('previewModal');
        modal.classList.remove('active');
        document.body.style.overflow = '';
        const body = document.getElementById('previewBody');
        body.innerHTML = '';
      }
      
      document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') closePreview();
      });
    ''');
    html.writeln('</script>');
    
    html.writeln('</body>');
    html.writeln('</html>');

    return Response.ok(
      html.toString(),
      headers: {'Content-Type': 'text/html'},
    );
  }

  String _generateBreadcrumbs(String currentPath) {
    if (currentPath == '/') {
      return '<span class="breadcrumb-item active">Shared Files</span>';
    }
    
    final parts = currentPath.split('/').where((p) => p.isNotEmpty).toList();
    final breadcrumbs = StringBuffer();
    breadcrumbs.write('<a href="/" class="breadcrumb-item">Shared Files</a>');
    
    String accumulatedPath = '';
    for (int i = 0; i < parts.length; i++) {
      accumulatedPath += '/${parts[i]}';
      breadcrumbs.write('<span class="breadcrumb-sep">›</span>');
      if (i == parts.length - 1) {
        breadcrumbs.write('<span class="breadcrumb-item active">${_escapeHtml(parts[i])}</span>');
      } else {
        breadcrumbs.write('<a href="$accumulatedPath" class="breadcrumb-item">${_escapeHtml(parts[i])}</a>');
      }
    }
    
    return breadcrumbs.toString();
  }

  int _getItemCount(List<String> paths) {
    int count = 0;
    for (final path in paths) {
      if (FileSystemEntity.isDirectorySync(path)) {
        try {
          count += Directory(path).listSync().length;
        } catch (_) {}
      } else {
        count++;
      }
    }
    return count;
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
          final stat = entity.statSync();
          final dateModified = _formatDate(stat.modified);
          
          html.writeln('<a href="/$relativePath" class="file-row directory">');
          html.writeln('<div class="col-name"><span class="file-icon folder-icon-blue"></span><span class="file-name">${_escapeHtml(name)}</span></div>');
          html.writeln('<div class="col-date">$dateModified</div>');
          html.writeln('<div class="col-size">--</div>');
          html.writeln('<div class="col-kind">Folder</div>');
          html.writeln('</a>');
        } else if (entity is File) {
          _addFileEntry(html, entity, currentPath);
        }
      }
    } catch (e) {
      html.writeln('<div class="error-message">Error listing directory contents: $e</div>');
    }
  }

  void _addFileEntry(StringBuffer html, File file, String currentPath) {
    try {
      final name = path_helper.basename(file.path);
      final stat = file.statSync();
      final size = _formatFileSize(stat.size);
      final relativePath = currentPath == '/' ? name : '$currentPath/$name';
      final iconClass = _getFileIconClass(name);
      final kind = _getFileKind(name);
      final dateModified = _formatDate(stat.modified);
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      
      // Determine preview type
      String previewType = 'other';
      if (mimeType.startsWith('image/')) {
        previewType = 'image';
      } else if (mimeType.startsWith('video/')) {
        previewType = 'video';
      } else if (mimeType.startsWith('audio/')) {
        previewType = 'audio';
      } else if (mimeType == 'application/pdf') {
        previewType = 'pdf';
      }
      
      final escapedName = _escapeHtml(name).replaceAll("'", "\\'").replaceAll('"', '\\"');
      final encodedUrl = Uri.encodeFull('/$relativePath');

      html.writeln('<div class="file-row file" onclick="openPreview(\x27$encodedUrl\x27, \x27$escapedName\x27, \x27$previewType\x27)">');
      html.writeln('<div class="col-name"><span class="file-icon $iconClass"></span><span class="file-name">${_escapeHtml(name)}</span></div>');
      html.writeln('<div class="col-date">$dateModified</div>');
      html.writeln('<div class="col-size">$size</div>');
      html.writeln('<div class="col-kind">$kind</div>');
      html.writeln('</div>');
    } catch (e) {
      // Skip files that can't be accessed
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes bytes';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _getFileIconClass(String fileName) {
    final extension = path_helper.extension(fileName).toLowerCase();
    
    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
      case '.svg':
      case '.ico':
        return 'icon-image';
      case '.mp4':
      case '.avi':
      case '.mov':
      case '.mkv':
      case '.webm':
      case '.flv':
      case '.wmv':
        return 'icon-video';
      case '.mp3':
      case '.wav':
      case '.flac':
      case '.aac':
      case '.ogg':
      case '.m4a':
      case '.wma':
        return 'icon-audio';
      case '.pdf':
        return 'icon-pdf';
      case '.doc':
      case '.docx':
      case '.odt':
      case '.rtf':
        return 'icon-doc';
      case '.xls':
      case '.xlsx':
      case '.csv':
        return 'icon-spreadsheet';
      case '.ppt':
      case '.pptx':
        return 'icon-presentation';
      case '.txt':
      case '.md':
      case '.log':
        return 'icon-text';
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return 'icon-archive';
      case '.html':
      case '.css':
      case '.js':
      case '.ts':
      case '.json':
      case '.xml':
        return 'icon-code';
      case '.exe':
      case '.msi':
      case '.dmg':
      case '.app':
        return 'icon-app';
      default:
        return 'icon-generic';
    }
  }

  String _getFileKind(String fileName) {
    final extension = path_helper.extension(fileName).toLowerCase();
    
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'JPEG Image';
      case '.png':
        return 'PNG Image';
      case '.gif':
        return 'GIF Image';
      case '.webp':
        return 'WebP Image';
      case '.svg':
        return 'SVG Image';
      case '.mp4':
        return 'MPEG-4 Movie';
      case '.mov':
        return 'QuickTime Movie';
      case '.avi':
        return 'AVI Movie';
      case '.mkv':
        return 'MKV Video';
      case '.mp3':
        return 'MP3 Audio';
      case '.wav':
        return 'WAV Audio';
      case '.flac':
        return 'FLAC Audio';
      case '.aac':
        return 'AAC Audio';
      case '.pdf':
        return 'PDF Document';
      case '.doc':
      case '.docx':
        return 'Word Document';
      case '.xls':
      case '.xlsx':
        return 'Excel Spreadsheet';
      case '.ppt':
      case '.pptx':
        return 'PowerPoint';
      case '.txt':
        return 'Plain Text';
      case '.md':
        return 'Markdown';
      case '.html':
        return 'HTML Document';
      case '.css':
        return 'CSS Stylesheet';
      case '.js':
        return 'JavaScript';
      case '.json':
        return 'JSON File';
      case '.zip':
        return 'ZIP Archive';
      case '.rar':
        return 'RAR Archive';
      case '.7z':
        return '7-Zip Archive';
      case '.exe':
        return 'Application';
      case '.dmg':
        return 'Disk Image';
      default:
        if (extension.isNotEmpty) {
          return '${extension.substring(1).toUpperCase()} File';
        }
        return 'Document';
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
      :root {
        --bg-primary: #F8FAFC;
        --bg-secondary: #FFFFFF;
        --bg-tertiary: #F1F5F9;
        --bg-hover: rgba(78, 205, 196, 0.1);
        --bg-selected: #279A97;
        --text-primary: #1E293B;
        --text-secondary: #334155;
        --text-tertiary: #64748B;
        --border-color: rgba(78, 205, 196, 0.3);
        --border-light: rgba(78, 205, 196, 0.15);
        --accent-primary: #279A97;
        --accent-light: #4ECDC4;
        --accent-dark: #1F7A77;
        --shadow-color: rgba(39, 154, 151, 0.15);
        --title-bar-bg: linear-gradient(180deg, #4ECDC4 0%, #279A97 100%);
        --toolbar-bg: rgba(255, 255, 255, 0.95);
        --folder-gradient: linear-gradient(180deg, #4ECDC4 0%, #279A97 100%);
      }
      
      @media (prefers-color-scheme: dark) {
        :root {
          --bg-primary: #0A1A1A;
          --bg-secondary: #1A2E2E;
          --bg-tertiary: #2A3E3E;
          --bg-hover: rgba(78, 205, 196, 0.15);
          --bg-selected: #279A97;
          --text-primary: #F1F9F9;
          --text-secondary: #E2F4F4;
          --text-tertiary: #94C7C7;
          --border-color: rgba(78, 205, 196, 0.3);
          --border-light: rgba(78, 205, 196, 0.2);
          --shadow-color: rgba(0, 0, 0, 0.4);
          --title-bar-bg: linear-gradient(180deg, #2A3E3E 0%, #1A2E2E 100%);
          --toolbar-bg: rgba(26, 46, 46, 0.95);
        }
      }
      
      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }
      
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif;
        background: var(--bg-primary);
        min-height: 100vh;
        color: var(--text-primary);
        display: flex;
        justify-content: center;
        align-items: flex-start;
        padding: 40px 20px;
        -webkit-font-smoothing: antialiased;
      }
      
      .finder-window {
        width: 100%;
        max-width: 960px;
        background: var(--bg-secondary);
        border-radius: 10px;
        box-shadow: 
          0 22px 70px 4px var(--shadow-color),
          0 0 0 0.5px var(--border-color);
        overflow: hidden;
        display: flex;
        flex-direction: column;
        min-height: 600px;
        max-height: calc(100vh - 80px);
      }
      
      /* Title Bar */
      .title-bar {
        background: var(--title-bar-bg);
        height: 52px;
        display: flex;
        align-items: center;
        padding: 0 16px;
        border-bottom: 1px solid var(--border-color);
        flex-shrink: 0;
        -webkit-app-region: drag;
      }
      
      .traffic-lights {
        display: flex;
        gap: 8px;
        padding: 4px;
      }
      
      .light {
        width: 12px;
        height: 12px;
        border-radius: 50%;
        cursor: pointer;
      }
      
      .light.close {
        background: linear-gradient(180deg, #FF6058 0%, #E04B43 100%);
        border: 0.5px solid #CE3C35;
      }
      
      .light.minimize {
        background: linear-gradient(180deg, #FFC02F 0%, #DFA023 100%);
        border: 0.5px solid #CA8F1E;
      }
      
      .light.maximize {
        background: linear-gradient(180deg, #2ACB42 0%, #1AAD33 100%);
        border: 0.5px solid #149D2B;
      }
      
      .title-center {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
      }
      
      .title-logo {
        display: flex;
        align-items: center;
        justify-content: center;
      }
      
      .title-brand {
        font-size: 14px;
        font-weight: 700;
        color: #FFFFFF;
        text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
        letter-spacing: 0.5px;
      }
      
      .title-sep {
        color: rgba(255, 255, 255, 0.5);
        font-weight: 300;
      }
      
      .title-path {
        font-size: 13px;
        font-weight: 500;
        color: rgba(255, 255, 255, 0.9);
        text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
      }
      
      .title-spacer {
        width: 68px;
      }
      
      /* Toolbar */
      .toolbar {
        background: var(--toolbar-bg);
        height: 38px;
        display: flex;
        align-items: center;
        padding: 0 12px;
        gap: 12px;
        border-bottom: 1px solid var(--border-color);
        flex-shrink: 0;
      }
      
      .toolbar-left {
        display: flex;
        gap: 4px;
      }
      
      .nav-btn {
        width: 28px;
        height: 24px;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 5px;
        color: var(--text-secondary);
        text-decoration: none;
        transition: all 0.15s ease;
      }
      
      .nav-btn:hover:not(.disabled) {
        background: var(--bg-hover);
        color: #279A97;
      }
      
      .nav-btn.disabled {
        opacity: 0.35;
        cursor: default;
      }
      
      .breadcrumbs {
        flex: 1;
        display: flex;
        align-items: center;
        gap: 4px;
        overflow: hidden;
        font-size: 12px;
      }
      
      .breadcrumb-item {
        color: var(--text-secondary);
        text-decoration: none;
        padding: 4px 6px;
        border-radius: 4px;
        white-space: nowrap;
        transition: all 0.15s ease;
      }
      
      .breadcrumb-item:hover:not(.active) {
        background: var(--bg-hover);
        color: #279A97;
      }
      
      .breadcrumb-item.active {
        color: #279A97;
        font-weight: 600;
      }
      
      .breadcrumb-sep {
        color: var(--text-tertiary);
        font-size: 14px;
      }
      
      .toolbar-right {
        display: flex;
        align-items: center;
      }
      
      .view-toggle {
        display: flex;
        background: var(--bg-tertiary);
        border-radius: 5px;
        padding: 2px;
      }
      
      .view-btn {
        width: 26px;
        height: 22px;
        display: flex;
        align-items: center;
        justify-content: center;
        border: none;
        background: transparent;
        color: var(--text-secondary);
        border-radius: 4px;
        cursor: pointer;
        transition: all 0.15s ease;
      }
      
      .view-btn.active {
        background: var(--bg-secondary);
        color: var(--text-primary);
        box-shadow: 0 1px 2px var(--shadow-color);
      }
      
      /* Column Headers */
      .column-headers {
        display: grid;
        grid-template-columns: 1fr 140px 80px 120px;
        gap: 8px;
        padding: 8px 16px;
        background: var(--toolbar-bg);
        border-bottom: 1px solid var(--border-color);
        font-size: 11px;
        font-weight: 500;
        color: var(--text-secondary);
        text-transform: uppercase;
        letter-spacing: 0.3px;
        flex-shrink: 0;
      }
      
      /* File List */
      .file-list {
        flex: 1;
        overflow-y: auto;
        background: var(--bg-secondary);
      }
      
      .file-row {
        display: grid;
        grid-template-columns: 1fr 140px 80px 120px;
        gap: 8px;
        padding: 8px 16px;
        text-decoration: none;
        color: var(--text-primary);
        border-bottom: 1px solid var(--border-light);
        transition: background 0.1s ease;
        align-items: center;
      }
      
      .file-row:hover {
        background: var(--bg-hover);
      }
      
      .file-row:active {
        background: var(--bg-selected);
        color: white;
      }
      
      .file-row:active .col-date,
      .file-row:active .col-size,
      .file-row:active .col-kind {
        color: rgba(255, 255, 255, 0.8);
      }
      
      .col-name {
        display: flex;
        align-items: center;
        gap: 10px;
        min-width: 0;
      }
      
      .file-name {
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        font-size: 13px;
      }
      
      .col-date, .col-size, .col-kind {
        font-size: 12px;
        color: var(--text-secondary);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      
      .col-size {
        text-align: right;
      }
      
      /* File Icons - Professional SVG-based design */
      .file-icon {
        width: 36px;
        height: 36px;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 8px;
        flex-shrink: 0;
        position: relative;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12), 0 1px 2px rgba(0, 0, 0, 0.08);
        transition: transform 0.15s ease, box-shadow 0.15s ease;
      }
      
      .file-icon:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15), 0 2px 4px rgba(0, 0, 0, 0.1);
      }
      
      .file-icon svg {
        width: 18px;
        height: 18px;
        fill: white;
        filter: drop-shadow(0 1px 1px rgba(0, 0, 0, 0.1));
      }
      
      /* Folder Icon - Premium macOS-style */
      .folder-icon-blue {
        background: linear-gradient(180deg, #4ECDC4 0%, #279A97 100%);
        position: relative;
        border-radius: 6px;
        overflow: hidden;
      }
      
      .folder-icon-blue::before {
        content: '';
        position: absolute;
        top: 8px;
        left: 4px;
        right: 4px;
        bottom: 4px;
        background: linear-gradient(180deg, rgba(255,255,255,0.2) 0%, rgba(255,255,255,0.05) 100%);
        border-radius: 3px;
        box-shadow: inset 0 -8px 12px rgba(0, 0, 0, 0.15);
      }
      
      .folder-icon-blue::after {
        content: '';
        position: absolute;
        top: 4px;
        left: 4px;
        width: 12px;
        height: 5px;
        background: linear-gradient(180deg, #5ED4CC 0%, #3BA69E 100%);
        border-radius: 3px 3px 0 0;
        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
      }
      
      /* Image Files - Vibrant Pink */
      .icon-image {
        background: linear-gradient(145deg, #FF6B9D 0%, #E84393 50%, #C44569 100%);
      }
      .icon-image::before {
        content: '';
        position: absolute;
        width: 16px;
        height: 12px;
        border: 2px solid white;
        border-radius: 2px;
        box-sizing: border-box;
      }
      .icon-image::after {
        content: '';
        position: absolute;
        width: 5px;
        height: 5px;
        background: white;
        border-radius: 50%;
        top: 10px;
        left: 10px;
      }
      
      /* Video Files - Rich Purple */
      .icon-video {
        background: linear-gradient(145deg, #A855F7 0%, #9333EA 50%, #7C3AED 100%);
      }
      .icon-video::before {
        content: '';
        position: absolute;
        width: 0;
        height: 0;
        border-left: 10px solid white;
        border-top: 6px solid transparent;
        border-bottom: 6px solid transparent;
        margin-left: 3px;
      }
      
      /* Audio Files - Warm Orange */
      .icon-audio {
        background: linear-gradient(145deg, #FB923C 0%, #F97316 50%, #EA580C 100%);
      }
      .icon-audio::before {
        content: '';
        position: absolute;
        width: 6px;
        height: 6px;
        background: white;
        border-radius: 50%;
        margin-top: 4px;
      }
      .icon-audio::after {
        content: '';
        position: absolute;
        width: 3px;
        height: 10px;
        background: white;
        border-radius: 0 0 2px 2px;
        margin-bottom: 6px;
        margin-left: 3px;
      }
      
      /* PDF Files - Professional Red */
      .icon-pdf {
        background: linear-gradient(145deg, #F87171 0%, #EF4444 50%, #DC2626 100%);
      }
      .icon-pdf::before {
        content: 'PDF';
        font-size: 8px;
        font-weight: 700;
        color: white;
        letter-spacing: -0.5px;
      }
      
      /* Document Files - Corporate Blue */
      .icon-doc {
        background: linear-gradient(145deg, #60A5FA 0%, #3B82F6 50%, #2563EB 100%);
      }
      .icon-doc::before {
        content: '';
        position: absolute;
        width: 12px;
        height: 14px;
        background: white;
        border-radius: 1px;
        clip-path: polygon(0 0, 70% 0, 100% 30%, 100% 100%, 0 100%);
      }
      .icon-doc::after {
        content: '';
        position: absolute;
        width: 6px;
        height: 1.5px;
        background: #3B82F6;
        box-shadow: 0 3px 0 #3B82F6, 0 6px 0 #3B82F6;
        margin-top: 3px;
        margin-right: 1px;
      }
      
      /* Spreadsheet Files - Fresh Green */
      .icon-spreadsheet {
        background: linear-gradient(145deg, #4ADE80 0%, #22C55E 50%, #16A34A 100%);
      }
      .icon-spreadsheet::before {
        content: '';
        position: absolute;
        width: 14px;
        height: 12px;
        border: 2px solid white;
        border-radius: 2px;
        box-sizing: border-box;
      }
      .icon-spreadsheet::after {
        content: '';
        position: absolute;
        width: 0.5px;
        height: 8px;
        background: white;
        box-shadow: 4px 0 0 white;
      }
      
      /* Presentation Files - Amber Gold */
      .icon-presentation {
        background: linear-gradient(145deg, #FBBF24 0%, #F59E0B 50%, #D97706 100%);
      }
      .icon-presentation::before {
        content: '';
        position: absolute;
        width: 16px;
        height: 10px;
        background: white;
        border-radius: 2px;
      }
      .icon-presentation::after {
        content: '';
        position: absolute;
        width: 4px;
        height: 4px;
        background: #F59E0B;
        margin-top: -1px;
        margin-left: -3px;
      }
      
      /* Text Files - Neutral Slate */
      .icon-text {
        background: linear-gradient(145deg, #94A3B8 0%, #64748B 50%, #475569 100%);
      }
      .icon-text::before {
        content: 'TXT';
        font-size: 7px;
        font-weight: 700;
        color: white;
        letter-spacing: -0.5px;
      }
      
      /* Archive Files - Deep Purple */
      .icon-archive {
        background: linear-gradient(145deg, #C084FC 0%, #A855F7 50%, #8B5CF6 100%);
      }
      .icon-archive::before {
        content: '';
        position: absolute;
        width: 12px;
        height: 14px;
        border: 2px solid white;
        border-radius: 2px;
        box-sizing: border-box;
      }
      .icon-archive::after {
        content: '';
        position: absolute;
        width: 6px;
        height: 2px;
        background: white;
        margin-top: -4px;
        border-radius: 1px;
      }
      
      /* Code Files - Teal Developer */
      .icon-code {
        background: linear-gradient(145deg, #2DD4BF 0%, #14B8A6 50%, #0D9488 100%);
      }
      .icon-code::before {
        content: '</>';
        font-size: 9px;
        font-weight: 700;
        color: white;
        font-family: 'SF Mono', 'Monaco', 'Consolas', monospace;
      }
      
      /* Application Files - Steel Gray */
      .icon-app {
        background: linear-gradient(145deg, #94A3B8 0%, #64748B 50%, #475569 100%);
      }
      .icon-app::before {
        content: '';
        position: absolute;
        width: 12px;
        height: 12px;
        border: 2px solid white;
        border-radius: 3px;
        box-sizing: border-box;
      }
      .icon-app::after {
        content: '';
        position: absolute;
        width: 4px;
        height: 4px;
        background: white;
        border-radius: 1px;
      }
      
      /* Generic Files - Subtle Gray */
      .icon-generic {
        background: linear-gradient(145deg, #D1D5DB 0%, #9CA3AF 50%, #6B7280 100%);
      }
      .icon-generic::before {
        content: '';
        position: absolute;
        width: 12px;
        height: 14px;
        background: white;
        border-radius: 1px;
        clip-path: polygon(0 0, 70% 0, 100% 30%, 100% 100%, 0 100%);
      }
      
      /* Status Bar */
      .status-bar {
        height: 24px;
        background: var(--toolbar-bg);
        border-top: 1px solid var(--border-color);
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 0 16px;
        font-size: 11px;
        color: var(--text-secondary);
        flex-shrink: 0;
      }
      
      .airfiles-badge {
        color: #279A97;
        font-weight: 500;
      }
      
      /* Error Message */
      .error-message {
        padding: 40px 20px;
        text-align: center;
        color: var(--text-secondary);
      }
      
      /* Scrollbar */
      .file-list::-webkit-scrollbar {
        width: 8px;
      }
      
      .file-list::-webkit-scrollbar-track {
        background: transparent;
      }
      
      .file-list::-webkit-scrollbar-thumb {
        background: rgba(78, 205, 196, 0.5);
        border-radius: 4px;
        border: 2px solid var(--bg-secondary);
      }
      
      .file-list::-webkit-scrollbar-thumb:hover {
        background: #4ECDC4;
      }
      
      /* Responsive */
      @media (max-width: 768px) {
        body {
          padding: 0;
        }
        
        .finder-window {
          border-radius: 0;
          max-height: 100vh;
          min-height: 100vh;
        }
        
        .column-headers {
          display: none;
        }
        
        .file-row {
          display: flex;
          gap: 12px;
        }
        
        .col-name {
          flex: 1;
        }
        
        .col-date, .col-kind {
          display: none;
        }
        
        .col-size {
          font-size: 11px;
        }
        
        .breadcrumbs {
          display: none;
        }
      }
      
      /* App Logo */
      .app-logo {
        display: flex;
        align-items: center;
        padding: 4px;
        border-radius: 6px;
        cursor: pointer;
        transition: all 0.2s ease;
      }
      
      .app-logo:hover {
        background: var(--bg-hover);
        transform: scale(1.05);
      }
      
      /* File row cursor */
      .file-row.file {
        cursor: pointer;
      }
      
      /* Preview Modal */
      .preview-modal {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.8);
        backdrop-filter: blur(10px);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
        opacity: 0;
        visibility: hidden;
        transition: all 0.3s ease;
      }
      
      .preview-modal.active {
        opacity: 1;
        visibility: visible;
      }
      
      .preview-content {
        background: var(--bg-secondary);
        border-radius: 12px;
        max-width: 90vw;
        max-height: 90vh;
        width: 800px;
        display: flex;
        flex-direction: column;
        box-shadow: 0 25px 80px rgba(0, 0, 0, 0.5);
        overflow: hidden;
        transform: scale(0.9);
        transition: transform 0.3s ease;
      }
      
      .preview-modal.active .preview-content {
        transform: scale(1);
      }
      
      .preview-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 16px 20px;
        background: linear-gradient(180deg, #4ECDC4 0%, #279A97 100%);
        color: white;
      }
      
      .preview-file-name {
        font-weight: 600;
        font-size: 14px;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        flex: 1;
        margin-right: 16px;
      }
      
      .preview-close {
        background: rgba(255, 255, 255, 0.2);
        border: none;
        color: white;
        width: 28px;
        height: 28px;
        border-radius: 50%;
        font-size: 20px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s ease;
      }
      
      .preview-close:hover {
        background: rgba(255, 255, 255, 0.3);
        transform: scale(1.1);
      }
      
      .preview-body {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 20px;
        min-height: 300px;
        background: var(--bg-tertiary);
        overflow: auto;
      }
      
      .preview-image {
        max-width: 100%;
        max-height: 60vh;
        border-radius: 8px;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
      }
      
      .preview-video {
        max-width: 100%;
        max-height: 60vh;
        border-radius: 8px;
      }
      
      .preview-pdf {
        width: 100%;
        height: 60vh;
        border: none;
        border-radius: 8px;
      }
      
      .audio-preview {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 20px;
        padding: 40px;
      }
      
      .audio-icon {
        font-size: 80px;
        animation: pulse 2s ease-in-out infinite;
      }
      
      @keyframes pulse {
        0%, 100% { transform: scale(1); }
        50% { transform: scale(1.1); }
      }
      
      .preview-unsupported {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 12px;
        color: var(--text-secondary);
        text-align: center;
        padding: 40px;
      }
      
      .unsupported-icon {
        font-size: 64px;
        opacity: 0.5;
      }
      
      .preview-unsupported .hint {
        font-size: 12px;
        color: var(--text-tertiary);
      }
      
      .preview-actions {
        display: flex;
        gap: 12px;
        padding: 16px 20px;
        background: var(--bg-secondary);
        border-top: 1px solid var(--border-color);
        justify-content: flex-end;
      }
      
      .preview-btn {
        padding: 8px 20px;
        border-radius: 6px;
        text-decoration: none;
        font-size: 13px;
        font-weight: 500;
        transition: all 0.2s ease;
      }
      
      .preview-btn.download {
        background: linear-gradient(180deg, #4ECDC4 0%, #279A97 100%);
        color: white;
      }
      
      .preview-btn.download:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(39, 154, 151, 0.4);
      }
      
      .preview-btn.open {
        background: var(--bg-tertiary);
        color: var(--text-primary);
        border: 1px solid var(--border-color);
      }
      
      .preview-btn.open:hover {
        background: var(--bg-hover);
        border-color: #279A97;
        color: #279A97;
      }
      
      @media (max-width: 768px) {
        .preview-content {
          width: 100%;
          max-width: 100%;
          max-height: 100%;
          border-radius: 0;
        }
        
        .preview-body {
          min-height: 200px;
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