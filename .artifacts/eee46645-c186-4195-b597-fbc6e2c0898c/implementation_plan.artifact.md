# Implementation Plan: Finalize Security & Logic Consistency

Ensure that the new security model is deployable and that all documentation correctly reflects the implemented features.

## User Review Required

> [!IMPORTANT]
> I have confirmed that your logic changes in the app are correct. However, your `firestore.rules` will not be uploaded to Firebase during deployment because they are not yet referenced in `firebase.json`. I will add this configuration for you.

## Proposed Changes

### 1. Firebase Configuration
#### [MODIFY] [firebase.json](file:///home/tamizharasan/flutterProjects/nus_nus_updated/firebase.json)
- Add the `firestore` configuration pointing to the `firestore.rules` file. This is required for `firebase deploy` to work.

### 2. Documentation Sync
#### [MODIFY] [README.md](file:///home/tamizharasan/flutterProjects/nus_nus_updated/README.md)
- Replace the default Flutter boilerplate with a concise description of the app and a "Security Rules" section containing the rules you created. This fixes the dangling references in the code.

#### [MODIFY] [member_directory_repository.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/data/member_directory_repository.dart)
- Update the comment to point to `firestore.rules` instead of `README.md` for the authoritative rule source.

### 3. Logic Refinement
#### [MODIFY] [balances_tab.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/widgets/balances_tab.dart)
- Change the "Settle all dues" button text to "Settle one due" (or similar) to accurately reflect that it currently settles only the first found debt, or improve it to handle multiple debts if you'd like. (I'll stick to a text update for accuracy first).

## Verification Plan

### Manual Verification
1. Run `firebase deploy`. Verify that it now reports "Deploying firestore...".
2. Check `README.md` and verify it contains the security documentation.
3. Open the Balances tab and verify the button text accurately describes the action.
