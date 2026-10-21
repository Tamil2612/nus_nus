import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../data/firestore_repository.dart';
import '../models/settlement_record.dart';
import '../providers/split_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import 'app_dialog.dart';

/// Bottom sheet listing the current group's recorded settlements, with an
/// Undo action for the two people involved in each one.
///
/// Undo is how a creditor disputes a payment the debtor recorded (or how
/// either person fixes a settlement recorded by mistake). Undone settlements
/// stay in the list, marked as undone, so the history is never rewritten.
class SettlementHistorySheet extends StatelessWidget {
  const SettlementHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => ChangeNotifierProvider<SplitProvider>.value(
        value: context.read<SplitProvider>(),
        child: const SettlementHistorySheet(),
      ),
    );
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return 'Just now';
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _confirmUndo(
    BuildContext context,
    SplitProvider provider,
    SettlementRecord record,
    String description,
  ) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      icon: Icons.undo_rounded,
      iconColor: AppColors.rust,
      title: 'Undo this settlement?',
      message:
          '$description\n\nThe shares it covered become unpaid again and '
          'balances go back to what they were before. If it was recorded in '
          'several groups, all of them are undone together.',
      confirmText: 'Undo settlement',
      confirmColor: AppColors.rust,
    );
    if (confirmed != true) return;

    final error =
        await provider.revertSettlement(record.groupId, record.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Settlement undone.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitProvider>();
    final group = provider.currentGroup;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settlement history',
                  style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink)),
              SizedBox(height: 4.h),
              Text(
                'Payments recorded in this group. Either person in a '
                'settlement can undo it.',
                style: TextStyle(fontSize: 12.sp, color: AppColors.slate),
              ),
              SizedBox(height: 12.h),
              if (group == null)
                const Text('Select a group first.')
              else
                Flexible(
                  child: StreamBuilder<List<SettlementRecord>>(
                    stream:
                        FirestoreRepository.instance.watchSettlements(group.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.h),
                          child: const Text(
                              'Could not load the settlement history.'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final records = snapshot.data!;
                      if (records.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.h),
                          child: const Text('No settlements recorded yet.'),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: records.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 16.h,
                            color: AppColors.slate.withValues(alpha: 0.2)),
                        itemBuilder: (context, i) {
                          final r = records[i];
                          final from = provider.personById(r.fromId)?.name ??
                              'Someone';
                          final to =
                              provider.personById(r.toId)?.name ?? 'Someone';
                          final description =
                              '$from paid $to ${fmtCurrency(r.amount, r.currency)}';
                          final canUndo = r.canBeUndoneBy(provider.uid);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      description,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w800,
                                        color: r.reverted
                                            ? AppColors.slate
                                            : AppColors.ink,
                                        decoration: r.reverted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      [
                                        _formatDate(r.createdAt),
                                        if (r.offsetCents > 0)
                                          '${fmtCurrency(r.offsetAmount, r.currency)} offset against opposing debts',
                                        if (r.reverted) 'UNDONE',
                                      ].join(' • '),
                                      style: TextStyle(
                                          fontSize: 11.sp,
                                          color: AppColors.slate),
                                    ),
                                  ],
                                ),
                              ),
                              if (canUndo)
                                TextButton(
                                  onPressed: () => _confirmUndo(
                                      context, provider, r, description),
                                  child: const Text('Undo',
                                      style: TextStyle(color: AppColors.rust)),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
