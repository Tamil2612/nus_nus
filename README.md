# Nus·Nus (نسنس)

**Nus·Nus** (meaning "half-half") is a premium, localized expense-splitting application designed for ultimate clarity and transparency. Built with Flutter and Firebase, it combines a professional "Digital Receipt" aesthetic with cutting-edge AI to make managing shared finances effortless.

---

## 🌟 Key Features

### 1. **Nus Ai (Multimodal Bill Parsing)**
- **Vision Intelligence**: Powered by **Gemini 1.5 Flash**, Nus Ai can "read" your receipt photos directly.
- **Natural Language Splitting**: Simply describe the split (e.g., *"Vivek paid. Split everything except the coffee evenly. I had the coffee."*) and let the AI do the math.
- **Context-Aware**: The AI automatically identifies your group members and maps the split to the correct people.

### 2. **Dynamic Multi-Currency Support**
- **Per-Group Currency**: Create different groups for different regions (e.g., "Dubai Trip" in **AED**, "USA Trip" in **USD**).
- **Intelligent Formatting**: The app automatically applies the correct symbols and regional formatting across all screens.
- **Aggregated View**: Your global standings are tracked separately per currency to ensure 100% accuracy.

### 3. **Unique "Split-Ticket" Activity Feed**
- **Professional Layout**: A chronologically reversed feed where every expense is displayed as a stylized digital "tab" or ticket.
- **Visual Hierarchy**: Immediate clarity on who paid, how much was spent, and who is participating in the split.

### 4. **"People" Dashboard**
- **Pairwise Standing**: A dedicated tab that aggregates all your debts and credits across every group you participate in.
- **Directional Flow**: Clear visual indicators show exactly who owes whom (e.g., `YOU <- AED 50 <- RAHUL`).
- **One-Tap Global Settle**: Resolve all shared dues with a specific person across all groups with a single click.

### 5. **Secure & Fair Logic**
- **Creditor-Only Settlement**: To ensure honesty, only the person who is **owed money** can officially confirm and record a settlement.
- **Creator Controls**: The person who adds a split has full administrative control to edit or delete it.
- **Soft-Deletion**: Members with history are archived rather than deleted, preserving historical balance accuracy.

---

## 🛠️ Technical Stack
- **Frontend**: Flutter (3.x) with Provider for state management.
- **Backend**: Firebase (Firestore for real-time sync, Auth for secure login).
- **Intelligence**: Google AI SDK (Gemini 1.5 Flash).
- **Distribution**: PWA-ready for instant iOS and Android home screen installation.

---

## 🔒 Security Rules

The application enforces strict data isolation and permission checks via Firestore Security Rules. These ensure that users can only view groups they are members of and only edit data they have created. (See `firestore.rules` for full technical definitions).
