# Implementation Plan: Soft-Removal of Group Members

Implement a feature to allow group owners to remove members from a group using a "soft-delete" approach (archiving). This ensures that historical expense data remains accurate while hiding removed members from current pickers and the active roster.

## User Review Required

> [!NOTE]
> Members with expense history will be **archived** (hidden from new expenses but kept for history), while members with no history will be fully removed from the group document.

## Proposed Changes

### [Component] SplitProvider
#### [MODIFY] [split_provider.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/providers/split_provider.dart)
- The existing `removePerson(int id)` method already implements the archiving logic. No functional changes needed here, but I will double-check its integrity.

### [Component] LedgerTab (UI)
#### [MODIFY] [ledger_tab.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/widgets/ledger_tab.dart)
- **`_confirmRemovePerson`**: Add a private helper method to show a confirmation dialog before removal, explaining the difference between full removal and archiving (as previously requested).
- **`_GroupRoster`**:
  - Add an `onRemove` callback: `Function(Person)? onRemove`.
  - Update the member chips to include a small delete icon (visible only to the owner).
  - Tapping the delete icon will trigger the `_confirmRemovePerson` dialog.
- **`LedgerTab` State**: Pass the new removal logic to the `_GroupRoster` widget.

## Verification Plan

### Manual Verification
1. **Remove Member with History**:
   - Add an expense involving Member A.
   - Attempt to remove Member A.
   - Verify the dialog warns that they have history and will be "hidden" but kept for records.
   - Confirm and verify they no longer appear in the "MEMBERS" list or new expense pickers.
2. **Remove Member without History**:
   - Add Member B.
   - Attempt to remove Member B immediately.
   - Verify the dialog simply asks to remove them completely.
   - Confirm and verify they are gone from the group.
3. **Owner Check**: Verify that a non-owner member cannot see the remove icons.
