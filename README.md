# 📱 HeartConnect Mobile
[![Ask DeepWiki](https://devin.ai/assets/askdeepwiki.png)](https://deepwiki.com/jpmasangkay/heartconnect-mobile)

### Student Freelancer Job Marketplace — Mobile App

**Post. Apply. Connect. On the Go.**

The official Flutter mobile companion to HeartConnect — a full-stack freelancer job marketplace built for students. Browse and post jobs, manage applications, chat in real time, and get push notifications, all from a native mobile experience.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-3.x-00BFA5?style=for-the-badge)](https://riverpod.dev)
[![Dio](https://img.shields.io/badge/Dio-HTTP_Client-6C63FF?style=for-the-badge)](https://pub.dev/packages/dio)
[![Socket.io](https://img.shields.io/badge/Socket.io-Realtime-010101?style=for-the-badge&logo=socket.io&logoColor=white)](https://socket.io)
[![GoRouter](https://img.shields.io/badge/GoRouter-Navigation-0288D1?style=for-the-badge)](https://pub.dev/packages/go_router)

🖥️ **Backend API:** [heartconnect.onrender.com](https://heartconnect.onrender.com)

---

## ✨ Features

### 👤 Authentication & Roles

- **JWT-based authentication** — secure login, registration, and session persistence via `flutter_secure_storage`
- **Role-based navigation** — separate dashboard flows and permissions for Clients and Freelancers
- Protected routes enforce access control throughout the app

### 📋 Job Postings

- Clients can **create, edit, and delete** job listings directly from the mobile app
- Freelancers can **browse and filter** available jobs by category, budget, and status
- Each listing shows a full detail view with budget, description, tags, and deadline

### 📨 Application Management

- Freelancers can **apply to jobs** with a proposal message
- Clients can **review, accept, or reject** applications from their mobile dashboard
- Application status changes are reflected in real time

### 💬 Real-Time Chat

- **Socket.io-powered messaging** — instant message delivery without page refreshes
- **In-chat file sharing** — attach and send files directly within conversations using `file_picker` and `image_picker`
- Files are downloadable and openable in-app via `open_file`

### 🔔 Push Notifications

- **Firebase Cloud Messaging (FCM)** — push alerts for new messages, application status changes, and job updates, even when the app is in the background

### ⚡ Performance & UX

- **Riverpod** — reactive, compile-safe state management across the entire app
- **Shimmer loading skeletons** — smooth placeholder animations during data fetches
- **Cached network images** — faster image loads with built-in memory and disk caching
- **Smooth page indicator** — polished onboarding and carousel transitions
- **Google Fonts** — consistent, high-quality typography powered by the `google_fonts` package
- Fully **cross-platform** — targets Android and iOS from a single codebase

---

## 🛠️ Tech Stack

| Package | Purpose |
|---------|---------|
| **Flutter 3.x + Dart 3.x** | Cross-platform UI framework |
| **flutter_riverpod** | Reactive state management |
| **Dio** | HTTP client for REST API communication |
| **go_router** | Declarative, URL-based navigation |
| **socket_io_client** | Real-time bidirectional messaging |
| **flutter_secure_storage** | Secure JWT persistence on device |
| **google_fonts** | Custom typography (DM Serif Display, Inter) |
| **cached_network_image** | Efficient image loading and caching |
| **shimmer** | Skeleton loader animations |
| **image_picker** | Camera and gallery image selection |
| **file_picker** | Cross-platform file attachment picker |
| **open_file** | Open downloaded files with native apps |
| **url_launcher** | Launch URLs and external links |
| **path_provider** | Access device file system paths |
| **smooth_page_indicator** | Animated page/onboarding indicators |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x (Dart 3.x)
- Android Studio or Xcode for device/emulator setup
- A running instance of the [HeartConnect backend](https://github.com/jpmasangkay/heartconnect)

### Installation

```bash
# Clone the repository
git clone https://github.com/jpmasangkay/heartconnect-mobile.git
cd heartconnect-mobile

# Install dependencies
flutter pub get
```

### Environment Configuration

Create a `lib/core/constants/app_constants.dart` file (or update your existing constants file) with your backend URLs:

```dart
const String kBaseUrl = 'https://heartconnect.onrender.com';
const String kSocketUrl = 'https://heartconnect.onrender.com';
```

For local development, replace these with your local server address (e.g., `http://10.0.2.2:5000` for Android emulator).

### Running the App

```bash
# Run on a connected device or emulator
flutter run

# Run in release mode
flutter run --release
```

### Building for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle (recommended for Play Store)
flutter build appbundle --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

---

## 📁 Project Structure

```
heartconnect-mobile/
├── android/                         # Android platform files
├── ios/                             # iOS platform files
├── lib/
│   ├── main.dart                    # App entry point — ProviderScope + GoRouter init
│   ├── core/
│   │   ├── constants/               # API base URLs, route names, app-wide constants
│   │   ├── theme/                   # App theme — colors, typography, component styles
│   │   └── utils/                   # Shared helper functions and extensions
│   ├── models/                      # Dart data models (User, Job, Application, Message)
│   ├── services/
│   │   ├── api_service.dart         # Dio HTTP client setup, interceptors, token injection
│   │   ├── auth_service.dart        # Login, register, secure token storage
│   │   ├── job_service.dart         # Job CRUD API calls
│   │   ├── application_service.dart # Application management API calls
│   │   ├── message_service.dart     # Chat history and file upload API calls
│   │   └── socket_service.dart      # Socket.io connection and event listeners
│   ├── providers/                   # Riverpod providers (auth, jobs, applications, chat)
│   ├── router/
│   │   └── app_router.dart          # GoRouter route definitions and guards
│   ├── features/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── dashboard/
│   │   │   ├── client_dashboard.dart
│   │   │   └── freelancer_dashboard.dart
│   │   ├── jobs/
│   │   │   ├── jobs_screen.dart     # Job browse + filter
│   │   │   ├── job_detail_screen.dart
│   │   │   └── job_form_screen.dart # Create / edit job
│   │   ├── applications/
│   │   │   ├── applications_screen.dart
│   │   │   └── proposal_screen.dart
│   │   └── chat/
│   │       ├── chat_list_screen.dart
│   │       └── chat_screen.dart     # Real-time message thread + file sharing
│   └── widgets/
│       ├── job_card.dart
│       ├── application_card.dart
│       ├── message_bubble.dart
│       └── skeletons/               # Shimmer skeleton widgets
└── pubspec.yaml
```

---

## 🧠 How It Works

HeartConnect Mobile is built around the same **role-driven, real-time architecture** as the web app, adapted for a native mobile experience:

1. **Authentication** — Users register as Client or Freelancer. JWTs are issued on login and stored securely on-device using `flutter_secure_storage`. Dio interceptors automatically attach tokens to every request. GoRouter guards redirect unauthenticated users to the login screen.

2. **Job Marketplace** — Clients post and manage jobs directly from the mobile dashboard. Freelancers browse listings with filter support. Each job detail screen shows full info and an apply button for eligible freelancers.

3. **Application Flow** — Freelancers submit a proposal tied to a job. Clients see incoming applications in their dashboard and can accept or reject them. Riverpod providers automatically re-fetch and reflect status changes across the UI.

4. **Real-Time Chat** — `socket_io_client` maintains a persistent connection to the backend. Messages are emitted, broadcast server-side, and received by the other party in real time. Files are picked via `file_picker` or `image_picker`, uploaded to a dedicated endpoint, and delivered as message payloads. Received files can be opened natively with `open_file`.

5. **Push Notifications** — Firebase Cloud Messaging delivers background push alerts when a message arrives or an application status changes, keeping users informed even when the app is closed.

6. **State Management** — Riverpod providers manage all async state (auth, jobs, applications, chat) with compile-time safety and zero `BuildContext` dependency, making the codebase clean and testable.

---

## 🌐 Backend

HeartConnect Mobile connects to the same shared backend as the web app.

| Service | URL |
|---------|-----|
| **Backend API (Render)** | [heartconnect.onrender.com](https://heartconnect.onrender.com) |
| **Web Frontend (Vercel)** | [heartconnect-nine.vercel.app](https://heartconnect-nine.vercel.app) |
| **Backend Repository** | [github.com/jpmasangkay/heartconnect](https://github.com/jpmasangkay/heartconnect) |

---

## 👥 Team

Built as a **CS 321 Software Engineering** final project at Sacred Heart College of Lucena City, Inc.

| Role | Responsibility |
|------|---------------|
| **Analyst** | Requirements gathering, documentation, use-case modeling |
| **UI/UX Designer** | Wireframes, design system, component prototyping |
| **Programmer** | Flutter frontend and mobile integration |
| **DB / QA** | Database design, test planning, and quality assurance |

---

## 👏 Acknowledgements

- State management by [Riverpod](https://riverpod.dev/)
- Navigation by [GoRouter](https://pub.dev/packages/go_router)
- HTTP client by [Dio](https://pub.dev/packages/dio)
- Real-time engine by [Socket.io](https://socket.io/)
- Typography by [Google Fonts](https://pub.dev/packages/google_fonts)
- Image caching by [cached_network_image](https://pub.dev/packages/cached_network_image)

---
