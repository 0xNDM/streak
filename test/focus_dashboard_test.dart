import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/home_shell.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/pages/focus_dashboard_page.dart';
import 'package:streak/features/focus/pages/focus_setup_page.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_header.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_widgets.dart';
import 'package:streak/features/focus/widgets/focus_setup_dialog.dart';
import 'package:streak/features/focus/widgets/mini_timer_chip.dart';

import 'support/app_harness.dart';

void main() {
  useEmptyStore();

  setUp(() {
    for (final name in const [
      'dev.fluttercommunity.plus/wakelock',
      'flutter.baseflow.com/permissions/methods',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => 1);
    }
  });

  testWidgets('Focus dashboard is the default primary page on Windows',
      (tester) async {
    if (!Platform.isWindows) return;

    await pumpScreen(tester, const HomeShell());
    expect(find.byType(FocusDashboardPage), findsOneWidget);
    expect(find.byType(FocusDashboardHeader), findsOneWidget);
    expect(find.text("Today's Sessions"), findsOneWidget);
  });

  testWidgets('Today sub-tab displays today sessions with duration and time range',
      (tester) async {
    final now = DateTime.now();
    final sessionToday = FocusSession(
      id: 'session-1',
      habitId: '',
      targetMinutes: 25,
      seconds: 25 * 60,
      completed: true,
      startedAt: now.subtract(const Duration(minutes: 30)),
      label: 'Deep Work',
    );

    await tester.runAsync(() async {
      await LocalStore.writeFocusSession(sessionToday);
    });

    await pumpScreen(tester, const FocusDashboardPage());
    await tester.pumpAndSettle();

    expect(find.byType(FocusDashboardHeader), findsOneWidget);
    expect(find.text('25m'), findsWidgets);
    expect(find.text('Deep Work'), findsOneWidget);
    expect(find.byType(FocusSessionCard), findsOneWidget);
  });

  testWidgets('Analytics sub-tab shows charts, metric cards, and activity map',
      (tester) async {
    final now = DateTime.now();
    final session = FocusSession(
      id: 'session-1',
      habitId: '',
      targetMinutes: 45,
      seconds: 45 * 60,
      completed: true,
      startedAt: now,
    );

    await tester.runAsync(() async {
      await LocalStore.writeFocusSession(session);
    });

    await pumpScreen(tester, const FocusDashboardPage());
    await tester.pumpAndSettle();

    // Switch to Analytics sub-tab
    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();

    expect(find.text('Activity Map'), findsOneWidget);
    expect(find.byType(FocusActivityMap), findsOneWidget);
    expect(find.byType(FocusMetricCard), findsWidgets);
  });

  testWidgets('Tapping Start Session opens focus setup', (tester) async {
    await pumpScreen(tester, const FocusDashboardPage());
    await tester.pumpAndSettle();

    final startButton = find.text('Start Session');
    expect(startButton, findsOneWidget);

    await tester.tap(startButton);
    await tester.pumpAndSettle();

    if (Platform.isWindows) {
      expect(find.byType(FocusSetupDialog), findsOneWidget);
    } else {
      expect(find.byType(FocusSetupPage), findsOneWidget);
    }
  });

  test('Database roundtrip: Focus sessions are stored and retrieved safely',
      () async {
    final session = FocusSession(
      id: 'db-test-1',
      habitId: 'habit-101',
      targetMinutes: 30,
      seconds: 1800,
      completed: true,
      startedAt: DateTime(2026, 10, 9, 8, 30),
      label: 'Coding',
    );

    await LocalStore.writeFocusSession(session);
    final stored = LocalStore.readFocusSessions();

    expect(stored.any((s) => s.id == 'db-test-1'), isTrue);
    final retrieved = stored.firstWhere((s) => s.id == 'db-test-1');
    expect(retrieved.habitId, 'habit-101');
    expect(retrieved.seconds, 1800);
    expect(retrieved.label, 'Coding');
    expect(retrieved.completed, isTrue);
  });

  testWidgets('Deleting a focus session in Today tab prompts confirm dialog and removes it',
      (tester) async {
    final now = DateTime.now();
    final session = FocusSession(
      id: 'session-to-delete',
      habitId: '',
      targetMinutes: 20,
      seconds: 1200,
      completed: true,
      startedAt: now.subtract(const Duration(minutes: 25)),
      label: 'Quick Review',
    );

    await tester.runAsync(() async {
      await LocalStore.writeFocusSession(session);
    });

    await pumpScreen(tester, const FocusDashboardPage());
    await tester.pumpAndSettle();

    expect(find.text('Quick Review'), findsOneWidget);
    expect(find.byIcon(LucideIcons.trash2), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();

    // Confirm dialog should be visible
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Session should be removed from the UI
    expect(find.text('Quick Review'), findsNothing);

    // And removed from LocalStore
    final stored = LocalStore.readFocusSessions();
    expect(stored.any((s) => s.id == 'session-to-delete'), isFalse);
  });

  testWidgets('Today tab opens show-all sessions dialog for many sessions',
      (tester) async {
    final now = DateTime.now();
    final sessions = [
      for (var i = 0; i < 5; i++)
        FocusSession(
          id: 'session-many-$i',
          habitId: '',
          targetMinutes: 15,
          seconds: 15 * 60,
          completed: true,
          startedAt: now.subtract(Duration(minutes: 10 + i * 40)),
          label: 'Session $i',
        ),
    ];

    await tester.runAsync(() async {
      for (final session in sessions) {
        await LocalStore.writeFocusSession(session);
      }
    });

    await pumpScreen(tester, const FocusDashboardPage());
    await tester.pumpAndSettle();

    expect(find.byType(FocusSessionCard), findsNWidgets(4));
    expect(find.text('Show all 5 sessions'), findsOneWidget);
    expect(find.text('Session 4'), findsNothing);

    await tester.tap(find.text('Show all 5 sessions'));
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('EEE, MMM d').format(now)), findsOneWidget);
    expect(find.text('Session 0'), findsOneWidget);
    expect(find.text('Session 4'), findsOneWidget);
  });

  testWidgets('Rail mini timer chip appears while a session is active',
      (tester) async {
    if (!Platform.isWindows) return;

    await pumpScreen(tester, const HomeShell());
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();

    expect(find.byType(MiniTimerChip), findsOneWidget);

    final focus =
        tester.element(find.byType(HomeShell)).read<FocusController>();
    expect(focus.isActive, isFalse);
    expect(find.text(formatDuration(focus.displaySeconds)), findsNothing);

    focus.start(habitId: '', targetMinutes: 25);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(focus.isActive, isTrue);
    expect(find.text(formatDuration(focus.displaySeconds)), findsOneWidget);

    focus.pause();
    await tester.pump();

    expect(find.byType(MiniTimerChip), findsOneWidget);
    expect(find.text(formatDuration(focus.displaySeconds)), findsOneWidget);
  });
}
