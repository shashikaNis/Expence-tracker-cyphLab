# Expense Tracker

A Flutter (Android) expense tracker backed by Firebase Authentication and Cloud Firestore.

## Contents

1. [Project Setup Instructions](#project-setup-instructions)
2. [Features Implemented](#features-implemented)
3. [Technologies / Packages Used](#technologies--packages-used)
4. [AI Tools Used](#ai-tools-used)
5. [Firestore Data Structure](#firestore-data-structure)
6. [Project Structure](#project-structure)
7. [Troubleshooting](#troubleshooting)

## Project Setup Instructions

### Prerequisites

1. **Flutter SDK 3.24.x**, on your `PATH`. Check with `flutter --version`.
2. **Android Studio** with:
   - Android SDK Platform **34** (SDK Manager → SDK Platforms)
   - Android SDK Build-Tools and Command-line Tools (SDK Manager → SDK Tools)
   - NDK **25.1.8937393** (SDK Tools → tick "Show Package Details" under NDK)
3. **JDK 17 or 21.** The JDK bundled with Android Studio works. Run `flutter doctor -v` to see which one Flutter uses.
4. **Firebase CLI** and **FlutterFire CLI**, only needed if you connect your own Firebase project:

   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   ```

Run `flutter doctor` and fix anything it flags under Flutter, Android toolchain and Android Studio.

### 1. Get the code and dependencies

```bash
git clone <repository-url>
cd "Expense Tracker CyphLab"
flutter pub get
```

### 2. Connect Firebase

The repo already contains `android/app/google-services.json` and `lib/firebase_options.dart` for the `expence-tracker-cyphlab` Firebase project. If you have access to that project, skip to step 3.

To use your **own** Firebase project instead:

1. Create a project in the [Firebase console](https://console.firebase.google.com/).
2. Run the following from the project root and select your project. When asked, choose **Android**:

   ```bash
   firebase login
   flutterfire configure
   ```

   This registers the Android app `com.cyphlab.expense_tracker_cyph_lab` and regenerates `google-services.json` and `firebase_options.dart`.

### 3. Enable Authentication

Firebase console → **Authentication** → **Sign-in method** → enable **Email/Password**.

### 4. Create Firestore and set security rules

Firebase console → **Firestore Database** → **Create database**. Then open the **Rules** tab and publish:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
      match /{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
}
```

These rules let each signed-in user read and write only their own data. No composite indexes are needed.

### 5. Run the app

Connect an Android device with USB debugging enabled, or start an emulator, then:

```bash
flutter run
```

To build an APK:

```bash
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/`. Release builds currently use the debug signing key; set up your own signing config before publishing.

## Features Implemented

- Email/password sign up, sign in, password reset and logout
- Add, edit (tap an expense) and delete (swipe left, or the bin icon on the edit screen) expenses
- Fixed categories, each with its own icon and colour
- Home screen filtered by month (defaults to the current month) and category (defaults to All), with a running total
- Charts:
  - **Monthly**: line chart of monthly totals across all your data
  - **By Category**: pie chart for a whole year or a single month
- Light, dark or system theme (remembered between launches)

## Technologies / Packages Used

| Area | Package |
| --- | --- |
| Framework | Flutter 3.24.x (Dart ^3.5.4) |
| Auth | `firebase_auth` |
| Database | `cloud_firestore` |
| Charts | `fl_chart` 0.69.x (newer versions need Flutter 3.27+) |
| Theme preference | `shared_preferences` |

Android build: Gradle 8.7, Android Gradle Plugin 8.3.2, Kotlin 1.9.24, `minSdk` 23.

## AI Tools Used

| Tool | Used for |
| --- | --- |
| **Android Studio AI agent** | Fixing Firebase setup issues inside Android Studio |
| **Claude Code** (Anthropic, Claude Opus 5.5 model) | AI coding assistant used in the Claude desktop app |

### Android Studio AI agent

- **Firebase CLI registration error:** `flutterfire configure` failed with `FirebaseCommandException` while registering `com.example.expense_tracker_cyph_lab` with the Firebase project.
  - **Cause:** default `com.example...` package names often clash with an app ID already registered (or deleted) in the Firebase project.
  - **Fix:** the agent recommended changing `applicationId` in `android/app/build.gradle`. It is now `com.cyphlab.expense_tracker_cyph_lab`. The agent also gave steps to re-authenticate the CLI (`firebase login --reauth`) and to check the app's status in the Firebase console.
- **Dart compile error:** `lib/firebase_options.dart` reported `The method 'FirebaseOptions' isn't defined for the type 'DefaultFirebaseOptions'`.
  - **Cause:** `firebase_core` was missing from `pubspec.yaml`, so its import could not be resolved.
  - **Fix:** the agent added `firebase_core` to `pubspec.yaml` and ran `flutter pub get`.

### Claude Code

Claude Code helped with:

- **Build fix:** diagnosing the Android Gradle error `Cannot query the value of this provider` (a corrupted Android SDK Platform 34 install), reinstalling the platform, and upgrading Gradle, the Android Gradle Plugin and Kotlin.
- **Firestore integration:** saving expenses to Cloud Firestore and showing them in a live list on the home screen.
- **README:** writing this README.

Each AI-assisted change was checked with `flutter analyze` and `flutter build apk`.

## Firestore Data Structure

```
users/{uid}
  monthlyTotalsVersion: 1
  expenses/{expenseId}
    amount, title, category, date (Timestamp), note, createdAt, updatedAt
  monthlyTotals/{YYYY-MM}            e.g. 2026-10
    year, month, total, count,
    categories: { Food: 4500, Fuel: 3000, ... },
    updatedAt
```

- `monthlyTotals` is a per-month summary that the charts read from, so they don't have to load every expense.
- Adding an expense updates its month in the same batch write. Editing and deleting use a transaction that moves the amount between months and categories, and removes a month's summary when it has no expenses left.
- The first time the Charts screen opens, the app rebuilds `monthlyTotals` from all existing expenses (`ExpenseService.ensureMonthlyTotals`). It then sets `monthlyTotalsVersion` so this doesn't run again.

## Project Structure

```
lib/
  main.dart                    App entry, Firebase init, theme mode
  routes.dart                  Named routes
  firebase_options.dart        Generated by FlutterFire CLI
  models/
    expense.dart               Expense model + Firestore mapping
    expense_category.dart      Category list (name, icon, colour)
    monthly_total.dart         Monthly summary model
  services/
    expense_service.dart       Firestore reads/writes and monthly totals
  theme/
    theme_controller.dart      Light/dark themes and saved preference
  ui/
    loginScreen.dart
    signupScreen.dart
    homeScreen.dart            List with month/category filters
    addExpenses.dart           Add / edit / delete form
    chartsScreen.dart          Monthly line chart and category pie chart
```

To add or change a category, edit the list in `lib/models/expense_category.dart`.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `Could not determine the dependencies of task ':firebase_auth:compileDebugJavaWithJavac'` / `Cannot query the value of this provider` | The Android SDK Platform 34 install is incomplete (`platforms/android-34/core-for-system-modules.jar` is missing). Uninstall and reinstall **Android SDK Platform 34** in the SDK Manager. |
| `Manifest merger failed : uses-sdk:minSdkVersion ... cannot be smaller than version 23` | `minSdk` must be 23 or higher in `android/app/build.gradle`. |
| `PlatformException(channel-error, Unable to establish connection on channel.)` | You added a plugin and then used hot reload or hot restart. Stop the app and run `flutter run` again; if it continues, run `flutter clean` first. |
| `PERMISSION_DENIED` when saving or loading | Publish the Firestore rules from step 4, and make sure you're signed in. |
| `NOT_FOUND` / database does not exist | Create the Firestore database (step 4). |
| `Unsupported class file major version` | Gradle is running on a JDK that's too new. Use Android Studio's bundled JDK (17 or 21), e.g. `flutter config --jdk-dir "<Android Studio>/jbr"`. |
| Build errors mentioning `withValues` or `Color.a` in `fl_chart` | Keep `fl_chart` at `^0.69.2` while on Flutter 3.24. |
| `FirebaseCommandException` when `flutterfire configure` registers the Android app | Use a unique `applicationId` (not `com.example...`) in `android/app/build.gradle`, run `firebase login --reauth`, and check whether an app with that package name already exists, or was deleted, in the Firebase console. |
| `The method 'FirebaseOptions' isn't defined` in `firebase_options.dart` | Add `firebase_core` to `pubspec.yaml` and run `flutter pub get`. |
