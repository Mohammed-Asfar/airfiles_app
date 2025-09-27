import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/services/file_server_service.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/services/file_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/models/server_config.dart';
import '../../../../core/models/file_item.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/airfiles_logo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final FileServerService _serverService = FileServerService();
  final NetworkService _networkService = NetworkService();
  final FileService _fileService = FileService();
  final PermissionService _permissionService = PermissionService();

  ServerState _serverState = const ServerState(status: ServerStatus.stopped);
  List<FileItem> _selectedFiles = [];
  String? _localIP;
  String? _wifiName;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadNetworkInfo();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _serverService.stopServer();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadNetworkInfo() async {
    setState(() => _isLoading = true);

    try {
      final networkInfo = await _networkService.getNetworkInfo();
      setState(() {
        _localIP = networkInfo.localIP;
        _wifiName = networkInfo.wifiName;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get network info: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectFiles() async {
    try {
      setState(() => _isLoading = true);

      // Check storage permissions first
      final hasStoragePermission =
          await _permissionService.requestStoragePermissions(
        context: context,
        showRationale: true,
      );

      if (!hasStoragePermission) {
        setState(() {
          _errorMessage = 'Storage permission is required to select files';
        });
        return;
      }

      final selectedPaths = await _fileService.pickFiles();
      if (selectedPaths.isNotEmpty) {
        final fileItems = await _fileService.getFileItems(selectedPaths);
        setState(() {
          _selectedFiles.addAll(fileItems); // Add to existing files instead of replacing
          _errorMessage = null;
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${fileItems.length} file(s)'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      final errorMessage = e.toString();
      print('File selection error: $errorMessage');
      
      setState(() {
        // Provide more helpful error messages for common Android issues
        if (errorMessage.contains('scoped storage') || 
            errorMessage.contains('unknown_path') ||
            errorMessage.contains('failed to retrieve path')) {
          _errorMessage = 'Android Storage Restriction: $errorMessage\n\n'
              'Try these solutions:\n'
              '• Select files from Downloads folder\n'
              '• Use Documents or Pictures folders\n'
              '• Avoid "Recent files" or cloud storage\n'
              '• Copy files to Downloads first if needed';
        } else if (errorMessage.contains('permission')) {
          _errorMessage = 'Permission Error: Please grant storage access in Settings > Apps > AirFiles > Permissions';
        } else {
          _errorMessage = 'File Selection Error: $errorMessage';
        }
      });
      
      // Show detailed error dialog for scoped storage issues
      if (mounted && (errorMessage.contains('scoped storage') || 
          errorMessage.contains('unknown_path') ||
          errorMessage.contains('failed to retrieve path'))) {
        _showScopedStorageHelpDialog();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startServer() async {
    if (_localIP == null) {
      setState(() => _errorMessage = 'No network connection found');
      return;
    }

    if (_selectedFiles.isEmpty) {
      setState(() => _errorMessage = 'Please select files to share first');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _serverState = _serverState.copyWith(status: ServerStatus.starting);
      });

      // Check network permissions for location-based WiFi info
      await _permissionService.requestNetworkPermissions(
        context: context,
        showRationale: false, // Don't show rationale for optional permission
      );

      // Request notification permission for server status updates
      await _permissionService.requestNotificationPermission(
        context: context,
        showRationale: false, // Don't show rationale for optional permission
      );

      final port = await _networkService.findAvailablePort();
      final sharedPaths = _selectedFiles.map((f) => f.path).toList();

      final config = await _serverService.startServer(
        address: _localIP!,
        port: port,
        sharedPaths: sharedPaths,
      );

      setState(() {
        _serverState = ServerState(
          status: ServerStatus.running,
          config: config,
          sharedPaths: sharedPaths,
        );
        _errorMessage = null;
      });

      _pulseController.repeat(reverse: true);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server started at ${config.serverUrl}'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Copy',
              textColor: Colors.white,
              onPressed: _copyUrl,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _serverState = ServerState(
          status: ServerStatus.error,
          errorMessage: e.toString(),
        );
        _errorMessage = 'Failed to start server: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _stopServer() async {
    try {
      setState(() {
        _isLoading = true;
        _serverState = _serverState.copyWith(status: ServerStatus.stopping);
      });

      await _serverService.stopServer();

      setState(() {
        _serverState = const ServerState(status: ServerStatus.stopped);
        _errorMessage = null;
      });

      _pulseController.stop();
      _pulseController.reset();
    } catch (e) {
      setState(() {
        _serverState = ServerState(
          status: ServerStatus.error,
          errorMessage: e.toString(),
        );
        _errorMessage = 'Failed to stop server: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _shareUrl() {
    if (_serverState.config?.serverUrl != null) {
      Share.share(
        'Access my shared files at: ${_serverState.config!.serverUrl}\n\nShared via AirFiles 🌬️',
        subject: 'AirFiles - Shared Files',
      );
    }
  }

  void _copyUrl() {
    if (_serverState.config?.serverUrl != null) {
      Clipboard.setData(ClipboardData(text: _serverState.config!.serverUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isDarkMode ? AppTheme.darkGradient : AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildPermissionStatus(),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color:
                              isDarkMode ? AppColors.darkAccent : Colors.white,
                        ),
                      )
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Use the custom AirFiles logo widget
              AirFilesLogo(
                size: 48,
                showText: true,
                textColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share files instantly on your local network',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.95),
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (_wifiName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.spiralTealLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi,
                    color: Colors.white,
                    size: 16,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _wifiName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionStatus() {
    return FutureBuilder<bool>(
      future: _permissionService.hasAllRequiredPermissions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final hasAllPermissions = snapshot.data ?? false;
        if (hasAllPermissions) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Some permissions are missing. Tap to review.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  _permissionService.showPermissionSettings(
                    context: context,
                    title: 'Missing Permissions',
                    message:
                        'Please grant the required permissions in settings to use all features.',
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'Review',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildServerStatus(),
          if (_errorMessage != null) _buildErrorMessage(),
          Expanded(
            child:
                _selectedFiles.isEmpty ? _buildEmptyState() : _buildFileList(),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildServerStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _serverState.isRunning ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.getServerStatusColor(
                      _serverState.status.name,
                    ).withOpacity(0.2),
                    border: Border.all(
                      color: AppTheme.getServerStatusColor(
                        _serverState.status.name,
                      ),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    _getServerStatusIcon(),
                    size: 32,
                    color: AppTheme.getServerStatusColor(
                      _serverState.status.name,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _getServerStatusText(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getServerStatusColor(
                    _serverState.status.name,
                  ),
                ),
          ),
          if (_serverState.config != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _serverState.config!.serverUrl,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  onPressed: _copyUrl,
                  icon: Icons.copy,
                  label: 'Copy',
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  onPressed: _shareUrl,
                  icon: Icons.share,
                  label: 'Share',
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  onPressed: () => _showQRCode(context),
                  icon: Icons.qr_code,
                  label: 'QR Code',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  IconData _getServerStatusIcon() {
    switch (_serverState.status) {
      case ServerStatus.running:
        return Icons.cloud_done;
      case ServerStatus.starting:
      case ServerStatus.stopping:
        return Icons.sync;
      case ServerStatus.error:
        return Icons.error;
      case ServerStatus.stopped:
      default:
        return Icons.cloud_off;
    }
  }

  String _getServerStatusText() {
    switch (_serverState.status) {
      case ServerStatus.running:
        return 'Server Running';
      case ServerStatus.starting:
        return 'Starting Server...';
      case ServerStatus.stopping:
        return 'Stopping Server...';
      case ServerStatus.error:
        return 'Server Error';
      case ServerStatus.stopped:
      default:
        return 'Server Stopped';
    }
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AirFilesLogo(
            size: 80,
            showBackground: true,
          ),
          const SizedBox(height: 24),
          Text(
            'No files selected',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select files to start sharing them\nover your local network',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Selected Files (${_selectedFiles.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              return _buildFileItem(file, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileItem(FileItem file, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.getFileTypeColor(file.extension),
          child: Text(
            file.type == FileItemType.directory
                ? '📁'
                : _getFileIcon(file.extension),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_fileService.getFileCategory(file)} • ${file.sizeFormatted}',
        ),
        trailing: IconButton(
          onPressed: () => _removeFile(index),
          icon: const Icon(Icons.close),
          iconSize: 20,
        ),
      ),
    );
  }

  String _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return '🖼️';
      case 'mp4':
      case 'avi':
      case 'mov':
        return '🎬';
      case 'mp3':
      case 'wav':
        return '🎵';
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      default:
        return '📄';
    }
  }

  /// Show help dialog for Android scoped storage issues
  void _showScopedStorageHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryColor),
              SizedBox(width: 8),
              Text('Android File Access Help'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Android 10+ restricts file access for security. Here\'s how to select files successfully:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('✅ RECOMMENDED LOCATIONS:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                const SizedBox(height: 8),
                const Text('• Downloads folder - Best compatibility'),
                const Text('• Documents folder - Good for documents'),
                const Text('• Pictures/DCIM - Good for photos'),
                const Text('• Movies - Good for videos'),
                const Text('• Music - Good for audio files'),
                const SizedBox(height: 16),
                const Text('❌ AVOID THESE:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                const SizedBox(height: 8),
                const Text('• "Recent files" section'),
                const Text('• Google Drive or cloud storage'),
                const Text('• Third-party app folders'),
                const Text('• System directories'),
                const SizedBox(height: 16),
                const Text('💡 QUICK SOLUTION:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                const SizedBox(height: 8),
                const Text('1. Open your file manager'),
                const Text('2. Navigate to Downloads folder'),
                const Text('3. Copy your files there if needed'),
                const Text('4. Select files directly from Downloads'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _selectFiles(); // Try again
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (!_serverState.isRunning) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedFiles.isNotEmpty ? _startServer : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Sharing'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectFiles,
                    icon: const Icon(Icons.add),
                    label: Text(
                        _selectedFiles.isEmpty ? 'Select Files' : 'Add More Files'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _showScopedStorageHelpDialog,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  child: const Icon(Icons.help_outline, size: 20),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _stopServer,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Sharing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showQRCode(BuildContext context) {
    if (_serverState.config?.serverUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            AirFilesLogo(
              size: 24,
              showBackground: false,
            ),
            const SizedBox(width: 8),
            const Text('Share QR Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: QrImageView(
                data: _serverState.config!.serverUrl,
                version: QrVersions.auto,
                size: 180.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan to access files',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              _shareUrl();
              Navigator.of(context).pop();
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }
}
