# API Configuration Guide

## Backend Server Setup

The application requires a backend server to be running for authentication and data management.

### Current Configuration

The API base URL is configured in `lib/config/api_config.dart`:

```dart
static const String defaultBaseUrl = 'http://192.168.118.161:5000/api';
```

### Troubleshooting Connection Issues

If you see errors like "Server is not responding" or "Connection timeout":

1. **Verify the backend server is running**
   - Check if the server is started at `http://192.168.118.161:5000`
   - Ensure the API endpoints are accessible

2. **Check network connectivity**
   - Ensure your device can reach the server IP address
   - Try pinging: `ping 192.168.118.161`
   - Check firewall settings

3. **Update the API URL**
   - Open `lib/config/api_config.dart`
   - Change `defaultBaseUrl` to match your server address
   - Available presets:
     - `localhostUrl` - for local development
     - `localNetworkUrl` - for local network testing

### Configuration Options

You can adjust these settings in `lib/config/api_config.dart`:

- **connectionTimeout**: Request timeout in seconds (default: 10)
- **maxRetries**: Number of retry attempts (default: 2)
- **retryDelaySeconds**: Delay between retries (default: 2)

### Example Configurations

**For localhost development:**
```dart
static String get baseUrl => localhostUrl;
```

**For custom IP:**
```dart
static const String customUrl = 'http://YOUR_IP:5000/api';
static String get baseUrl => customUrl;
```

### Error Messages

The app now provides detailed error messages:

- **"Connection timeout"** - Server took too long to respond
- **"Cannot reach server"** - Network connectivity issue
- **"Server is not responding"** - Backend is not running or unreachable
- **"Login failed"** - Invalid credentials or authentication error
