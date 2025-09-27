class ServerConfig {
  final String address;
  final int port;
  final bool passwordProtected;
  final String? password;
  final bool isRunning;

  const ServerConfig({
    required this.address,
    required this.port,
    this.passwordProtected = false,
    this.password,
    this.isRunning = false,
  });

  String get serverUrl => 'http://$address:$port';

  ServerConfig copyWith({
    String? address,
    int? port,
    bool? passwordProtected,
    String? password,
    bool? isRunning,
  }) {
    return ServerConfig(
      address: address ?? this.address,
      port: port ?? this.port,
      passwordProtected: passwordProtected ?? this.passwordProtected,
      password: password ?? this.password,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig &&
          runtimeType == other.runtimeType &&
          address == other.address &&
          port == other.port &&
          passwordProtected == other.passwordProtected &&
          password == other.password &&
          isRunning == other.isRunning;

  @override
  int get hashCode =>
      address.hashCode ^
      port.hashCode ^
      passwordProtected.hashCode ^
      password.hashCode ^
      isRunning.hashCode;

  @override
  String toString() {
    return 'ServerConfig{address: $address, port: $port, passwordProtected: $passwordProtected, isRunning: $isRunning}';
  }
}

enum ServerStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

class ServerState {
  final ServerStatus status;
  final ServerConfig? config;
  final String? errorMessage;
  final List<String> sharedPaths;

  const ServerState({
    required this.status,
    this.config,
    this.errorMessage,
    this.sharedPaths = const [],
  });

  ServerState copyWith({
    ServerStatus? status,
    ServerConfig? config,
    String? errorMessage,
    List<String>? sharedPaths,
  }) {
    return ServerState(
      status: status ?? this.status,
      config: config ?? this.config,
      errorMessage: errorMessage ?? this.errorMessage,
      sharedPaths: sharedPaths ?? this.sharedPaths,
    );
  }

  bool get isRunning => status == ServerStatus.running;
  bool get isStopped => status == ServerStatus.stopped;
  bool get isLoading => status == ServerStatus.starting || status == ServerStatus.stopping;
  bool get hasError => status == ServerStatus.error;

  @override
  String toString() {
    return 'ServerState{status: $status, config: $config, errorMessage: $errorMessage, sharedPaths: ${sharedPaths.length} paths}';
  }
}