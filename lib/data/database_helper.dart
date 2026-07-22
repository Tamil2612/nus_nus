import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/person.dart';

/// On-device persistence for the whole app state.
///
/// Strategy: rather than hand-writing granular INSERT/UPDATE/DELETE calls
/// for every possible mutation (add person, remove expense, rename group,
/// ...), we snapshot the *entire* in-memory state to disk after every
/// change: wipe the four tables and re-insert everything in one
/// transaction. At the scale of a personal split-expenses app (a handful
/// of groups, dozens of people/expenses) this is fast, and it's much
/// harder to get subtly wrong than incremental sync logic.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nus_nus.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE groups (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE people (
            id INTEGER PRIMARY KEY,
            group_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            color INTEGER NOT NULL,
            archived INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY,
            group_id INTEGER NOT NULL,
            desc TEXT NOT NULL,
            amount REAL NOT NULL,
            payer_id INTEGER NOT NULL,
            is_settlement INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE expense_splits (
            expense_id INTEGER NOT NULL,
            person_id INTEGER NOT NULL,
            share REAL NOT NULL,
            PRIMARY KEY (expense_id, person_id)
          )
        ''');
      },
    );
  }

  /// Wipes and rewrites the whole database from the given groups.
  Future<void> saveAll(List<Group> groups) async {
    final db = await _database;
    try {
      await db.transaction((txn) async {
        await txn.delete('expense_splits');
        await txn.delete('expenses');
        await txn.delete('people');
        await txn.delete('groups');

        final groupBatch = txn.batch();
        final peopleBatch = txn.batch();
        final expenseBatch = txn.batch();
        final splitBatch = txn.batch();

        for (final g in groups) {
          groupBatch.insert('groups', {'id': g.id, 'name': g.name});

          for (final p in g.members) {
            peopleBatch.insert('people', {
              'id': p.id,
              'group_id': g.id,
              'name': p.name,
              'color': p.color.value,
              'archived': p.archived ? 1 : 0,
            });
          }

          for (final e in g.expenses) {
            expenseBatch.insert('expenses', {
              'id': e.id,
              'group_id': g.id,
              'desc': e.desc,
              'amount': e.amount,
              'payer_id': e.payerId,
              'is_settlement': e.isSettlement ? 1 : 0,
            });
            for (final entry in e.splitMap.entries) {
              splitBatch.insert('expense_splits', {
                'expense_id': e.id,
                'person_id': entry.key,
                'share': entry.value,
              });
            }
          }
        }

        await groupBatch.commit(noResult: true);
        await peopleBatch.commit(noResult: true);
        await expenseBatch.commit(noResult: true);
        await splitBatch.commit(noResult: true);
      });
    } catch (e, st) {
      debugPrint('DatabaseHelper.saveAll failed: $e\n$st');
    }
  }

  /// Loads everything back into a list of [Group] objects.
  Future<List<Group>> loadAll() async {
    final db = await _database;
    try {
      final groupRows = await db.query('groups');
      final peopleRows = await db.query('people');
      final expenseRows = await db.query('expenses');
      final splitRows = await db.query('expense_splits');

      final splitsByExpense = <int, Map<int, double>>{};
      for (final row in splitRows) {
        final expenseId = row['expense_id'] as int;
        final personId = row['person_id'] as int;
        final share = (row['share'] as num).toDouble();
        splitsByExpense.putIfAbsent(expenseId, () => {})[personId] = share;
      }

      final peopleByGroup = <int, List<Person>>{};
      for (final row in peopleRows) {
        final groupId = row['group_id'] as int;
        peopleByGroup.putIfAbsent(groupId, () => []).add(
              Person(
                id: row['id'] as int,
                name: row['name'] as String,
                color: Color(row['color'] as int),
                archived: (row['archived'] as int) == 1,
              ),
            );
      }

      final expensesByGroup = <int, List<Expense>>{};
      for (final row in expenseRows) {
        final groupId = row['group_id'] as int;
        final id = row['id'] as int;
        expensesByGroup.putIfAbsent(groupId, () => []).add(
              Expense(
                id: id,
                desc: row['desc'] as String,
                amount: (row['amount'] as num).toDouble(),
                payerId: row['payer_id'] as int,
                splitMap: splitsByExpense[id] ?? {},
                isSettlement: (row['is_settlement'] as int) == 1,
              ),
            );
      }

      return groupRows.map((row) {
        final id = row['id'] as int;
        return Group(
          id: id,
          name: row['name'] as String,
          members: peopleByGroup[id] ?? [],
          expenses: expensesByGroup[id] ?? [],
        );
      }).toList();
    } catch (e, st) {
      debugPrint('DatabaseHelper.loadAll failed: $e\n$st');
      return [];
    }
  }
}
