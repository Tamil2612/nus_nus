import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import 'common_atoms.dart';

/// Shows exactly where the *signed-in user* personally stands — never
/// anyone else's balance with anyone else — combined across every group
/// they're a participant in. Split into two explicit lists ("owed to
/// you" / "you owe") rather than one merged one, so it's immediately
/// obvious which direction each amount goes.
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final mine = provider.myBalancesByPerson();
    final owedToYou = mine.where((o) => o.amount > 0.005).toList();
    final youOwe = mine.where((o) => o.amount < -0.005).toList();
    final totalOwedToYou =
        owedToYou.fold(0.0, (s, o) => s + o.amount);
    final totalYouOwe =
        youOwe.fold(0.0, (s, o) => s + o.amount.abs());

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Grand-total summary card
          _panel(
            child: Row(
              children: [
                Expanded(
                  child: _summaryStat(
                    label: 'OWED TO YOU',
                    amount: totalOwedToYou,
                    color: AppColors.sage,
                  ),
                ),
                Container(width: 1, height: 40.h, color: AppColors.line),
                Expanded(
                  child: _summaryStat(
                    label: 'YOU OWE',
                    amount: totalYouOwe,
                    color: AppColors.rust,
                  ),
                ),
              ],
            ),
          ),
          16.verticalSpace,
          _PersonListSection(
            title: 'OWED TO YOU',
            entries: owedToYou,
            color: AppColors.sage,
            emptyHint: 'Nobody owes you anything right now.',
          ),
          24.verticalSpace,
          _PersonListSection(
            title: 'YOU OWE',
            entries: youOwe,
            color: AppColors.rust,
            emptyHint: "You don't owe anyone anything right now.",
          ),
          80.verticalSpace,
        ],
      ),
    );
  }

  Widget _summaryStat(
      {required String label, required double amount, required Color color}) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10.sp,
                letterSpacing: 1.2,
                color: AppColors.slate,
                fontWeight: FontWeight.w900)),
        6.verticalSpace,
        Text(
          fmtAed(amount),
          style: TextStyle(
              fontSize: 18.sp, fontWeight: FontWeight.w900, color: color),
        ),
      ],
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

class _PersonListSection extends StatelessWidget {
  final String title;
  final List<OverallBalance> entries;
  final Color color;
  final String emptyHint;

  const _PersonListSection({
    required this.title,
    required this.entries,
    required this.color,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w900,
            color: AppColors.paper,
            letterSpacing: 1.2,
          ),
        ),
        12.verticalSpace,
        if (entries.isEmpty)
          EmptyHint(emptyHint)
        else
          ...entries.map((o) => _ExpandablePersonCard(entry: o, color: color)),
      ],
    );
  }
}

class _ExpandablePersonCard extends StatefulWidget {
  final OverallBalance entry;
  final Color color;

  const _ExpandablePersonCard({required this.entry, required this.color});

  @override
  State<_ExpandablePersonCard> createState() => _ExpandablePersonCardState();
}

class _ExpandablePersonCardState extends State<_ExpandablePersonCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: _expanded
              ? [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: widget.color.withValues(alpha: 0.8),
                  child: Text(
                    widget.entry.name.isNotEmpty ? widget.entry.name[0].toUpperCase() : '?',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                ),
                16.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.entry.name,
                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      Text(
                        'across ${widget.entry.groupCount} group${widget.entry.groupCount == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 11.sp, color: AppColors.slate, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmtAed(widget.entry.amount.abs()),
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900, color: widget.color),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16.r,
                      color: AppColors.slate,
                    ),
                  ],
                ),
              ],
            ),
            if (_expanded) ...[
              Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: const Divider(color: AppColors.line, height: 1),
              ),
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Column(
                  children: widget.entry.breakdown.map((b) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          b.groupName,
                          style: TextStyle(fontSize: 12.sp, color: AppColors.slate, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          fmtAed(b.amount.abs()),
                          style: TextStyle(
                            fontSize: 12.sp, 
                            color: b.amount > 0 ? AppColors.sage : AppColors.rust,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
