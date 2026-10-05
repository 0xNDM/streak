import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:streak/core/database/data_location.dart';
import 'package:streak/core/utils/app_dirs.dart';
import 'package:streak/features/habits/data/category.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/habits/data/habit_note.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/data/todo_tag.dart';

class LocalStore {
  const LocalStore._();

  static const _habitsBox = 'habits';
  static const _settingsBox = 'settings';
  static const _categoriesBox = 'categories';
  static const _notesBox = 'notes';
  static const _focusBox = 'focus';
  static const _todosBox = 'todos';
  static const _todoTagsBox = 'todo_tags';

  static late Box _habits;
  static late Box _settings;
  static late Box _categories;
  static late Box _notes;
  static late Box _focus;
  static late Box _todos;
  static late Box _todoTags;

  static int _writing = 0;
  static String _habitsStamp = '';

  static bool get isWriting => _writing > 0;

  static Future<T> guardWrites<T>(Future<T> Function() action) async {
    _writing++;
    try {
      return await action();
    } finally {
      _writing--;
    }
  }

  static Future<void> init() async {
    if (isMobile) {
      await Hive.initFlutter();
    } else {
      Hive.init((await appDataDir()).path);
    }
    _habits = await Hive.openBox(_habitsBox);
    _habitsStamp = _stampOf(_habits);
    _settings = await Hive.openBox(_settingsBox);
    _categories = await Hive.openBox(_categoriesBox);
    _notes = await Hive.openBox(_notesBox);
    _focus = await Hive.openBox(_focusBox);
    _todos = await Hive.openBox(_todosBox);
    _todoTags = await Hive.openBox(_todoTagsBox);
    final movedFrom = DataLocation.rewriteFrom;
    if (movedFrom != null) await _followMove(movedFrom);
  }

  static Future<void> _followMove(String from) async {
    final to = (await appDataDir()).path;
    for (final box in [
      _habits,
      _settings,
      _categories,
      _notes,
      _focus,
      _todos,
      _todoTags,
    ]) {
      for (final key in box.keys.toList()) {
        final value = box.get(key);
        final moved = DataLocation.rewrite(value, from, to);
        if (!identical(moved, value)) await box.put(key, moved);
      }
      await box.flush();
    }
    DataLocation.finish();
  }

  static List<Todo> readTodos() {
    final result = <Todo>[];
    for (final raw in _todos.values) {
      try {
        result.add(Todo.fromMap(Map<String, dynamic>.from(raw as Map)));
      } catch (e) {
        debugPrint('Skipped an unreadable to-do: $e');
      }
    }
    return result;
  }

  static Future<void> writeTodo(Todo todo) => _todos.put(todo.id, todo.toMap());

  static Future<void> writeTodos(Iterable<Todo> todos) =>
      _todos.putAll({for (final todo in todos) todo.id: todo.toMap()});

  static Future<void> removeTodo(String id) => _todos.delete(id);

  static Future<void> removeTodos(Iterable<String> ids) => _todos.deleteAll(ids);

  static List<TodoTag> readTodoTags() {
    final result = <TodoTag>[];
    for (final raw in _todoTags.values) {
      try {
        result.add(TodoTag.fromJson(raw as String));
      } catch (e) {
        debugPrint('Skipped an unreadable tag: $e');
      }
    }
    return result;
  }

  static Future<void> writeTodoTag(TodoTag tag) =>
      _todoTags.put(tag.id, tag.toJson());

  static Future<void> removeTodoTag(String id) => _todoTags.delete(id);

  static List<FocusSession> readFocusSessions() {
    final result = <FocusSession>[];
    for (final raw in _focus.values) {
      result.add(FocusSession.fromMap(Map<String, dynamic>.from(raw as Map)));
    }
    return result;
  }

  static Future<void> writeFocusSession(FocusSession session) =>
      _focus.put(session.id, session.toMap());

  static Future<void> removeFocusSessions(Iterable<String> ids) async {
    for (final id in ids) {
      await _focus.delete(id);
    }
  }

  static Future<void> removeFocusFor(String habitId) async {
    final ids = readFocusSessions()
        .where((s) => s.habitId == habitId)
        .map((s) => s.id)
        .toList();
    for (final id in ids) {
      await _focus.delete(id);
    }
  }

  static List<HabitNote> readNotes() {
    final result = <HabitNote>[];
    for (final raw in _notes.values) {
      result.add(HabitNote.fromMap(Map<String, dynamic>.from(raw as Map)));
    }
    return result;
  }

  static Future<void> writeNote(HabitNote note) =>
      _notes.put(note.id, note.toMap());

  static Future<void> removeNote(String id) => _notes.delete(id);

  static Future<void> removeNotesFor(String habitId) async {
    final ids = readNotes()
        .where((n) => n.habitId == habitId)
        .map((n) => n.id)
        .toList();
    for (final id in ids) {
      await _notes.delete(id);
    }
  }

  static Map<String, Habit> readHabits() {
    final result = <String, Habit>{};
    for (final raw in _habits.values) {
      try {
        final habit = Habit.fromJson(raw as String);
        result[habit.id] = habit;
      } catch (e) {
        debugPrint('Skipped an unreadable habit: $e');
      }
    }
    return result;
  }

  static Habit? habit(String id) {
    try {
      final raw = _habits.get(id);
      return raw is String ? Habit.fromJson(raw) : null;
    } catch (_) {
      return null;
    }
  }

  static String? habitName(String id) => habit(id)?.name;

  static Future<void> writeHabit(Habit habit) async {
    await _habits.put(habit.id, habit.toJson());
    _habitsStamp = _stampOf(_habits);
  }

  static String _stampOf(Box box) {
    final path = box.path;
    if (path == null) return '';
    try {
      final stat = File(path).statSync();
      return '${stat.size}:${stat.modified.microsecondsSinceEpoch}';
    } catch (_) {
      return '';
    }
  }

  static bool get habitsChangedElsewhere {
    final stamp = _stampOf(_habits);
    return stamp.isEmpty || stamp != _habitsStamp;
  }

  static Future<void> removeHabit(String id) => _habits.delete(id);

  static Future<void> reloadHabits() async {
    if (_writing > 0) return;
    if (_habits.isOpen) await _habits.close();
    _habits = await Hive.openBox(_habitsBox);
    _habitsStamp = _stampOf(_habits);
  }

  static List<Category> readCategories() {
    final result = <Category>[];
    for (final raw in _categories.values) {
      try {
        result.add(Category.fromJson(raw as String));
      } catch (e) {
        debugPrint('Skipped an unreadable category: $e');
      }
    }
    return result;
  }

  static Future<void> writeCategory(Category category) =>
      _categories.put(category.id, category.toJson());

  static Future<void> removeCategory(String id) => _categories.delete(id);

  static String categoryKey(String name) => name.trim().toLowerCase();

  static Future<void> mergeCategory(Category category) async {
    final key = categoryKey(category.name);
    final taken = readCategories()
        .any((c) => c.id != category.id && categoryKey(c.name) == key);
    if (!taken) await writeCategory(category);
  }

  static Future<List<Category>> readCategoriesOnce() async {
    final kept = <String, Category>{};
    final all = readCategories()
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    for (final category in all) {
      final key = categoryKey(category.name);
      if (kept.containsKey(key)) {
        await removeCategory(category.id);
      } else {
        kept[key] = category;
      }
    }
    return kept.values.toList();
  }

  static bool get hasCategories => _categories.isNotEmpty;

  static T setting<T>(String key, T fallback) {
    final value = _settings.get(key, defaultValue: fallback);
    return value is T ? value : fallback;
  }

  static Map<String, dynamic> settingMap(String key) {
    final value = _settings.get(key);
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  static Future<void> writeSetting(String key, Object value) =>
      _settings.put(key, value);

  static Future<void> clearProgress() async {
    for (final habit in readHabits().values) {
      await writeHabit(habit.copyWith(completions: const {}));
    }
    await _notes.clear();
    await _focus.clear();
  }

  static Future<void> wipeContent() async {
    await _habits.clear();
    await _notes.clear();
    await _focus.clear();
    await _todos.clear();
    await _todoTags.clear();
    await _categories.clear();
  }

  static Future<void> wipeEverything() async {
    await _habits.clear();
    await _notes.clear();
    await _focus.clear();
    await _todos.clear();
    await _todoTags.clear();
    await _categories.clear();
    await _settings.clear();
  }
}
