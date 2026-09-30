# Nus·Nus (نص نص)

**Nus·Nus** (Arabic for *"Half-Half"*) is a smart, localized expense-splitting application designed for maximum clarity, fairness, and transparency. Built with **Flutter** and **Firebase Cloud Functions**, it combines a modern digital receipt aesthetic with **Gemini AI** to make split tabs and shared group expenses completely effortless.

---

## 🌟 Key Features

### 1. 🤖 **Gemini AI Powered Assistance (`Nus AI`)**
* **Multimodal Receipt Scanning**: Upload a photo of any receipt or bill. Gemini AI automatically extracts line items, totals, tax/fees distribution, and payer details.
* **Natural Language Split Prompts**: Type custom split instructions in plain English or Arabic (e.g., *"Total 150 AED. Rahul paid. Split evenly between everyone except Sarah who didn't order drinks"*).
* **"Ask Anything" App State AI Chat**: Ask questions directly about your groups and balances (e.g., *"How much do I owe across all my trips?"* or *"Who spent the most on dinner last night?"*).

### 2. 🧮 **Automated Settlement & Pairwise Debt Minimization**
* **Algorithmic Debt Optimization**: Built-in settlement calculator resolves complex multi-person group debts down to the minimal possible number of transfer transactions.
* **Creditor-Gated Settlement System**: For maximum trust, only the person **owed money** (the creditor) can officially record or confirm a settlement.
* **Transparent Ledger Flow**: View detailed pairwise breakdowns (`You owe Person A: 45 AED`, `Person B owes You: 90 AED`) with real-time balance calculations.

### 3. 💳 **Digital Receipt Feed & Group Management**
* **Ticket-Style Activity Feed**: Expenses are styled as sleek, chronological digital "tabs" showing exact split maps, timestamps, and participant tags.
* **Multi-Group & Multi-Currency**: Manage separate groups for trips, households, or events (e.g., AED for Dubai, USD for US trip, EUR for Euro trip) with isolated balances per currency.
* **Flexible Member Management**: Add group members dynamically with real-time sync across all connected devices.

---

## 🏗️ Architecture & Technology Stack

```
   ┌─────────────────────────────────────────────────────────┐
   │             Flutter Cross-Platform Frontend             │
   │  (iOS, Android, Web, macOS, Windows with ScreenUtil)    │
   └──────────────────────────┬──────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            ▼                                   ▼
┌─────────────────────────┐         ┌─────────────────────────┐
│   Firebase Firestore    │         │ Firebase Cloud Functions│
│  (Real-Time DB Sync &   │         │ (Node.js Serverless AI  │
│     Authentication)     │         │ & Gemini 3.6 Flash SDK) │
└─────────────────────────┘         └─────────────────────────┘
```

* **Frontend**: [Flutter](https://flutter.dev) (Dart) with `Provider` state management, `flutter_screenutil` responsive scaling, and `Google Fonts`.
* **Backend**: [Firebase Cloud Functions](https://firebase.google.com/docs/functions) (Node.js) for serverless AI operations and backend validation.
* **Database & Auth**: [Cloud Firestore](https://firebase.google.com/docs/firestore) real-time streams & [Firebase Auth](https://firebase.google.com/docs/auth).
* **Artificial Intelligence**: [Google Gemini AI](https://deepmind.google/technologies/gemini/) (`gemini-3.6-flash`) via the Google Generative AI SDK.
* **CI/CD Pipeline**: GitHub Actions for automated Flutter Web builds and Firebase Hosting deployment.

---

## 📁 Repository Structure

```
nus_nus/
├── lib/
│   ├── models/            # Data models (Expense, Group, AppUser, LedgerEntry)
│   ├── providers/         # State management (SplitProvider)
│   ├── screens/           # UI screens (Home, AI Expense, Group Detail, Auth)
│   ├── services/          # Firebase & Gemini AI integrations (GeminiAiService)
│   ├── theme/             # Custom design tokens and color palettes
│   ├── utils/             # Settlement calculator engine & formatters
│   └── widgets/           # Modular UI components (Receipt Cards, Chat Views)
├── functions/             # Firebase Cloud Functions backend (Node.js)
│   ├── index.js           # Serverless AI endpoints (parseBillWithAI, queryAppState)
│   └── package.json       # Backend dependencies
├── .github/workflows/     # GitHub Actions CI/CD for Firebase Hosting
├── firebase.json          # Firebase deployment configuration
├── firestore.rules        # Firestore security rules
└── pubspec.yaml           # Flutter dependencies
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.0.0`)
* [Node.js](https://nodejs.org/) (`v20+`) & npm
* [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)

### 1. Clone & Install Flutter Dependencies
```bash
git clone https://github.com/Tamil2612/nus_nus.git
cd nus_nus
flutter pub get
```

### 2. Run the App
```bash
# Run on Chrome Web
flutter run -d chrome

# Run on Android / iOS
flutter run
```

---

## ☁️ Deploying Firebase Cloud Functions

1. Navigate to the `functions` directory and set your Gemini API key in `functions/.env`:
   ```env
   GEMINI_API_KEY=YOUR_GEMINI_API_KEY
   ```

2. Deploy Cloud Functions to Firebase:
   ```bash
   npx firebase-tools deploy --only functions
   ```

---

## 🔒 Security & Privacy
* **API Key Protection**: Gemini AI API keys are stored securely in backend serverless environment variables (`functions/.env`), preventing exposure inside client app builds.
* **Firestore Security Rules**: User data access is strictly bounded by group membership and authentication tokens (`firestore.rules`).
