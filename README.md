# Telecloud

A Telegram-powered cloud file manager and music player for iOS.

![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)
![Swift Version](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **File Manager**: Browse, organize, and manage files from your Telegram groups
- **Music Player**: Full-featured audio player with Spotify-style Now Playing screen
- **Virtual Folders**: Organize files into folders (stored locally with JSON index)
- **Background Playback**: Continue listening while using other apps
- **AirPlay Support**: Stream to AirPlay devices
- **Lock Screen Controls**: Control playback from lock screen

## Architecture

```
Telecloud/
├── App/                    # App entry point
├── Views/                  # SwiftUI Views
│   ├── Auth/              # Login views
│   ├── FileManager/       # File browser views
│   └── Player/            # Music player views
├── ViewModels/            # MVVM ViewModels
├── Models/                # Data models
├── Services/              # Business logic
│   ├── TelegramService.swift    # Bot API client
│   └── FileSystemService.swift  # File management
└── Player/                # Audio playback
    └── AudioPlayerService.swift
```

## Setup Instructions

### 1. Create a Telegram Bot

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` and follow the instructions
3. Save the bot token (looks like `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

### 2. Create a Group

1. Create a new group in Telegram
2. Add your bot to the group
3. Make the bot an administrator
4. Send a test message in the group

### 3. Get Chat ID

1. Visit: `https://api.telegram.org/botYOUR_TOKEN/getUpdates`
2. Look for `"chat":{"id":-123456789}`
3. The number (including the minus sign) is your Chat ID

### 4. Build and Run

#### Option A: GitHub Actions (Free, No Mac Required)

1. Fork this repository
2. Push your changes to the `main` branch
3. GitHub Actions will automatically build the IPA
4. Download the unsigned IPA from the Actions artifacts
5. Install using AltStore, Sideloadly, or similar tools

#### Option B: Xcode (Mac Required)

1. Open `Telecloud.xcodeproj` in Xcode 15+
2. Select your team in Signing & Capabilities
3. Build and run on your device

## Virtual Folder System

Since Telegram doesn't support real folders, Telecloud uses a local JSON index file (`telecloud_index.json`) to maintain folder structure:

```json
{
  "folders": [
    {
      "id": "uuid",
      "name": "Music",
      "parentId": null
    }
  ],
  "files": [
    {
      "id": "uuid",
      "messageId": 123,
      "folderId": "uuid",
      "filename": "song.mp3"
    }
  ]
}
```

## Technical Stack

- **iOS**: 16.0+
- **Swift**: 5.9
- **SwiftUI**: Modern declarative UI
- **Combine**: Reactive programming
- **AVFoundation**: Audio playback
- **Telegram Bot API**: Cloud storage backend

## Building Unsigned IPA

The included GitHub Actions workflow builds an unsigned IPA that can be installed on any iOS device using:

- **AltStore** (Recommended)
- **Sideloadly**
- **TrollStore** (iOS 14.0 - 16.6.1)
- **Enterprise signing**

No paid Apple Developer account required!

## License

MIT License - See LICENSE file for details

## Credits

- Telegram Bot API for cloud storage
- SwiftUI for the beautiful UI
- SF Symbols for icons
