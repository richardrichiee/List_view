import 'package:list_view/core/db/app_database.dart';
import 'package:list_view/models/task_item.dart';

abstract interface class TaskRepository {
  Future<List<TaskItem>> getTasks();
  Future<int> createTask(TaskItem task);
  Future<void> updateTask(TaskItem task);
  Future<void> deleteTask(int id);
  Future<void> reorderTasks(List<TaskItem> tasks);
}

class SqfliteTaskRepository implements TaskRepository {
  SqfliteTaskRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<TaskItem>> getTasks() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tableName,
      orderBy: 'sortOrder ASC, id ASC',
    );
    return rows.map(TaskItem.fromMap).toList();
  }

  @override
  Future<int> createTask(TaskItem task) async {
    final db = await _appDatabase.database;
    return db.transaction((transaction) async {
      final result = await transaction.rawQuery(
        'SELECT COALESCE(MAX(sortOrder), -1) + 1 AS nextOrder '
        'FROM ${AppDatabase.tableName}',
      );
      final nextOrder = result.single['nextOrder'] as int;
      return transaction.insert(AppDatabase.tableName, {
        ...task.toMap(),
        'sortOrder': nextOrder,
      });
    });
  }

  @override
  Future<void> updateTask(TaskItem task) async {
    final id = task.id;
    if (id == null) {
      throw ArgumentError.value(task, 'task', 'An existing task needs an ID');
    }
    final db = await _appDatabase.database;
    final updatedRows = await db.update(
      AppDatabase.tableName,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updatedRows == 0) {
      throw StateError('Task $id no longer exists');
    }
  }

  @override
  Future<void> deleteTask(int id) async {
    final db = await _appDatabase.database;
    final deletedRows = await db.delete(
      AppDatabase.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (deletedRows == 0) {
      throw StateError('Task $id no longer exists');
    }
  }

  @override
  Future<void> reorderTasks(List<TaskItem> tasks) async {
    final db = await _appDatabase.database;
    await db.transaction((transaction) async {
      final batch = transaction.batch();
      for (var index = 0; index < tasks.length; index++) {
        final id = tasks[index].id;
        if (id == null) {
          throw ArgumentError.value(
            tasks[index],
            'tasks',
            'An existing task needs an ID',
          );
        }
        batch.update(
          AppDatabase.tableName,
          {'sortOrder': index},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
