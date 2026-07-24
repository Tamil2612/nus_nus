# Implementation Plan: Cross-Group Overview Tab

Add a third tab called "Overview" to show aggregated balances across all groups, including a detailed group-by-group breakdown for each person.

## Proposed Changes

### [Component] SplitProvider
#### [MODIFY] [split_provider.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/providers/split_provider.dart)
- Update `OverallBalance` class to include a list of per-group contributions:
  ```dart
  class GroupContribution {
    final String groupName;
    final double amount;
    GroupContribution(this.groupName, this.amount);
  }
  ```
- Update `myBalancesByPerson()` to track which groups contribute to the total balance for each person.

### [Component] SplitHomeScreen
#### [MODIFY] [split_home_screen.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/screens/split_home_screen.dart)
- Restore the third tab in `DefaultTabController`.
- Add 'Overview' to the `TabBar`.
- Add `OverviewTab()` to the `TabBarView`.

### [Component] OverviewTab
#### [MODIFY] [overview_tab.dart](file:///home/tamizharasan/flutterProjects/nus_nus_updated/lib/widgets/overview_tab.dart)
- Redesign the UI to match the "Nus·Nus" theme (dark gradient background, paper cards).
- Implement an expandable card for each person in the overview:
  - Header: Person's name and total aggregated balance.
  - Expanded content: A list showing "In [Group Name]: [Amount]".
- Ensure high contrast and clear text legibility.

## Verification Plan

### Manual Verification
- Verify that a third tab "Overview" appears on the home screen.
- Verify that the summary at the top correctly shows "OWED TO YOU" and "YOU OWE" totals across all groups.
- Verify that clicking/expanding a person in the list shows exactly which groups the balance comes from.
- Verify theme consistency with Activity and Balances tabs.
