# Code Quality & Logic Analysis: Nus·Nus (Splitwise Clone)

I have performed a comprehensive review of the codebase, focusing on the core data models, calculation logic, and synchronization patterns.

## Summary of Findings

The app's architecture is robust and follows modern Android/Flutter best practices for data consistency and real-time synchronization. The "never-mutate-history" approach for settlements is particularly well-implemented.

### 1. Calculation Engine (`SettlementCalculator`)
The four-stage calculation pipeline is clean and mathematically sound:
- **Resilience**: Using signed `LedgerEntry` objects allows settlements to offset debts naturally without needing to edit past expenses.
- **Rounding Accuracy**: `SplitProvider._buildSplitMap` correctly handles cent-rounding by allocating the remainder to the first participant, ensuring that `sum(shares) == total` always holds true.
- **Optimization**: The greedy algorithm in `computeSettlement` correctly produces the minimum number of transfers required to zero out all balances.

### 2. Group Management & Soft-Deletion
- **Integrity**: The archiving logic for members with history is excellent. It preserves historical balance correctness while keeping the "active" roster clean.
- **ID Management**: Using `int` for person IDs within a group and `String` for globally unique Firestore IDs is a good balance of performance and uniqueness.

### 3. Data Sync & Security
- **Performance**: Using a subcollection for expenses (`groups/{id}/expenses`) is the correct choice to avoid Firestore's 1MB document limit and write-contention issues.
- **Security**: The recommended Firestore rules correctly enforce owner-only permissions for critical actions (renaming, deleting, settling up) while allowing all members to contribute data.

---

## 🧐 Technical Observations & Best Practices

| Component | Observation | Status |
| :--- | :--- | :--- |
| **Rounding** | Consistently uses `.round()` and 2-decimal formatting to avoid floating-point drift. | ✅ Solid |
| **Audit Trail** | `addedBy` field on expenses tracks contribution even when edited by owner. | ✅ Good |
| **Identity** | `linkedUserId` correctly maps local members to registered accounts. | ✅ Solid |
| **Cross-Group** | `myBalancesByPerson` correctly aggregates your stand with others across groups. | ✅ Accurate |

---

## ⚠️ Small Refinement Suggestions

While the logic is correct, here are a few tiny improvements you might consider:

### 1. Unique ID Safety
In `SplitProvider.myBalancesByPerson`, if two people have the same name and neither is a registered user, they will be merged in the "Overview" tab.
> [!TIP]
> This is a rare edge case, but using `uid` as the primary key and `name` only as a secondary identifier (as you already do) is the best way to handle this.

### 2. Owner Safety
Currently, an owner could theoretically "archive" themselves from their own group if they have history.
> [!NOTE]
> The UI currently prevents this by not showing the "Remove" icon on the owner's own chip, but you could add a check in `SplitProvider.removePerson` to explicitly prevent `id == 1` from being removed if you want extra safety.

### 3. Firestore Rules
Ensure you have updated your rules to include the `expenses` subcollection as discussed in the previous step. Without this, the app will show expenses as 0 (due to permission errors).

---

## Conclusion
**The code is production-ready for its intended use case.** The logic for splits, settlements, and balances is correct and matches the behavior of a professional splitting app like Splitwise.
