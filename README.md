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

## Main features

- Profile list with search
- Folder-style names using `/` (example: `gmail/main`, `github/personal`)
- Password actions: view, copy, edit
- Metadata key actions: view, copy, edit
- Add profile with generated or custom password
- LAN web interface (read-focused)
- Backup export/import

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
- If you uninstall app or clear app data, you will lose access to stored data.
- Please export backups often if your passwords are important.
