import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

/// Shows exactly where the *signed-in user* personally stands — never
/// anyone else's balance with anyone else — combined across every group
/// they're a participant in. Provides a clear "You vs. Them" pairwise 
/// visual and the ability to settle all dues at once.
class PeopleTab extends StatelessWidget {
  const PeopleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final mine = provider.myBalancesByPerson();
    
    // Aggregated totals per currency
    final totalsOwedToYou = <String, double>{};
    final totalsYouOwe = <String, double>{};

    for (final o in mine) {
      o.currencyBalances.forEach((currency, amount) {
        if (amount > 0.005) {
          totalsOwedToYou[currency] = (totalsOwedToYou[currency] ?? 0) + amount;
        } else if (amount < -0.005) {
          totalsYouOwe[currency] = (totalsYouOwe[currency] ?? 0) + amount.abs();
        }
      });
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Grand-total summary card
          _panel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SummaryColumn(
                    label: 'OWED TO YOU',
                    totals: totalsOwedToYou,
                    color: AppColors.sage,
                  ),
                ),
                Container(width: 1, height: 60.h, color: AppColors.line),
                Expanded(
                  child: _SummaryColumn(
                    label: 'YOU OWE',
                    totals: totalsYouOwe,
                    color: AppColors.rust,
                  ),
                ),
              ],
            ),
          ),
          
          24.verticalSpace,
          
          if (mine.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 80.h),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 64.r, color: AppColors.slate.withValues(alpha: 0.3)),
                    16.verticalSpace,
                    Text(
                      'No people to show yet.\nStart splitting to see your standing!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.slate, fontSize: 14.sp),
                    ),
                  ],
                ),
              ),
            )
          else
            ...mine.map((o) => _ExpandablePairwiseCard(entry: o)),
          
          80.verticalSpace,
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String label;
  final Map<String, double> totals;
  final Color color;

  const _SummaryColumn({
    required this.label,
    required this.totals,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10.sp,
                letterSpacing: 1.2,
                color: AppColors.slate,
                fontWeight: FontWeight.w900)),
        8.verticalSpace,
        if (totals.isEmpty)
          Text('-', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: AppColors.slate))
        else
          ...totals.entries.map((e) => Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Text(
              fmtCurrency(e.value, e.key),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16.sp, fontWeight: FontWeight.w900, color: color),
            ),
          )),
      ],
    );
  }
}

class _ExpandablePairwiseCard extends StatefulWidget {
  final OverallBalance entry;

  const _ExpandablePairwiseCard({required this.entry});

  @override
  State<_ExpandablePairwiseCard> createState() => _ExpandablePairwiseCardState();
}

class _ExpandablePairwiseCardState extends State<_ExpandablePairwiseCard> {
  bool _expanded = false;
  bool _isSettling = false;

  Future<void> _onSettleAll(SplitProvider provider) async {
    setState(() => _isSettling = true);
    final errors = await provider.settlePairwise(widget.entry);
    if (!mounted) return;
    setState(() => _isSettling = false);

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some settlements failed: ${errors.first}'),
          backgroundColor: AppColors.rust,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All dues settled with this person!'),
          backgroundColor: AppColors.sage,
        ),
      );
      setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final provider = context.watch<SplitProvider>();
    
    // Check if user has permission to settle ANY of the groups in this breakdown.
    // Permission: Only the group owner OR the person being paid (creditor) can confirm.
    final canSettleAtLeastOne = entry.breakdown.any((contrib) {
      if (contrib.amount.abs() <= 0.005) return false;
      
      final isOwner = provider.groups.any((g) => g.id == contrib.groupId && g.ownerId == provider.uid);
      final isCreditor = contrib.amount > 0; // In OverallBalance context, positive = they owe you.
      
      return isOwner || isCreditor;
    });

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: _expanded
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                _MiniAvatar(name: 'YOU', color: AppColors.brass),
                Expanded(
                  child: Column(
                    children: entry.currencyBalances.entries.map((e) {
                      final currency = e.key;
                      final amount = e.value;
                      final owesYou = amount > 0.005;
                      final color = owesYou ? AppColors.sage : AppColors.rust;

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: Column(
                          children: [
                            Text(
                              fmtCurrency(amount.abs(), currency),
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w900,
                                color: color,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (owesYou) Icon(Icons.arrow_back, size: 14.r, color: color),
                                Container(
                                  height: 2.h,
                                  width: 40.w,
                                  color: color.withValues(alpha: 0.3),
                                ),
                                if (!owesYou) Icon(Icons.arrow_forward, size: 14.r, color: color),
                              ],
                            ),
                            Text(
                              owesYou ? 'owes you' : 'you owe',
                              style: TextStyle(fontSize: 10.sp, color: AppColors.slate, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                _MiniAvatar(name: entry.name, color: entry.currencyBalances.values.first > 0 ? AppColors.sage : AppColors.rust),
              ],
            ),

            if (_expanded) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: const Divider(color: AppColors.line, height: 1),
              ),
              
              // Per-Group Breakdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GROUP BREAKDOWN',
                    style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: AppColors.slate, letterSpacing: 1.1),
                  ),
                  12.verticalSpace,
                  ...entry.breakdown.map((b) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          b.groupName,
                          style: TextStyle(fontSize: 13.sp, color: AppColors.ink, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          fmtCurrency(b.amount.abs(), b.currency),
                          style: TextStyle(
                            fontSize: 13.sp, 
                            fontWeight: FontWeight.w800,
                            color: b.amount > 0 ? AppColors.sage : AppColors.rust,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
              
              20.verticalSpace,
              
              // Settle Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSettling || !canSettleAtLeastOne) ? null : () => _onSettleAll(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: AppColors.paper,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  child: _isSettling 
                    ? 16.verticalSpace
                    : Text(
                        canSettleAtLeastOne 
                          ? 'SETTLE ALL DUES WITH ${entry.name.toUpperCase()}'
                          : 'OTHER PERSON MUST CONFIRM SETTLEMENT', 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String name;
  final Color color;
  const _MiniAvatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 20.r,
          backgroundColor: color.withValues(alpha: 0.1),
          child: CircleAvatar(
            radius: 16.r,
            backgroundColor: color,
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        4.verticalSpace,
        SizedBox(
          width: 60.w,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}
