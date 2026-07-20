import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/balances_tab.dart';
import '../widgets/header_bar.dart';
import '../widgets/ledger_tab.dart';

class SplitHomeScreen extends StatelessWidget {
  const SplitHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final totalSpent = context.select<SplitProvider, double>(
      (p) => p.totalSpent,
    );

    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              HeaderBar(totalSpent: totalSpent),
              const TabBar(
                labelColor: AppColors.brassSoft,
                unselectedLabelColor: AppColors.slate,
                indicatorColor: AppColors.brass,
                tabs: [
                  Tab(text: 'Ledger'),
                  Tab(text: 'Balances'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    LedgerTab(),
                    BalancesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
