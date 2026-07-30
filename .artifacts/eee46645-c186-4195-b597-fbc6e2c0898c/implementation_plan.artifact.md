# Implementation Plan: Revert AI Architecture to Client-Side Gemini SDK

Roll back the AI integration from the server-side **Firebase AI Logic** (Vertex AI for Firebase) and **Firebase App Check** back to the direct client-side **`google_generative_ai`** SDK.

## User Review Required

> [!CAUTION]
> **Security Warning**: By moving the API key back into the client-side code, it will be embedded in your app's binary. This makes it vulnerable to extraction by anyone who downloads your APK or IPA. This approach is only recommended for private development and testing with trusted users.

## Proposed Changes

### 1. Dependency Management
#### [MODIFY] [pubspec.yaml](file:///home/tamizharasan/flutterProjects/nus_nus_updated/pubspec.yaml)
- Remove `firebase_ai`.
- Remove `firebase_app_check`.
- Re-add **`google_generative_ai: ^0.4.7`**.

### 2. App Initialization Cleanup
#### [MODIFY] [main.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/main.dart)
- Remove the `firebase_app_check` import.
- Delete the `FirebaseAppCheck.instance.activate` block from the `main()` function.

### 3. AI Service Restoration
#### [MODIFY] [gemini_ai_service.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/services/gemini_ai_service.dart)
- Revert imports from `firebase_ai` back to `google_generative_ai`.
- Re-embed your API key directly in the class.
- Refactor `parseBillWithVision` and `queryAppState` to use the `google_generative_ai` syntax:
  - Use `GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey, systemInstruction: ...)`
  - Revert `InlineDataPart` to `DataPart`.
  - Revert `FirebaseAI.googleAI().inlineData()` back to standard multimodal handling.

## Verification Plan

### Manual Verification
1. **Vision Test**: Verify that uploading a receipt still results in a correct JSON split calculation.
2. **Chat Test**: Verify that the "Ask Anything" mode correctly answers questions about your expenses.
3. **No App Check**: Verify the app builds and runs without requiring debug tokens or reCAPTCHA setup.
