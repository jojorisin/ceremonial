# Secure Chat – Proof of Concept

A Flutter proof-of-concept secure chat app with camera-based key generation. **This phase implements the core key generation flow.**

## Key Generation Flow (Implemented)

1. **Camera capture** – User captures a shared visual (poster, object, etc.) visible to both devices in the same room  
2. **RAM-only processing** – Image bytes are read into memory; temp file is deleted immediately (camera plugin uses a brief temp cache)  
3. **SHA-3-256 hash** – Image is hashed with SHA-3 (FIPS-202)  
4. **PBKDF2 derivation** – Hash is fed into PBKDF2 to produce a 256-bit AES key  
5. **Secure storage** – Key is stored in:
   - **iOS**: Keychain (hardware-backed when available)
   - **Android**: Encrypted Shared Preferences with Tink (Keystore-backed)

No keys or images ever touch a server.

## Prerequisites

- Flutter SDK 3.5+
- iOS 12+ / Android 6.0+ (API 23+)

## Setup & Run

```bash
cd secure_chat_app
flutter pub get
flutter run
```

If the project was scaffolded manually, ensure platform files exist by running:

```bash
flutter create .   # Adds any missing iOS/Android scaffolding
```

For a device:

```bash
flutter run -d <device_id>
```

## Project Structure

```
lib/
├── main.dart                    # App entry
├── screens/
│   └── key_generation_screen.dart  # Camera UI + key generation
└── services/
    ├── camera_service.dart      # Camera capture, RAM-only read, temp cleanup
    └── key_service.dart         # SHA-3 → PBKDF2 → Secure Storage
```

## Planned Features (Not Yet Implemented)

- **QR code key sharing** – One device displays QR, other scans; both derive same key locally  
- **E2E encrypted messages** – Messages encrypted with the derived key  
- **Face + gesture auth** – MediaPipe/Face Mesh for expression/gesture unlock  

## Running on iPhone (most reliable: native app)

Flutter web can be flaky on iOS Safari. **Installing the native app is the most reliable option:**

1. Connect your iPhone to your Mac via USB
2. Trust the computer on the iPhone if prompted
3. Run: `flutter run` (Flutter will detect the device and install)
4. Or: `flutter run -d <device-id>` (list devices: `flutter devices`)

This gives you full camera and QR support without web limitations.

## Accessing from phone via ngrok (recommended for iPhone)

Uses HTTPS—works from anywhere. **Use the same ngrok URL on both computer and phone** so messages sync.

1. Install ngrok: `brew install ngrok`
2. Sign up at [ngrok.com](https://ngrok.com) (free) → get your auth token
3. Configure: `ngrok config add-authtoken YOUR_TOKEN`
4. Run: `./serve_ngrok.sh` (uses Node server for message sync if available)
5. Open the `https://xxx.ngrok-free.app` URL on **both** your computer and phone

## Accessing from phone (web) on same network

1. Run: `./serve_web.sh` (builds and serves)
2. Find your Mac's IP: `ipconfig getifaddr en0`
3. On phone: open `http://YOUR_IP:8080`

**Best setup:** Connect both computer and phone to the **same WiFi router** (not iPhone hotspot). Hotspot + Flutter web often fails on iOS Safari.

## Security Notes

- Image: Flutter camera writes briefly to temp cache; bytes are read and the temp file is deleted immediately  
- Key: Stored via `flutter_secure_storage` (Keychain / encrypted prefs)  
- Salt: Fixed app-specific salt; consider a per-session salt for QR sharing when that flow is added  
