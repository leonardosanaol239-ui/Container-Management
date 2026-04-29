# Network Setup Guide

## Understanding the Connection Issue

Your Flutter app needs to connect to the backend server. They **must be on the same network** or have a way to communicate.

## Current Situation

- **Backend Server**: Running on Gothong network at `192.168.118.161:5000`
- **Your Device**: Connected to a different WiFi (open network)
- **Result**: ❌ Cannot connect (different networks)

## Solutions

### ✅ Solution 1: Connect to Gothong WiFi (Easiest)

1. Connect your device to the **same WiFi network** as the backend server
2. Use this configuration in `lib/config/api_config.dart`:
   ```dart
   static String get baseUrl => gothongNetworkUrl;
   ```
3. Restart the app

### ✅ Solution 2: Run Backend on Same Machine (Development)

If the backend is running on the **same computer** as your Flutter app:

1. Keep your current WiFi connection
2. Use this configuration in `lib/config/api_config.dart`:
   ```dart
   static String get baseUrl => localhostUrl;
   ```
3. Restart the app

**Note**: This is the **current configuration** I've set for you.

### ✅ Solution 3: Use VPN (Sophos)

If Sophos provides VPN access to Gothong network:

1. Connect to Sophos VPN
2. Verify you can access `http://192.168.118.161:5000` in browser
3. Use this configuration:
   ```dart
   static String get baseUrl => gothongNetworkUrl;
   ```
4. Restart the app

### ✅ Solution 4: Expose Backend Publicly (Production)

Make the backend accessible from anywhere:

1. **Configure Router Port Forwarding**:
   - Forward external port (e.g., 8080) to internal 192.168.118.161:5000
   - Get your public IP address

2. **Update API Config**:
   ```dart
   static const String publicUrl = 'http://YOUR_PUBLIC_IP:8080/api';
   static String get baseUrl => publicUrl;
   ```

3. **Security Considerations**:
   - Use HTTPS (SSL certificate)
   - Implement authentication
   - Configure firewall rules
   - Use strong passwords

### ✅ Solution 5: Use Cloud Hosting

Deploy backend to cloud service:
- Azure App Service
- AWS EC2
- Google Cloud
- Heroku

Then update:
```dart
static const String cloudUrl = 'https://your-app.azurewebsites.net/api';
static String get baseUrl => cloudUrl;
```

## Quick Configuration Reference

Edit `lib/config/api_config.dart` and change the `baseUrl` getter:

```dart
// For localhost (backend on same machine)
static String get baseUrl => localhostUrl;

// For Gothong internal network (when connected to Gothong WiFi)
static String get baseUrl => gothongNetworkUrl;

// For custom setup
static const String customUrl = 'http://YOUR_IP:PORT/api';
static String get baseUrl => customUrl;
```

## Testing Your Setup

1. Click **"TEST CONNECTION"** button on login screen
2. Check the error message
3. Verify the URL being used
4. Follow the suggestions provided

## Common Scenarios

### Scenario 1: Development on Same Machine
- **Backend**: Running on your laptop
- **Flutter App**: Running on same laptop
- **Configuration**: `localhostUrl` ✅ (Current)

### Scenario 2: Testing on Gothong Network
- **Backend**: On Gothong server (192.168.118.161)
- **Flutter App**: On device connected to Gothong WiFi
- **Configuration**: `gothongNetworkUrl`

### Scenario 3: Remote Access
- **Backend**: On Gothong server
- **Flutter App**: On device anywhere (different WiFi)
- **Configuration**: Need VPN or public IP

## Troubleshooting

### "Connection timeout" Error
- ✅ Check: Are you on the same network as backend?
- ✅ Check: Is backend running?
- ✅ Check: Is the IP address correct?

### "Cannot reach server" Error
- ✅ Check: Network connectivity
- ✅ Try: Ping the server IP
- ✅ Verify: Firewall settings

### Still Not Working?
1. Open browser on your device
2. Navigate to: `http://192.168.118.161:5000/api` (or your backend URL)
3. If browser can't reach it, Flutter app won't either
4. This confirms it's a network issue, not an app issue

## Current Configuration

I've set the app to use **localhost** (`http://localhost:5000/api`).

**This works if**:
- Backend is running on the same machine as Flutter app
- You're developing/testing locally

**Change to `gothongNetworkUrl` if**:
- Backend is on a different machine
- You're connected to Gothong WiFi
- You need to access the actual server
