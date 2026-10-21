# Nus·Nus — Split Expenses, Simply

**Nus·Nus** (نص نص, “half-half”) is a Flutter expense-sharing app that helps groups record shared costs, understand who owes whom, and keep conversations and expenses together.

Built with **Flutter, Firebase, and Google Gemini**, Nus·Nus combines expense tracking, group balances, AI-assisted receipt parsing, and a group chat where members can discuss plans, share images, and see expenses in the same timeline.

> **Payments:** Nus·Nus records expenses and settlement status. It does not initiate bank transfers or move money.

## Highlights

### 💬 Group chat and shared timeline
- Chat with members inside a group.
- View chat messages and expense cards in one chronological timeline.
- Send text messages and share images from the gallery or camera.
- Store new chat images in Firebase Storage instead of embedding image data in Firestore documents.
- Load recent messages first and fetch older messages as needed.
- Edit your own text message **once**. The app UI and Firestore security rules enforce the one-time limit.
- Delete messages according to authorship and group-owner permissions.
- Open shared images in a full-screen viewer with zoom support.
- Receive push notifications for new group messages and open the relevant group from a notification, where configured.

### 💸 Expense tracking
- Create personal and shared groups.
- Record an expense, choose the payer, and select participants for the split.
- View expense history, contributions, and outstanding balances.
- Edit or delete expenses according to the app's ownership and permission rules.
- Keep expenses in the dedicated group expenses collection; the chat timeline displays expenses without duplicating the financial records.

### 🧮 Balances and settlements
- Calculate outstanding shares for group members.
- Track settlement status and show remaining balances.
- Net opposing debts and calculate suggested transfers to simplify settling a group.
- Validate settlement requests on the backend before changing expense records.

A settlement record is not independent proof that a bank transfer occurred. Users remain responsible for completing and verifying payments outside the app.

### 🤖 Gemini AI assistance
- Extract proposed bill details from receipt images or text.
- Suggest payer, participants, and expense splits using the available group context.
- Ask questions about expenses, groups, and balances using the app's AI assistance.

Always review AI-generated amounts and receipt details before saving them.

### 👥 Groups, accounts, and notifications
- Manage groups and members.
- Link app accounts to group participants where supported.
- Support group currencies, including AED.
- Use Firebase Cloud Messaging for configured notifications.
- Keep notification tokens in private user documents.
- Delete accounts through the trusted account-cleanup function. Personal ledgers and profile data are removed; shared groups require an ownership transfer or explicit deletion, while retained shared history is anonymized.

### 🛡️ Security and reliability
- Firebase Authentication protects signed-in workflows.
- Firestore rules restrict group data to members and enforce message authorship and edit restrictions.
- Firebase Storage rules limit access to group chat images and restrict uploads by path, type, and size.
- Cloud Functions handle trusted operations such as group deletion and related chat cleanup.
- Loading and error states help prevent duplicate actions and communicate failed operations.

## Technology stack

| Area | Technology |
|---|---|
| Mobile and web UI | Flutter, Dart |
| State management | Provider |
| Responsive layout | Flutter ScreenUtil |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Image storage | Firebase Storage |
| Backend | Firebase Cloud Functions (Node.js) |
| Push notifications | Firebase Cloud Messaging |
| AI assistance | Google Gemini API |
| Hosting | Firebase Hosting |
| Tests | Flutter tests, Node.js tests, Firebase Emulator Suite |

## Project structure

```text
nus_nus/
├── lib/
│   ├── data/          # Firestore and repository logic
│   ├── models/        # Expenses, groups, messages, people and balances
│   ├── providers/     # Application state
│   ├── screens/       # App screens
│   ├── services/      # AI, notifications and supporting services
│   ├── theme/         # Colors and theme
│   ├── utils/         # Formatting and calculation helpers
│   ├── widgets/       # Reusable UI and group chat
│   └── main.dart
├── functions/
│   └── index.js       # Callable functions and notification triggers
├── functions/rules-tests/
│   └── firestore_rules.emulator.cjs
├── test/              # Flutter tests
├── firestore.rules
├── storage.rules
├── firebase.json
├── pubspec.yaml
└── README.md
```

## Getting started

### Prerequisites
Install:
- Flutter SDK and its compatible Dart SDK
- Node.js 22 and npm
- Firebase CLI
- A Firebase project with the services required by the features you want to run
- A Gemini API key if using Gemini-powered functionality

Useful guides: [Flutter setup](https://docs.flutter.dev/get-started/install) · [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup) · [Firebase CLI](https://firebase.google.com/docs/cli) · [Cloud Functions](https://firebase.google.com/docs/functions) · [Google AI Studio](https://aistudio.google.com/)

### 1. Clone and install dependencies

```bash
git clone https://github.com/Tamil2612/nus_nus.git
cd nus_nus
flutter pub get
npm ci --prefix functions
```

### 2. Configure Firebase

Ensure the Flutter platform configuration files and Firebase project alias point to the project you intend to use. For a separate Firebase project, follow the official FlutterFire setup instructions and update the configuration accordingly.

Enable the services required by your chosen features:
- Firebase Authentication
- Cloud Firestore
- Firebase Storage for chat images
- Cloud Functions for trusted backend operations and notification triggers
- Firebase Cloud Messaging for push notifications
- Firebase Hosting if deploying the web build

Before deploying, verify the active Firebase project:

```bash
firebase login
firebase projects:list
cat .firebaserc
```

### 3. Configure Gemini

Configure the Gemini API key for the backend using Firebase's supported secret configuration. For local development, use the environment setup expected by the Functions code (for example, a local `functions/.env` file when supported).

```env
GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

Replace the placeholder with your own key. Never commit real API keys, credentials, service-account files, or populated secret files to Git.

### 4. Run the app

Run on an available device or emulator:

```bash
flutter run
```

Run the web app in Chrome:

```bash
flutter run -d chrome
```

Firebase authentication, database, storage, and function behavior require the relevant project configuration and permissions.

## Testing and quality checks

Run Flutter dependency resolution, analysis, and tests:

```bash
flutter pub get
flutter analyze
flutter test
```

Run the Cloud Functions test suite:

```bash
npm test --prefix functions
```

The group-chat CI workflow also exercises Firestore and Storage rules against the Firebase Emulator Suite and builds the Flutter web app. Use the repository's workflow as the source of truth for the exact CI steps.

Important manual scenarios:
- Send, receive, edit once, and delete text messages.
- Verify that a second edit is rejected by Firestore rules, not only hidden in the UI.
- Upload and view images as a group member; verify unauthorized users cannot read them.
- Test notification delivery and tap-to-open navigation.
- Delete a group and verify the related chat data and Storage objects are cleaned up.
- Delete an account with owned groups; verify ownership choices are enforced, retained groups stay usable, and former-member labels replace identifying names.
- Test expense creation, balance calculations, and settlement validation.
- Confirm loading indicators and error states behave correctly on slow or failed requests.

## Firebase deployment

**Review the Firebase project and the CI results before deploying.** Rules and functions are production changes; deploy only to the intended project.

Deploy Firestore and Storage rules:

```bash
firebase deploy --only firestore:rules,storage
```

Deploy Cloud Functions:

```bash
firebase deploy --only functions
```

Build and deploy Flutter web hosting:

```bash
flutter build web --dart-define=FIREBASE_VAPID_KEY="$FIREBASE_VAPID_KEY"
firebase deploy --only hosting
```

Before building, set `FIREBASE_VAPID_KEY` to the Firebase project's **Web Push
public key** from Firebase Console → Project settings → Cloud Messaging → Web
Push certificates. Do not use a private key or the Firebase API key. The key is
public and must be supplied to every web build; the Hosting deployment
workflow reads it from the GitHub Actions repository secret with the same name.
Firebase Hosting serves the PWA over HTTPS, which Web Push requires.

On iPhone/iPad, Web Push requires iOS/iPadOS 16.4 or later and an installed
Home Screen web app. Open Nus·Nus in Safari, choose Share → Add to Home Screen,
enable “Open as Web App” if offered, then launch that icon, sign in, and tap
Enable notifications in the drawer. Installing the PWA does not itself request
notification permission.

Deploying rules is required for the latest chat access and one-time edit restrictions to apply in production. Deploying functions is required for backend functionality such as message notifications and group deletion cleanup. Do not run deployment commands until you have verified the active Firebase project and reviewed the changes.

## Data and security notes

- Group messages are stored under `groups/{groupId}/messages`.
- Expenses remain authoritative under `groups/{groupId}/expenses`; the chat timeline does not duplicate expense records.
- New chat images are stored in Firebase Storage under group-scoped paths.
- Firestore rules restrict chat access to group members and validate message authorship.
- A text message can be edited once; image messages are not editable.
- Group deletion uses a trusted backend operation to clean up related data and chat images.
- Keep Gemini API keys and other secrets on the backend, not in client source code.
- Review security rules and Cloud Functions changes before deploying to production.

## Contributing

1. Create a focused feature branch.
2. Keep changes scoped and add or update relevant tests.
3. Run `flutter analyze`, `flutter test`, and `npm test --prefix functions`.
4. Test relevant Firebase rules and backend behavior in the Emulator Suite.
5. Open a pull request describing the change and the checks performed.

## License

No license is specified in this repository. Add a `LICENSE` file and update this section before distributing the project under an open-source license.
