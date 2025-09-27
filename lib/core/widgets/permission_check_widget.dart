import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';
import '../theme/app_colors.dart';
import 'airfiles_logo.dart';

class PermissionCheckWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPermissionsGranted;
  final bool checkOnInit;

  const PermissionCheckWidget({
    super.key,
    required this.child,
    this.onPermissionsGranted,
    this.checkOnInit = true,
  });

  @override
  State<PermissionCheckWidget> createState() => _PermissionCheckWidgetState();
}

class _PermissionCheckWidgetState extends State<PermissionCheckWidget> {
  final PermissionService _permissionService = PermissionService();
  bool _hasAllPermissions = false;
  bool _isChecking = false;
  bool _isRequesting = false;
  Map<PermissionType, bool> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    if (widget.checkOnInit) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isChecking = true);

    try {
      // Check individual permissions
      final storageGranted = await _checkStoragePermissions();
      final locationGranted = await _permissionService
          .checkPermission(PermissionType.location)
          .then((status) => status == PermissionStatus.granted);
      final cameraGranted = await _permissionService
          .checkPermission(PermissionType.camera)
          .then((status) => status == PermissionStatus.granted);
      final microphoneGranted = await _permissionService
          .checkPermission(PermissionType.microphone)
          .then((status) => status == PermissionStatus.granted);
      final notificationGranted = await _permissionService
          .checkPermission(PermissionType.notification)
          .then((status) => status == PermissionStatus.granted);

      setState(() {
        _permissionStatuses = {
          PermissionType.storage: storageGranted,
          PermissionType.location: locationGranted,
          PermissionType.camera: cameraGranted,
          PermissionType.microphone: microphoneGranted,
          PermissionType.notification: notificationGranted,
        };

        // Check if critical permissions are granted
        _hasAllPermissions = storageGranted; // Storage is the only critical permission
      });

      if (_hasAllPermissions && widget.onPermissionsGranted != null) {
        widget.onPermissionsGranted!();
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Future<bool> _checkStoragePermissions() async {
    final photosStatus = await _permissionService.checkPermission(PermissionType.photos);
    final videosStatus = await _permissionService.checkPermission(PermissionType.videos);
    final audioStatus = await _permissionService.checkPermission(PermissionType.audio);
    final storageStatus = await _permissionService.checkPermission(PermissionType.storage);

    // On Android 13+, we need at least one media permission
    // On older Android, we need storage permission
    return photosStatus == PermissionStatus.granted || 
           videosStatus == PermissionStatus.granted || 
           audioStatus == PermissionStatus.granted || 
           storageStatus == PermissionStatus.granted;
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isRequesting = true);

    try {
      // Request storage permissions first (critical)
      final storageGranted = await _permissionService.requestStoragePermissions(
        context: context,
        showRationale: true,
      );

      if (storageGranted) {
        // Request other permissions
        await _permissionService.requestNetworkPermissions(
          context: context,
          showRationale: true,
        );

        await _permissionService.requestMediaPermissions(
          context: context,
          showRationale: true,
        );

        await _permissionService.requestNotificationPermission(
          context: context,
          showRationale: true,
        );
      }

      // Recheck permissions
      await _checkPermissions();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permissions: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isRequesting = false);
    }
  }

  Future<void> _requestSpecificPermission(PermissionType type) async {
    try {
      late bool granted;
      
      switch (type) {
        case PermissionType.storage:
        case PermissionType.photos:
        case PermissionType.videos:
        case PermissionType.audio:
          granted = await _permissionService.requestStoragePermissions(
            context: context,
            showRationale: true,
          );
          break;
        case PermissionType.location:
          granted = await _permissionService.requestNetworkPermissions(
            context: context,
            showRationale: true,
          );
          break;
        case PermissionType.camera:
        case PermissionType.microphone:
          granted = await _permissionService.requestMediaPermissions(
            context: context,
            showRationale: true,
          );
          break;
        case PermissionType.notification:
          granted = await _permissionService.requestNotificationPermission(
            context: context,
            showRationale: true,
          );
          break;
        case PermissionType.manageExternalStorage:
          final status = await _permissionService.requestPermission(type);
          granted = status == PermissionStatus.granted;
          break;
      }

      if (granted) {
        await _checkPermissions();
      }
    } catch (e) {
      debugPrint('Error requesting $type permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Checking permissions...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_hasAllPermissions) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _buildPermissionsList(),
                  ),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 32),
        AirFilesLogo(
          size: 80,
          showBackground: true,
        ),
        const SizedBox(height: 24),
        Text(
          'AirFiles Permissions',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'AirFiles needs certain permissions to share your files securely over the local network.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withOpacity(0.9),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPermissionsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPermissionTile(
            icon: Icons.folder,
            title: 'File Access',
            description: 'Required to select and share files from your device',
            type: PermissionType.storage,
            isRequired: true,
          ),
          _buildPermissionTile(
            icon: Icons.wifi,
            title: 'Network Access',
            description: 'Required to determine your WiFi network for secure local sharing',
            type: PermissionType.location,
            isRequired: false,
          ),
          _buildPermissionTile(
            icon: Icons.camera_alt,
            title: 'Camera',
            description: 'Optional: Share photos and videos from camera',
            type: PermissionType.camera,
            isRequired: false,
          ),
          _buildPermissionTile(
            icon: Icons.mic,
            title: 'Microphone',
            description: 'Optional: Share audio recordings',
            type: PermissionType.microphone,
            isRequired: false,
          ),
          _buildPermissionTile(
            icon: Icons.notifications,
            title: 'Notifications',
            description: 'Optional: Get notified about server status and file transfers',
            type: PermissionType.notification,
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required PermissionType type,
    required bool isRequired,
  }) {
    final isGranted = _permissionStatuses[type] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted ? AppColors.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? AppColors.success : (isRequired ? AppColors.error : Colors.grey),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGranted ? AppColors.success : (isRequired ? AppColors.error : Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'REQUIRED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isGranted)
            const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 24,
            )
          else
            TextButton(
              onPressed: () => _requestSpecificPermission(type),
              child: const Text('Grant'),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isRequesting ? null : _requestAllPermissions,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isRequesting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Grant All Permissions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            _permissionService.showPermissionSettings(
              context: context,
              title: 'Permission Settings',
              message: 'You can manually enable permissions in the app settings.',
            );
          },
          child: const Text(
            'Open App Settings',
            style: TextStyle(
              color: Colors.white,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}