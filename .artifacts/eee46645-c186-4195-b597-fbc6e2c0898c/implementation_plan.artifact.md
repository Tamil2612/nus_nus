# Implementation Plan: Full-App AI Financial Assistant

Transform the AI experience from a specialized bill-splitter into a comprehensive financial assistant that can answer questions about your entire spending history across all groups.

## Proposed Changes

### [Component] GeminiAiService
#### [MODIFY] [gemini_ai_service.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/services/gemini_ai_service.dart)
- **New Method: `queryAppState`**:
  - Accepts a `userQuery` and a `compactAppState` string.
  - **System Prompt**: Defines the AI as a "Financial Data Analyst". Instructs it to parse the provided context (all groups/expenses) and answer the user's question accurately.
  - **Context Handling**: Gemini 3.6 Flash's large context window allows us to send a summary of all recent expenses and group standings.

### [Component] SplitProvider
#### [MODIFY] [split_provider.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/providers/split_provider.dart)
- **AI Context Getter**: Implement `getAiSummaryContext()`.
  - Generates a compact JSON string representing all groups, total spends, and individual expense descriptions/amounts for the current user.
  - Filters out sensitive data (UIDs) but keeps names and amounts.

### [Component] AI Expense Screen (UI Overhaul)
#### [MODIFY] [ai_expense_screen.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/screens/ai_expense_screen.dart)
- **Dual-Mode Layout**:
  - Add a "Segmented Control" or "Custom Toggle" at the top: **[SPLIT BILL]** | **[ASK ANYTHING]**.
- **Split Bill Mode**: Retains the current receipt upload and prompt logic.
- **Ask Anything Mode**:
  - A clean, dedicated chat interface.
  - Features suggested questions (e.g., *"How much did I spend this month?"*, *"Who owes me the most?"*, *"Which group is most active?"*).
  - Integration with the new `queryAppState` method.

### [Component] New Widgets
#### [NEW] `ai_chat_view.dart`
- A dedicated chat-history widget for the "Ask Anything" mode.
- Reuses the `TypingIndicator` and chat bubble styles from previous iterations.

## Verification Plan

### Manual Verification
1. **Split Mode**: Verify that uploading a receipt still works perfectly.
2. **Ask Mode**:
   - Ask: *"What is my total spending across all groups?"* -> Verify the AI calculates the sum correctly.
   - Ask: *"Did I buy coffee recently?"* -> Verify the AI finds relevant expense descriptions.
   - Ask: *"Who owes me money in the [Group Name] group?"* -> Verify it matches the Balances tab.
3. **Toggle Stability**: Ensure switching between modes doesn't lose current state (like a selected image).
