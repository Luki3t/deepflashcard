# DeepFlashcard

A language-learning flashcard app built with Flutter. Spaced repetition (SM-2),
on-device translation, pronunciation, and example sentences — everything runs
locally on your device, offline, with no server and no API keys required.

## Features

- Decks with source/target language pairs
- Manual flashcard creation with auto-translation (Google ML Kit, on-device)
- Spaced repetition (SM-2 algorithm, like Anki)
- Study modes: flip card, multiple choice, typed answer
- Text-to-speech pronunciation
- Example sentences from Tatoeba (downloaded on demand, offline afterwards)
- Stats and daily streak
- Daily reminder notifications
- Light/dark theme

## Getting started

Requirements:

- Flutter SDK (stable channel)
- Android Studio or VS Code with the Flutter/Dart extensions
- An Android emulator or device (API 24+)

```
flutter pub get
flutter run
```

No API keys are needed — the app works fully offline.

## Building a release

```
flutter build apk --release        # single APK, for local testing
flutter build appbundle --release  # .aab, for Google Play upload
```

Release builds are signed using `android/key.properties`
(see `android/app/build.gradle.kts`). That file is git-ignored and must be
created locally — it is not checked into version control.

## Attribution

- Translation: [Google ML Kit](https://developers.google.com/ml-kit) (on-device, free)
- Example sentences: [Tatoeba.org](https://tatoeba.org) contributors, licensed
  [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/)

## Privacy

This app stores all data locally on your device. Nothing is sent to any server.
