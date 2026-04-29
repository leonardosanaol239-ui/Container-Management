# Backend Connection Fix

## Current Error
"Connection timeout. Please check if the server is running."

## Your Setup
- Backend: Running on same computer
- Frontend: Flutter Web (Chrome)
- Current Config: `http://127.0.0.1:5000/api`

## Steps to Fix

### 1. Verify Backend is Running

Open a new terminal and check if your backend is running:

```bash
# Check if something is running on port 5000
netstat -ano | findstr :5000
```

If nothing shows up, **start your backend server**.

### 2. Test Backend Directly

Open your browser and go to:
```
http://127.0.0.1:5000/api
```

**Expected**: You should see some response (JSON, HTML, or error message)
**Problem**: If you see "Can't reach this page" → Backend is NOT running

### 3. Check Backend Port

Your backend might be running on a different port. Common ports:
- 5000 (default)
- 5001
- 3000
- 8080

If your backend is on a different port, update `lib/config/api_config.dart`:

```dart
static const String localhostUrl = 'http://127.0.0.1:YOUR_PORT/api';
```

### 4. Configure CORS (Required for Flutter Web)

Since you're running Flutter Web, your backend MUST allow CORS.

#### For ASP.NET Core:

Add to `Program.cs`:

```csharp
// Add CORS before building the app
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Use CORS (MUST be before UseAuthorization)
app.UseCors("AllowAll");
app.UseAuthorization();
```

Then **restart your backend**.

#### For Node.js/Express:

```bash
npm install cors
```

```javascript
const cors = require('cors');
app.use(cors());
```

#### For Python/Flask:

```bash
pip install flask-cors
```

```python
from flask_cors import CORS
app = Flask(__name__)
CORS(app)
```

### 5. Alternative: Run as Desktop App

If you can't configure CORS, run Flutter as a Windows desktop app instead:

```bash
# Stop the web app (Ctrl+C in terminal)
# Then run as desktop
flutter run -d windows
```

Desktop apps don't have CORS restrictions.

### 6. Hot Restart Flutter App

After making changes, hot reload won't work. You need to:

1. Stop the app (Ctrl+C in terminal)
2. Run again: `flutter run -d chrome` or `flutter run -d windows`

## Quick Checklist

- [ ] Backend server is running
- [ ] Backend is on port 5000 (or update config)
- [ ] Can access `http://127.0.0.1:5000/api` in browser
- [ ] CORS is configured on backend
- [ ] Flutter app was restarted (not just hot reloaded)

## Still Not Working?

### Check Backend Logs

When you click LOGIN, check your backend console. You should see:
- Incoming request to `/api/Auth/login`
- Request details

If you see nothing → Request is not reaching backend (CORS or network issue)

### Check Browser Console

1. Open Chrome DevTools (F12)
2. Go to Console tab
3. Look for errors mentioning "CORS" or "blocked"

If you see CORS errors → Configure CORS on backend

### Try Different URL Formats

Update `lib/config/api_config.dart` and try:

```dart
// Try localhost instead of 127.0.0.1
static const String localhostUrl = 'http://localhost:5000/api';

// Or try your machine's IP
static const String localhostUrl = 'http://192.168.x.x:5000/api';
```

Remember to restart the app after changes!
