# LanLock

For the start, I am a very security-focused person, and I care about small details too.  
I use a password manager on Linux called `pass`.  
But it was confusing for me that I could not easily share my passwords between Linux, Windows, and my phone.  
So I got this idea and built LanLock.

## What is LanLock?

LanLock is a local password manager made with Flutter.

It helps you:

- save password profiles
- save metadata for each profile (like email, notes, username)
- keep sensitive data encrypted (AES)
- store data in local SQLite database
- view your passwords from phone/PC in the same network using a small LAN web server
- create backup export/import

This project is focused on local control, simple flow, and practical security.

## Security model (important)

- LanLock uses one **master password**.
- This same master password is also used for LAN web login.
- Secrets (passwords + metadata values) are encrypted and stored in SQLite.
- App stores a derived encryption key in secure storage for fast startup.
- If this stored key is missing/lost, app asks master password again.

## Main features

- Profile list with search
- Folder-style names using `/` (example: `gmail/main`, `github/personal`)
- Password actions: view, copy, edit
- Metadata key actions: view, copy, edit
- Add profile with generated or custom password
- LAN web interface (read-focused)
- Backup export/import
- Master-password based encryption flow

## Requirements

You need:

- Flutter SDK (stable)
- Dart SDK (comes with Flutter)
- Android SDK + emulator/device (for Android testing)

Optional:

- Linux desktop toolchain (if you also run on Linux desktop)

## How to run

1. Clone the project:

```bash
git clone https://github.com/itsmu1x/lanlock
cd lanlock
```

2. Get packages:

```bash
flutter pub get
```

3. Run app:

```bash
flutter run
```

## App icon generation (Android)

If you changed icon image, run:

```bash
dart run flutter_launcher_icons
```

Then rebuild:

```bash
flutter clean
flutter run
```

## Notes

- Data is local on your device.
- If you uninstall app or clear app data, you can lose access to stored data.
- Please export backups often if your passwords are important.
- Release build needs `INTERNET` permission (already added in Android manifest) for LAN server.

## Quick flow

1. First start:
   - If there is no master password, app asks user to create one.
2. Next starts:
   - If stored key exists, app opens directly.
   - If key is missing, app asks master password.
