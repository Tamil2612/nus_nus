import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'common_atoms.dart';

class BalancesTab extends StatelessWidget {
  const BalancesTab({super.key});

  Future<void> _confirmSettle(
    BuildContext context,
    SplitProvider provider,
    int fromId,
    int toId,
    double amount,
  ) async {
    final from = provider.personById(fromId);
    final to = provider.personById(toId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Record settlement?',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
        content: Text(
          'This records that ${from?.name ?? '?'} paid ${to?.name ?? '?'} '
          '${fmtCurrency(amount, provider.currentGroup?.currency ?? 'AED')} outside the app. It just updates the ledger — '
          'no money actually moves.',
          style: const TextStyle(color: AppColors.slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.slate)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.solidButton.copyWith(
              backgroundColor: WidgetStateProperty.all(AppColors.sage),
            ),
            child: const Text('Mark as settled'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final error = provider.settleUp(fromId, toId, amount);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Settled up — balances updated.'),
        backgroundColor: error != null ? AppColors.rust : AppColors.sage,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    
    // Calculate totals for summary card
    double totalOwedByYou = 0;
    double totalOwedToYou = 0;
    
    final pairs = provider.pairBalances;
    // For this group specific summary: find the Person linked to the
    // signed-in user in *this* group. Deliberately does NOT fall back to
    // "some other member" if we're not linked here — that would silently
    // show a stranger's balance as if it were yours.
    final currentGroup = provider.currentGroup;
    Person? myPerson;
    if (currentGroup != null) {
      for (final p in currentGroup.members) {
        if (p.linkedUserId == provider.uid) {
          myPerson = p;
          break;
        }
      }
    }
    final myId = myPerson?.id;

    for (final pb in pairs) {
      if (pb.debtorId == myId) totalOwedByYou += pb.owedAmount;
      if (pb.creditorId == myId) totalOwedToYou += pb.owedAmount;
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card (Image 1 style)
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              fmtCurrency(totalOwedByYou, currentGroup?.currency ?? 'AED'),
                              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: AppColors.rust),
                            ),
                            4.verticalSpace,
                            Text('Owed by you', style: TextStyle(fontSize: 12.sp, color: AppColors.slate, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40.h, color: AppColors.line),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              fmtCurrency(totalOwedToYou, currentGroup?.currency ?? 'AED'),
                              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: AppColors.sage),
                            ),
                            4.verticalSpace,
                            Text('Owed to you', style: TextStyle(fontSize: 12.sp, color: AppColors.slate, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                24.verticalSpace,
                
                if (totalOwedByYou > 0) ...[
                  Text('OWED BY YOU', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: AppColors.paper, letterSpacing: 1.2)),
                  12.verticalSpace,
                  ...pairs.where((pb) => pb.debtorId == myId).map((pb) {
                    final to = provider.personById(pb.creditorId!);
                    return _BalanceTile(
                      person: to!,
                      amount: pb.owedAmount,
                      currency: currentGroup?.currency ?? 'AED',
                      subtitle: 'unpaid balance',
                      isOwedByYou: true,
                    );
                  }),
                  24.verticalSpace,
                ],
                
                if (totalOwedToYou > 0) ...[
                  Text('OWED TO YOU', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: AppColors.paper, letterSpacing: 1.2)),
                  12.verticalSpace,
                  ...pairs.where((pb) => pb.creditorId == myId).map((pb) {
                    final from = provider.personById(pb.debtorId!);
                    return _BalanceTile(
                      person: from!,
                      amount: pb.owedAmount,
                      currency: currentGroup?.currency ?? 'AED',
                      subtitle: 'is due to pay you',
                      isOwedByYou: false,
                      onSettle: () => _confirmSettle(context, provider, pb.debtorId!, pb.creditorId!, pb.owedAmount),
                    );
                  }),
                ],
                
                if (myId == null)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60.h),
                      child: Column(
                        children: [
                          Icon(Icons.help_outline, color: AppColors.slate, size: 48.r),
                          12.verticalSpace,
                          const EmptyHint(
                              "You're not linked to a member in this group yet, "
                              "so your personal balance can't be shown here."),
                        ],
                      ),
                    ),
                  )
                else if (totalOwedByYou == 0 && totalOwedToYou == 0)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60.h),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppColors.sage, size: 48.r),
                          12.verticalSpace,
                          const EmptyHint('No active balances. Everything is settled!'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Bottom Action Button — only settles *your own* debts, never an
        // arbitrary pair in the group that may have nothing to do with you.
        if (myId != null && pairs.any((pb) => pb.debtorId == myId))
          Padding(
            padding: EdgeInsets.all(16.w),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final myDebt = pairs.firstWhere((pb) => pb.debtorId == myId);
                  _confirmSettle(context, provider, myDebt.debtorId!,
                      myDebt.creditorId!, myDebt.owedAmount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brass,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                child: Text('Settle a debt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
              ),
            ),
          ),
      ],
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final Person person;
  final double amount;
  final String currency;
  final String subtitle;
  final bool isOwedByYou;
  final VoidCallback? onSettle;

  const _BalanceTile({
    required this.person,
    required this.amount,
    required this.currency,
    required this.subtitle,
    required this.isOwedByYou,
    this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: person.color,
            child: Text(
              person.name[0].toUpperCase(),
              style: TextStyle(fontSize: 14.sp, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          16.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                Text(
                  subtitle, 
                  style: TextStyle(fontSize: 11.sp, color: AppColors.slate, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtCurrency(amount, currency),
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: AppColors.ink),
              ),
              if (onSettle != null)
                GestureDetector(
                  onTap: onSettle,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      'SETTLE →',
                      style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: AppColors.sage),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
