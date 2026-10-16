import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/split_provider.dart';
import '../screens/expense_detail_screen.dart';
import '../screens/group_detail_screen.dart';
import '../theme/app_colors.dart';
import 'notification_service.dart';

/// Lets code outside the widget tree (push handlers) show a banner and
/// open screens. Both are attached to the MaterialApp in main.dart.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

StreamSubscription<PushEvent>? _pushSub;

/// Call once at startup (before runApp).
void registerPushNavigation() {
  _pushSub ??= NotificationService.instance.events.listen(_onPushEvent);
}

void _onPushEvent(PushEvent event) {
  switch (event.kind) {
    case PushEventKind.opened:
      _openFromPush(event.data);
    case PushEventKind.foreground:
      _showForegroundBanner(event);
  }
}

/// Android doesn't draw a notification while the app is open, so show an
/// in-app banner instead. (iOS shows its own system banner — see
/// NotificationService.initialize — so doing this there would show it twice.)
void _showForegroundBanner(PushEvent event) {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;
  final title = event.title ?? '';
  final body = event.body ?? '';
  if (title.isEmpty && body.isEmpty) return;

  final notificationType = event.data['type'];
  final opensExpense = notificationType == 'expense_created';
  final opensGroupChat = notificationType == 'group_message';
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.inkSoft,
        duration: const Duration(seconds: 6),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.paper,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (body.isNotEmpty)
              Text(body, style: const TextStyle(color: AppColors.paper)),
          ],
        ),
        action: (opensExpense || opensGroupChat)
            ? SnackBarAction(
                label: 'VIEW',
                textColor: AppColors.brass,
                onPressed: () => _openFromPush(event.data),
              )
            : null,
      ),
    );
}

int _openGeneration = 0;

/// Opens the expense a "new split" notification is about.
///
/// When the app was closed, the tap arrives before the user's groups and
/// expenses have loaded, so this waits (up to ~20s) for the expense to show
/// up instead of giving up immediately.
Future<void> _openFromPush(Map<String, String> data) async {
  final notificationType = data['type'];
  if (notificationType != 'expense_created' && notificationType != 'group_message') return;
  final groupId = data['groupId'];
  final expenseId = data['expenseId'];
  if (groupId == null || groupId.isEmpty) return;
  if (notificationType == 'expense_created' && (expenseId == null || expenseId.isEmpty)) return;

  final generation = ++_openGeneration;
  for (var attempt = 0; attempt < 50; attempt++) {
    if (generation != _openGeneration) return; // a newer tap took over
    final context = appNavigatorKey.currentContext;
    if (context != null) {
      final provider = Provider.of<SplitProvider>(context, listen: false);
      final groupExists = provider.groups.any((group) => group.id == groupId);
      if (groupExists) {
        provider.selectGroup(groupId);
        if (notificationType == 'group_message') {
          appNavigatorKey.currentState?.push(
            MaterialPageRoute<void>(builder: (_) => const GroupDetailScreen()),
          );
          return;
        }
        final expense = _findExpense(provider, groupId, expenseId ?? '');
        if (expense != null) {
          appNavigatorKey.currentState?.push(
            MaterialPageRoute<void>(builder: (_) => ExpenseDetailScreen(expense: expense)),
          );
          return;
        }
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  debugPrint('Push target in group $groupId never became available '
      '(signed out, or no longer a member?).');
}

Expense? _findExpense(SplitProvider provider, String groupId, String expenseId) {
  for (final group in provider.groups) {
    if (group.id != groupId) continue;
    for (final expense in group.expenses) {
      if (expense.id == expenseId) return expense;
    }
  }
  return null;
}
