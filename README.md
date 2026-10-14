# Nus·Nus — Split Expenses, Simply

Nus·Nus (نص نص, meaning “half-half”) is a Flutter expense-sharing application that helps people track shared expenses, understand who owes whom, and record settlements transparently.

Built with Flutter and Firebase, Nus·Nus supports personal expense tracking, shared groups, live expense updates, optimized balance calculations, receipt parsing with Gemini AI, and push notifications.

## Features

### 💸 Expense Tracking
- Create personal and shared expense groups.
- Record expenses, choose the payer, and split costs between participants.
- Track who added an expense and when it was created.
- Edit or delete expenses according to the application's ownership and permission rules.
- View expense history and outstanding balances.

### 🧮 Balance Calculation and Settlements
- Calculate outstanding shares for each participant.
- Support partial and full settlement of expense shares.
- Net opposing debts between two participants.
- Calculate optimized transfers to settle overall group balances with fewer payments.
- Preserve the original expense history when settlements are recorded.
- Validate settlement amounts against current balances on the backend to reject stale or excessive settlement requests.

**How settlements work:** A settlement records that money was paid outside the app. Nus·Nus does not initiate bank transfers or move money. A linked account belonging to either participant in a debt pair can confirm the settlement. The backend verifies group membership, participant linkage, debt direction, and the amount before updating the relevant expense shares.

### 🤖 Gemini AI Assistance
- Parse bill details from text instructions and receipt images.
- Identify the payer and participants from the supplied member list.
- Generate proposed expense splits and validate that the amounts add up.
- Ask questions about expenses, groups, and balances using the app's AI assistance.

AI-generated expense details should be reviewed before they are saved. AI output is not a substitute for verifying a receipt or payment.

### 👥 Groups and Members
- Manage personal and shared groups.
- Add participants and link app accounts to group members.
- Keep group metadata and expenses synchronized through Firestore.
- Track individual contributions and balances.
- Support group currencies, including AED.

### 🔔 Notifications
- Register Firebase Cloud Messaging tokens for signed-in users.
- Notify other group members when a new shared expense is added.
- Remove invalid notification tokens when Firebase reports them as expired or unregistered.

### ⏳ Loading and Error Handling
- Display an app-wide loading overlay during critical operations.
- Prevent additional interactions while a blocking operation is running.
- Handle failed writes and refresh local data when necessary.

## Technology Stack

| Component | Technology |
|---|---|
| Frontend | Flutter and Dart |
| State management | Provider |
| Responsive UI | Flutter ScreenUtil |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Backend | Firebase Cloud Functions |
| AI | Google Gemini API |
| Push notifications | Firebase Cloud Messaging |
| Testing | Flutter Test |
| Hosting | Firebase Hosting configuration |

## Project Structure

```text
nus_nus/
├── lib/
│   ├── data/          # Firestore and member-directory repositories
│   ├── models/        # Expenses, groups, people and balances
│   ├── providers/     # Authentication and application state
│   ├── screens/       # Application screens
│   ├── services/      # AI, notifications and supporting services
│   ├── theme/         # Theme and application colors
│   ├── utils/         # Settlement calculations and formatting
│   ├── widgets/       # Reusable UI components
│   └── main.dart
├── functions/
│   ├── index.js       # Callable functions and notification triggers
│   └── package.json
├── test/              # Flutter unit tests
├── assets/
│   └── icon/
├── android/
├── ios/
├── web/
├── firestore.rules
├── firebase.json
├── pubspec.yaml
└── README.md
```

## Prerequisites

Install the following tools before setting up the project:

- Flutter SDK compatible with the dependencies in `pubspec.yaml`
- Dart SDK compatible with the Flutter installation
- Node.js 22 and npm for Cloud Functions
- Firebase CLI
- A Firebase project with the required services configured
- A Gemini API key for AI functionality

Useful installation guides:

- [Flutter installation](https://docs.flutter.dev/get-started/install)
- [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [Cloud Functions for Firebase](https://firebase.google.com/docs/functions)
- [Google AI Studio](https://aistudio.google.com/)

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/Tamil2612/nus_nus.git
cd nus_nus
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Make sure the Flutter Firebase configuration files match your Firebase project.

The repository contains Firebase project configuration for Nus·Nus. If you are setting up a different Firebase project, regenerate or update the platform configuration files using the official Firebase Flutter setup instructions.

Enable the Firebase services required by the application:

- Firebase Authentication
- Cloud Firestore
- Cloud Functions
- Firebase Cloud Messaging, if push notifications are required
- Firebase Hosting, if hosting the web build

### 4. Configure the Gemini API key

The Cloud Functions code reads the `GEMINI_API_KEY` environment variable, with a legacy Firebase Functions configuration fallback.

For a local Functions environment, create `functions/.env`:

```env
GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

Replace the placeholder with your own key. Do not commit real API keys, credentials, or secret files to Git.

For production, configure secrets using the appropriate Firebase-supported secret-management mechanism and ensure the deployed functions receive the key securely.

### 5. Install backend dependencies

```bash
cd functions
npm install
cd ..
```

### 6. Run the application

Run in Chrome:

```bash
flutter run -d chrome
```

Run on an available Android or iOS device:

```bash
flutter run
```

Ensure that the relevant platform configuration and Firebase services are set up before testing authentication or backend functionality.

## Testing

Run Flutter static analysis:

```bash
flutter analyze
```

Run the Flutter test suite:

```bash
flutter test
```

Install backend dependencies and verify that the Functions source loads:

```bash
cd functions
npm install
node --check index.js
```

The current `functions/package.json` does not define a working automated test suite. Consequently, `npm test` is not currently a valid passing-test command. Backend behavior should be tested separately, ideally using the Firebase Emulator Suite.

Important scenarios to test include:

- Creating, editing, and deleting expenses with different group roles.
- Calculating balances with partial and full settlements.
- Netting opposing debts correctly.
- Rejecting settlement attempts from unrelated users.
- Rejecting stale balances and settlement amounts above the current debt.
- Handling concurrent settlement attempts.
- Verifying Firestore security rules against unauthorized access.
- Confirming that loading overlays disappear after successful and failed operations.

## Firebase Deployment

Review the Firebase project and deployment configuration before deploying. Deploying backend functions, security rules, and web hosting are separate operations.

### Deploy Firestore rules

```bash
firebase deploy --only firestore:rules
```

### Deploy Cloud Functions

```bash
firebase deploy --only functions
```

### Build the Flutter web application

```bash
flutter build web
```

### Deploy web hosting

After building the web application:

```bash
firebase deploy --only hosting
```

Use the correct Firebase project and environment before deploying. Verify that the necessary API keys, permissions, billing configuration, and platform settings are in place.

## Security and Privacy

- Firebase Authentication is required for protected application and backend operations.
- Firestore rules restrict group access to members and enforce ownership and authorship constraints on expense operations.
- The settlement callable validates the caller's group membership and connection to one of the two participants before updating expense shares.
- AI API keys belong on the backend, not in Flutter source code or client-side configuration.
- Push notification tokens are stored under private user documents and should only be accessible to their owner.
- Never commit `.env` files containing real secrets, service-account credentials, or private keys.
- Review Firestore rules and Cloud Functions behavior before deploying changes to production.

## Important Notes

- Nus·Nus records expenses and settlements; it does not process or transfer money.
- A recorded settlement updates the relevant outstanding expense shares. It is not independent proof that a bank transfer occurred.
- The balance calculator computes suggested transfers from current net balances. These suggestions may differ from the detailed pairwise debt breakdown.
- AI-generated receipt data and expense splits should be checked by the user.
- A successful web build does not, by itself, verify mobile builds, backend correctness, security rules, or production deployment.

## Contributing

1. Create a feature branch.
2. Make focused changes.
3. Run `flutter analyze` and `flutter test`.
4. Test relevant backend and Firestore behavior.
5. Submit a pull request with a description of the changes and testing performed.

## License

No license is specified here. Add a `LICENSE` file and update this section before distributing the project under an open-source license.
