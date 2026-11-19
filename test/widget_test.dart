// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_view/data/task_repository.dart';
import 'package:list_view/models/task_item.dart';
import 'package:list_view/presentation/dashboard.dart';
import 'package:list_view/providers/task_provider.dart';

void main() {
  test('task reordering updates the provider task order', () async {
    final repository = FakeTaskRepository();
    repository.tasks.addAll([
      TaskItem(
        id: 2,
        title: 'Review pull request',
        description: '',
        isCompleted: false,
      ),
      TaskItem(
        id: 3,
        title: 'Prepare release notes',
        description: '',
        isCompleted: false,
      ),
    ]);
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final tasks = await container.read(taskListProvider.future);
    await container
        .read(taskListProvider.notifier)
        .reorderTasks(
          tasks: tasks,
          visibleTasks: tasks,
          oldIndex: 0,
          newIndex: 2,
        );

    expect(
      container
          .read(taskListProvider)
          .requireValue
          .map((task) => task.title)
          .toList(),
      ['Review pull request', 'Prepare release notes', 'Draft project brief'],
    );
  });

  testWidgets('dashboard supports task create, complete, edit, and delete', (
    WidgetTester tester,
  ) async {
    final repository = FakeTaskRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Dashboard()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Draft project brief'), findsOneWidget);
    expect(find.text('0 of 1 tasks completed'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'brief');
    await tester.pumpAndSettle();
    expect(find.text('Draft project brief'), findsOneWidget);
    expect(find.text('No tasks match "brief".'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Review pull request',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Check the latest changes',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(find.text('Review pull request'), findsOneWidget);
    expect(repository.tasks, hasLength(2));

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 tasks completed'), findsOneWidget);

    await tester.tap(find.byTooltip('Task options').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Review updated pull request',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Review updated pull request'), findsOneWidget);

    await tester.tap(find.byTooltip('Task options').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Review updated pull request'), findsNothing);
    expect(repository.tasks, hasLength(1));
  });
}

class FakeTaskRepository implements TaskRepository {
  final List<TaskItem> tasks = [
    TaskItem(
      id: 1,
      title: 'Draft project brief',
      description: 'Outline the project goals',
      isCompleted: false,
    ),
  ];
  int _nextId = 2;

  @override
  Future<int> createTask(TaskItem task) async {
    final id = _nextId++;
    tasks.add(task.copyWith(id: id));
    return id;
  }

  @override
  Future<void> deleteTask(int id) async {
    tasks.removeWhere((task) => task.id == id);
  }

  @override
  Future<List<TaskItem>> getTasks() async => List.of(tasks);

  @override
  Future<void> updateTask(TaskItem task) async {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) throw StateError('Task not found');
    tasks[index] = task;
  }

  @override
  Future<void> reorderTasks(List<TaskItem> reorderedTasks) async {
    final order = {
      for (var index = 0; index < reorderedTasks.length; index++)
        reorderedTasks[index].id: index,
    };
    tasks.sort((a, b) => order[a.id]!.compareTo(order[b.id]!));
  }
}
