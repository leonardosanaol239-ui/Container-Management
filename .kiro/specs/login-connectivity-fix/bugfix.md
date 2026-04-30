# Bugfix Requirements Document

## Introduction

The Flutter container management application fails to connect to the backend API during login when the user is connected to an open WiFi network instead of the Gothong internal network (192.168.118.161). The backend is running on the same machine as the Flutter app (localhost), and the database is properly connected. This bug prevents users from logging in when they are not on the Gothong network, even though the backend is accessible via localhost.

The root cause appears to be related to network connectivity issues when using localhost URLs on certain WiFi networks, potentially due to firewall rules, network isolation, or DNS resolution problems. The Sophos connection being active may also be interfering with localhost connectivity.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the user is connected to an open WiFi network (not Gothong network at 192.168.118.161) AND attempts to log in with valid credentials THEN the system fails to connect to the backend API and displays a connection error

1.2 WHEN the backend is running on localhost:5000 AND the user attempts to log in from an open WiFi network THEN the system cannot establish a connection despite the backend being accessible on the same machine

1.3 WHEN network conditions prevent localhost resolution (due to firewall, VPN, or network isolation) THEN the system does not attempt alternative localhost addresses (127.0.0.1) or provide helpful troubleshooting guidance

### Expected Behavior (Correct)

2.1 WHEN the user is connected to any WiFi network AND the backend is running on localhost THEN the system SHALL successfully connect to the backend API using localhost or 127.0.0.1

2.2 WHEN the initial localhost connection attempt fails THEN the system SHALL automatically retry with alternative localhost addresses (e.g., try 127.0.0.1 if localhost fails, or vice versa)

2.3 WHEN all localhost connection attempts fail THEN the system SHALL provide clear error messages indicating the backend is unreachable and suggest troubleshooting steps (verify backend is running, check firewall settings, disable VPN if active)

2.4 WHEN the user needs to switch between localhost and network-specific URLs (like Gothong network) THEN the system SHALL provide a mechanism to easily configure the API base URL without code changes

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the user is connected to the Gothong network (192.168.118.161) AND the API is configured to use the Gothong network URL THEN the system SHALL CONTINUE TO connect successfully to the backend

3.2 WHEN valid credentials are provided AND the backend is reachable THEN the system SHALL CONTINUE TO authenticate users and navigate to the appropriate dashboard based on user role

3.3 WHEN invalid credentials are provided THEN the system SHALL CONTINUE TO display appropriate authentication error messages

3.4 WHEN the backend returns error responses (401, 400, etc.) THEN the system SHALL CONTINUE TO parse and display user-friendly error messages
