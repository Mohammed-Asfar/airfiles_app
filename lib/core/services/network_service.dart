import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkService {
  /// Get the local IP address of the device
  Future<String?> getLocalIpAddress() async {
    try {
      // Try to get WiFi IP first
      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty && wifiIP != '127.0.0.1') {
        return wifiIP;
      }

      // Fallback to network interfaces
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          // Skip loopback addresses
          if (address.isLoopback) continue;
          
          // Prefer common local network ranges
          final ip = address.address;
          if (_isLocalNetworkAddress(ip)) {
            return ip;
          }
        }
      }

      // If no preferred address found, return the first non-loopback
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) {
            return address.address;
          }
        }
      }

      return null;
    } catch (e) {
      print('Error getting local IP address: $e');
      return null;
    }
  }

  /// Get WiFi network name (SSID)
  Future<String?> getWifiName() async {
    try {
      return await NetworkInfo().getWifiName();
    } catch (e) {
      print('Error getting WiFi name: $e');
      return null;
    }
  }

  /// Get WiFi BSSID
  Future<String?> getWifiBSSID() async {
    try {
      return await NetworkInfo().getWifiBSSID();
    } catch (e) {
      print('Error getting WiFi BSSID: $e');
      return null;
    }
  }

  /// Check if device is connected to WiFi
  Future<bool> isConnectedToWifi() async {
    try {
      final wifiName = await getWifiName();
      final wifiIP = await NetworkInfo().getWifiIP();
      
      return wifiName != null && 
             wifiName.isNotEmpty && 
             wifiIP != null && 
             wifiIP.isNotEmpty &&
             wifiIP != '127.0.0.1';
    } catch (e) {
      print('Error checking WiFi connection: $e');
      return false;
    }
  }

  /// Find an available port for the server
  Future<int> findAvailablePort({int startPort = 8080}) async {
    for (int port = startPort; port <= startPort + 100; port++) {
      if (await _isPortAvailable(port)) {
        return port;
      }
    }
    throw Exception('No available port found in range ${startPort}-${startPort + 100}');
  }

  /// Check if a specific port is available
  Future<bool> _isPortAvailable(int port) async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if an IP address is in a local network range
  bool _isLocalNetworkAddress(String ip) {
    // Common local network ranges:
    // 192.168.x.x
    // 10.x.x.x
    // 172.16-31.x.x
    
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    try {
      final a = int.parse(parts[0]);
      final b = int.parse(parts[1]);

      // 192.168.x.x
      if (a == 192 && b == 168) return true;
      
      // 10.x.x.x
      if (a == 10) return true;
      
      // 172.16-31.x.x
      if (a == 172 && b >= 16 && b <= 31) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get network information summary
  Future<NetworkDetails> getNetworkInfo() async {
    final localIP = await getLocalIpAddress();
    final wifiName = await getWifiName();
    final isWifiConnected = await isConnectedToWifi();
    
    return NetworkDetails._(
      localIP: localIP,
      wifiName: wifiName,
      isWifiConnected: isWifiConnected,
    );
  }

  /// Validate if an IP address format is correct
  bool isValidIpAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    try {
      for (final part in parts) {
        final num = int.parse(part);
        if (num < 0 || num > 255) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if a port number is valid
  bool isValidPort(int port) {
    return port > 0 && port <= 65535;
  }
}

class NetworkDetails {
  final String? localIP;
  final String? wifiName;
  final bool isWifiConnected;

  const NetworkDetails._({
    this.localIP,
    this.wifiName,
    this.isWifiConnected = false,
  });

  bool get hasValidIP => localIP != null && localIP!.isNotEmpty;

  @override
  String toString() {
    return 'NetworkDetails{localIP: $localIP, wifiName: $wifiName, isWifiConnected: $isWifiConnected}';
  }
}