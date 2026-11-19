import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:list_view/core/db/app_database.dart';
import 'package:list_view/data/task_repository.dart';
import 'package:list_view/models/task_item.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return SqfliteTaskRepository(AppDatabase());
});

final taskListProvider =
    AsyncNotifierProvider<TaskListNotifier, List<TaskItem>>(
      TaskListNotifier.new,
    );

class TaskListNotifier extends AsyncNotifier<List<TaskItem>> {
  TaskRepository get _repository => ref.read(taskRepositoryProvider);

  @override
  Future<List<TaskItem>> build() => _repository.getTasks();

  Future<void> addTask({
    required String title,
    required String description,
  }) async {
    await _runMutation(() async {
      await _repository.createTask(
        TaskItem(title: title, description: description, isCompleted: false),
      );
    });
  }

  Future<void> updateTask(TaskItem task) async {
    await _runMutation(() => _repository.updateTask(task));
  }

  Future<void> toggleTask(TaskItem task) async {
    await updateTask(task.copyWith(isCompleted: !task.isCompleted));
  }

  Future<void> deleteTask(TaskItem task) async {
    final id = task.id;
    if (id == null) {
      throw ArgumentError.value(task, 'task', 'An existing task needs an ID');
    }
    await _runMutation(() => _repository.deleteTask(id));
  }

  Future<void> reorderTasks({
    required List<TaskItem> tasks,
    required List<TaskItem> visibleTasks,
    required int oldIndex,
    required int newIndex,
  }) async {
    if (oldIndex == newIndex) return;

    final reorderedVisible = List<TaskItem>.of(visibleTasks);
    final movedTask = reorderedVisible.removeAt(oldIndex);
    reorderedVisible.insert(newIndex, movedTask);
    final visibleIds = reorderedVisible.map((task) => task.id).toSet();
    var visibleIndex = 0;
    final reorderedAll = tasks.map((task) {
      if (visibleIds.contains(task.id)) {
        return reorderedVisible[visibleIndex++];
      }
      return task;
    }).toList();

    await _runMutation(() => _repository.reorderTasks(reorderedAll));
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<TaskItem>>();
    state = await AsyncValue.guard(_repository.getTasks);
  }

  Future<void> _runMutation(Future<void> Function() mutation) async {
    state = const AsyncLoading<List<TaskItem>>();
    state = await AsyncValue.guard(() async {
      await mutation();
      return _repository.getTasks();
    });
  }
}
