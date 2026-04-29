class ApiConfig {
  // API base URL for backend on same machine
  static const String localhostUrl = 'http://localhost:5000/api';

  // Alternative localhost (try if above doesn't work)
  static const String localhost127 = 'http://127.0.0.1:5000/api';

  // For Gothong internal network (only works when connected to Gothong WiFi)
  static const String gothongNetworkUrl = 'http://192.168.118.161:5000/api';

  // Current active base URL
  // IMPORTANT: Change this if your backend is on a different port
  static String get baseUrl => localhostUrl;

  // Connection timeout in seconds
  static const int connectionTimeout = 15;

  // Retry configuration
  static const int maxRetries = 2;
  static const int retryDelaySeconds = 2;
}
