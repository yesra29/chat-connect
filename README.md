# ChatConnect 

ChatConnect is a real-time chat application built with Flutter and Firebase. It allows users to communicate instantly with features like authentication, message timestamps, and message deletion. Designed for smooth performance and clean UI/UX.

##  Features

- 🔐 Firebase Authentication (Email/Password)
- 💬 Real-time Messaging (Cloud Firestore)
- 🕓 Timestamps on Messages
- 🔔 In-app Notifications (Local/Push)
- 🗑️ Message Deletion (Client-side)
- 📱 Mobile-first UI using Flutter


## 🛠 Tech Stack

- Frontend: Flutter (Dart)
- Backend: Firebase (Authentication, Firestore, Cloud Functions)
- Notifications: Firebase Messaging / Local Notifications

## 🧑‍💻 Installation

1. Clone the repo
   git clone git@github.com:yesra29/chat-connect.git
   cd chat-connect
  

2. Install dependencies
   flutter pub get

3. Set up Firebase
   - Create a Firebase project at [firebase.google.com](https://firebase.google.com/)
   - Add your `google-services.json` (Android) and/or `GoogleService-Info.plist` (iOS)
   - Enable Email/Password sign-in in Firebase Authentication
   - Set up Firestore rules and Cloud Messaging if needed

4. Run the app
   flutter run

## 🔧 Project Structure

```
lib/
├── main.dart
├── screens/
├── widgets/
├── models/
├── services/
└── utils/
```

##  TODOs

- [x] Add real-time messaging
- [x] User authentication
- [x] Message deletion
- [ ] Group chat rooms
- [ ] Typing indicators
- [ ] Image/file sharing

##  Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

##  License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.


