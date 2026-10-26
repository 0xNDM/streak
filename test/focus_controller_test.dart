import 'package:flutter_test/flutter_test.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/services/focus_service.dart';

import 'support/app_harness.dart';

FocusController _controller() {
  final controller = FocusController();
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  useEmptyStore();

  test('weekly target keys use the selected week start', () {
    expect(
      FocusController.weekKey(DateTime(2026, 1, 1), DateTime.monday),
      '29-12-2025',
    );
    expect(
      FocusController.weekKey(DateTime(2026, 1, 1), DateTime.sunday),
      '28-12-2025',
    );
  });

  group('coming back to a saved session', () {
    Future<void> save({
      required int acc,
      required String since,
      String runId = 'run-1',
      String? lastSeen,
      bool open = true,
    }) =>
        LocalStore.writeSetting('focusActive', {
          'habitId': 'h1',
          'target': 25,
          'focus': 25,
          'break': 0,
          'isBreak': false,
          'round': 1,
          'acc': acc,
          'since': since,
          'lastSeen': lastSeen ?? since,
          'runId': runId,
          'labelIds': const <String>[],
          'open': open,
        });

    test('one that was left paused at zero is dropped', () async {
      await save(acc: 0, since: '');
      final focus = _controller();
      await focus.recoverIfNeeded();
      expect(focus.isActive, isFalse);
      expect(LocalStore.readFocusSessions(), isEmpty);
    });

    test('one with time on the clock is saved but not resumed', () async {
      await save(acc: 300, since: '');
      final focus = _controller();
      expect(focus.isActive, isFalse);
      await focus.recoverIfNeeded();
      expect(focus.isActive, isFalse);
      final sessions = LocalStore.readFocusSessions();
      expect(sessions.single.id, 'run-1');
      expect(sessions.single.seconds, 300);
    });

    test('one still running is saved at its last heartbeat', () async {
      final start = DateTime.now().subtract(const Duration(minutes: 5));
      final seen = DateTime.now().subtract(const Duration(minutes: 1));
      await save(
        acc: 0,
        since: start.toIso8601String(),
        lastSeen: seen.toIso8601String(),
      );
      final focus = _controller();
      await focus.recoverIfNeeded();
      expect(focus.isActive, isFalse);
      expect(LocalStore.readFocusSessions().single.seconds, 240);
    });

    test('a dropped one does not block starting another habit', () async {
      await save(acc: 0, since: '');
      final focus = _controller();
      await focus.recoverIfNeeded();
      expect(focus.isActive, isFalse);

      focus.start(habitId: 'h2', targetMinutes: 45);
      expect(focus.isActive, isTrue);
      expect(focus.habitId, 'h2');
      expect(focus.targetSeconds, 2700);
    });

    test('a completed run is credited once, even after another restart',
        () async {
      final ended = DateTime.now().subtract(const Duration(minutes: 2));
      final pending = FocusSession(
        id: 'done-run',
        habitId: 'h1',
        targetMinutes: 25,
        seconds: 1500,
        completed: true,
        startedAt: ended.subtract(const Duration(minutes: 25)),
        endedAt: ended,
      );
      await LocalStore.writeSetting('focusActive', {
        'open': true,
        'completed': true,
        'runId': pending.id,
        'pending': pending.toMap(),
      });

      final credits = <String>[];
      final first = _controller();
      first.onRoundSaved = (session) async {
        credits.add(session.id);
      };
      await first.recoverIfNeeded();
      expect(credits, ['done-run']);
      expect(LocalStore.readFocusSessions().single.id, 'done-run');

      await coldStart();
      final second = _controller();
      second.onRoundSaved = (session) async {
        credits.add(session.id);
      };
      await second.recoverIfNeeded();
      expect(credits, ['done-run']);
    });
  });

  group('editing a session', () {
    FocusSession stored({
      required DateTime endedAt,
      int seconds = 1500,
      bool counted = true,
    }) =>
        FocusSession(
          id: 'editable',
          habitId: 'read',
          targetMinutes: 25,
          seconds: seconds,
          completed: true,
          startedAt: endedAt.subtract(Duration(seconds: seconds)),
          endedAt: endedAt,
          counted: counted,
          labelIds: const ['old'],
        );

    test('a recent duration change keeps the end and needs fresh credit',
        () async {
      final endedAt = DateTime.now().subtract(const Duration(hours: 1));
      await LocalStore.writeFocusSession(stored(endedAt: endedAt));
      final focus = _controller();

      final updated = await focus.editSession(
        id: 'editable',
        seconds: 1800,
        labelIds: const ['new'],
      );

      expect(updated, isNotNull);
      expect(updated!.seconds, 1800);
      expect(updated.endedAt, endedAt);
      expect(updated.startedAt, endedAt.subtract(const Duration(minutes: 30)));
      expect(updated.labelIds, ['new']);
      expect(updated.counted, isFalse);
    });

    test('changing only labels keeps the time already credited', () async {
      final endedAt = DateTime.now().subtract(const Duration(hours: 1));
      await LocalStore.writeFocusSession(stored(endedAt: endedAt));
      final focus = _controller();

      final updated = await focus.editSession(
        id: 'editable',
        seconds: 1500,
        labelIds: const ['new'],
      );

      expect(updated!.counted, isTrue);
      expect(updated.startedAt, endedAt.subtract(const Duration(minutes: 25)));
    });

    test('a session older than 12 hours cannot be edited', () async {
      final endedAt = DateTime.now().subtract(const Duration(hours: 13));
      await LocalStore.writeFocusSession(stored(endedAt: endedAt));
      final focus = _controller();

      final updated = await focus.editSession(
        id: 'editable',
        seconds: 600,
        labelIds: const [],
      );

      expect(updated, isNull);
      expect(LocalStore.readFocusSessions().single.seconds, 1500);
    });
  });

  group('countdown', () {
    test('a timed session keeps its target and counts down', () {
      final focus = _controller();
      focus.start(habitId: '', targetMinutes: 25);

      expect(focus.isFlow, isFalse);
      expect(focus.targetSeconds, 1500);
      expect(focus.remainingSeconds, 1500);
      expect(focus.displaySeconds, focus.remainingSeconds);
      expect(focus.reachedTarget, isFalse);
      expect(focus.progress, 0);
    });

    test('pomodoro still turns on for a timed session', () {
      final focus = _controller();
      focus.start(habitId: '', targetMinutes: 25, breakMinutes: 5);

      expect(focus.isPomodoro, isTrue);
    });
  });

  group('flowtime', () {
    test('it has no target and does not complete on its own', () {
      final focus = _controller();
      focus.start(habitId: '', targetMinutes: 0);

      expect(focus.isFlow, isTrue);
      expect(focus.targetSeconds, 0);
      expect(focus.remainingSeconds, 0);
      expect(focus.reachedTarget, isFalse);
    });

    test('the clock counts up instead of down', () {
      final focus = _controller();
      focus.start(habitId: '', targetMinutes: 0);

      expect(focus.displaySeconds, focus.elapsedSeconds);
      expect(focus.progress, isNot(isNaN));
      expect(focus.progress, inInclusiveRange(0, 1));
    });

    test('pomodoro is refused because there is nothing to break from', () {
      final focus = _controller();
      focus.start(habitId: '', targetMinutes: 0, breakMinutes: 5);

      expect(focus.isPomodoro, isFalse);
    });

    test('a session shorter than 30 seconds is not saved', () async {
      final focus = _controller();
      focus.start(habitId: '', targetMinutes: 0);

      expect(await focus.stop(completed: true), isNull);
      expect(focus.isActive, isFalse);
    });
  });

  group('outliving the process', () {
    Future<void> seedRunning({
      required int targetMinutes,
      required Duration ago,
      Duration seenAgo = Duration.zero,
      int breakMinutes = 0,
    }) async {
      await LocalStore.writeSetting('focusActive', {
        'habitId': 'read',
        'target': targetMinutes,
        'focus': targetMinutes,
        'break': breakMinutes,
        'isBreak': false,
        'round': 1,
        'acc': 0,
        'since': DateTime.now().subtract(ago).toIso8601String(),
        'lastSeen': DateTime.now().subtract(seenAgo).toIso8601String(),
        'runId': 'run-read',
        'open': true,
      });
      await coldStart();
    }

    test('a running session is finalized after a cold start, not resumed',
        () async {
      await seedRunning(
        targetMinutes: 25,
        ago: const Duration(minutes: 10),
      );

      final after = _controller();
      expect(after.isActive, isFalse);
      await after.recoverIfNeeded();
      expect(after.isActive, isFalse);
      final sessions = LocalStore.readFocusSessions();
      expect(sessions.single.habitId, 'read');
      expect(sessions.single.seconds, 600);
    });

    test('a countdown that ran out while away banks its target, not the gap',
        () async {
      await seedRunning(
        targetMinutes: 25,
        ago: const Duration(hours: 3),
      );

      final focus = _controller();
      await focus.recoverIfNeeded();
      final session = LocalStore.readFocusSessions().single;
      expect(session.seconds, 1500);
      expect(session.completed, isTrue);
    });

    test('a session paused before the process died is finalized', () async {
      await LocalStore.writeSetting('focusActive', {
        'habitId': 'read',
        'target': 25,
        'focus': 25,
        'break': 0,
        'isBreak': false,
        'round': 1,
        'acc': 300,
        'since': '',
        'lastSeen': DateTime.now().toIso8601String(),
        'runId': 'run-paused',
        'open': true,
      });
      await coldStart();

      final focus = _controller();
      await focus.recoverIfNeeded();
      expect(focus.isActive, isFalse);
      expect(LocalStore.readFocusSessions().single.seconds, 300);
    });

    test('flowtime keeps every minute up to the last heartbeat', () async {
      await seedRunning(
        targetMinutes: 0,
        ago: const Duration(hours: 3),
      );

      final focus = _controller();
      await focus.recoverIfNeeded();
      expect(LocalStore.readFocusSessions().single.seconds, closeTo(10800, 60));
    });

    test('recovery banks up to the last heartbeat, not the process start',
        () async {
      await seedRunning(
        targetMinutes: 60,
        ago: const Duration(minutes: 30),
        seenAgo: const Duration(minutes: 20),
      );

      final focus = _controller();
      await focus.recoverIfNeeded();
      final session = LocalStore.readFocusSessions().single;
      expect(session.seconds, closeTo(600, 5));
      expect(focus.isActive, isFalse);
    });

    test('pausing from the notification drops the time it was left alone',
        () async {
      final focus = _controller();
      focus.start(habitId: 'read', targetMinutes: 60);
      await focus.apply(
        FocusAction(
          kind: FocusAction.pause,
          at: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );

      expect(focus.isRunning, isFalse);
      expect(focus.elapsedSeconds, closeTo(300, 5));
    });
  });

  group('what the focus screen remembers', () {
    test('a free session starts with the last setup, not with 25', () async {
      var settings = SettingsController();
      expect(settings.focusMinutes, 25);
      expect(settings.focusBreakMinutes, 0);

      await settings.rememberFocusSetup(50, 10);
      await coldStart();

      settings = SettingsController();
      expect(settings.focusMinutes, 50);
      expect(settings.focusBreakMinutes, 10);
    });

    test('turning pomodoro off is remembered too', () async {
      var settings = SettingsController();
      await settings.rememberFocusSetup(50, 10);
      await settings.rememberFocusSetup(30, 0);
      await coldStart();

      settings = SettingsController();
      expect(settings.focusMinutes, 30);
      expect(settings.focusBreakMinutes, 0);
    });

    test('the track survives a cold start, and stopping forgets it', () async {
      var settings = SettingsController();
      expect(settings.focusTrack, '');

      await settings.setFocusTrack('rain');
      await coldStart();

      settings = SettingsController();
      expect(settings.focusTrack, 'rain');

      await settings.setFocusTrack('');
      await coldStart();

      settings = SettingsController();
      expect(settings.focusTrack, '');
    });
  });

  group('FocusController label management and period offsets', () {
    test('sub-labels maintain hierarchy and parent linkage', () async {
      final focus = _controller();
      final parent = await focus.createLabel('Learning', 0xFF3B82F6);
      final child = await focus.createLabel('Flutter Course', 0xFF10B981, parentId: parent.id);

      expect(child.parentId, parent.id);
      expect(child.isChild, isTrue);

      final children = focus.childLabelsOf(parent.id);
      expect(children.length, 1);
      expect(children.first.id, child.id);

      final topLevel = focus.topLevelLabels;
      expect(topLevel.any((l) => l.id == parent.id), isTrue);
      expect(topLevel.any((l) => l.id == child.id), isFalse);

      expect(focus.labelDisplayName(child.id), 'Learning > Flutter Course');
    });

    test('archive and unarchive labels', () async {
      final focus = _controller();
      final label = await focus.createLabel('Reading', 0xFF3B82F6);
      expect(focus.activeLabels.any((l) => l.id == label.id), isTrue);

      await focus.archiveLabel(label.id);
      expect(focus.activeLabels.any((l) => l.id == label.id), isFalse);
      expect(focus.archivedLabels.any((l) => l.id == label.id), isTrue);

      await focus.unarchiveLabel(label.id);
      expect(focus.activeLabels.any((l) => l.id == label.id), isTrue);
      expect(focus.archivedLabels.any((l) => l.id == label.id), isFalse);
    });

    test('recentEditableSessions returns sessions within 12 hours', () async {
      final focus = _controller();
      final now = DateTime.now();

      final recent = FocusSession(
        id: 'recent-1',
        habitId: '',
        targetMinutes: 25,
        seconds: 1500,
        completed: true,
        startedAt: now.subtract(const Duration(hours: 3)),
        endedAt: now.subtract(const Duration(hours: 2, minutes: 35)),
      );

      final old = FocusSession(
        id: 'old-1',
        habitId: '',
        targetMinutes: 25,
        seconds: 1500,
        completed: true,
        startedAt: now.subtract(const Duration(hours: 15)),
        endedAt: now.subtract(const Duration(hours: 14, minutes: 35)),
      );

      await LocalStore.writeFocusSession(recent);
      await LocalStore.writeFocusSession(old);
      await focus.recoverIfNeeded();

      final editable = focus.recentEditableSessions(maxAgeHours: 12, now: now);
      expect(editable.any((s) => s.id == 'recent-1'), isTrue);
      expect(editable.any((s) => s.id == 'old-1'), isFalse);
    });

    test('focus session computes wall-clock span, pauses, and intensity', () {
      final start = DateTime(2026, 10, 26, 6, 0);
      final end = DateTime(2026, 10, 26, 9, 0);
      final session = FocusSession(
        id: 'wall-clock-1',
        habitId: '',
        targetMinutes: 120,
        seconds: 7200, // 2 hours focus in 3 hours span
        completed: true,
        startedAt: start,
        endedAt: end,
      );

      expect(session.spanSeconds, 10800); // 3 hours
      expect(session.pauseSeconds, 3600); // 1 hour pause
      expect(session.hasPauses, isTrue);
      expect(session.intensityPercent, 67); // 7200 / 10800 = 66.67% -> 67%
    });
  });
}
