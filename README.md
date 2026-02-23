An encrypted chat app where keys are created through a physical ceremony — never transmitted online.

I've been thinking about digital security and how quantum computing will eventually break today's encryption — pushing us back to more analog methods.
That, and watching a Youtube-video about Cloudflare photographing lava-lamps to generate cryptographic randomness, sparked the idea for this project.

This is my first vibe coding project, built as a Java student with 6 months of coding experience. The concept is mine, built with Ai-assistance.

How it works

Key Ceremony — meet physically, capture a shared random image with the camera
The image is hashed with SHA-3, derived into a 256-bit key via PBKDF2, and stored in Secure Enclave (iOS) / TEE (Android). The image is never saved.
Share QR — show the QR code in the room, others scan it. When dismissed, it's gone forever.
Chat — all messages are encrypted with AES-256-GCM and forward secrecy via ratcheting.

Security features

Physical key exchange — no network attack surface at key creation
Secure Enclave / TEE storage — keys cannot be extracted
Forward secrecy — each message uses a derived subkey
Ed25519 message signing — messages cannot be forged
Panic button — one tap deletes all keys and messages permanently
Auto-delete — messages can be set to expire

Tech
Flutter · Dart · Node.js relay server · AES-256-GCM · SHA-3 · PBKDF2 · Ed25519

Status
In progress
