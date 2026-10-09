# Fork Documentation: Streak (Focus Desktop Edition)

> **Upstream Repository**: [InlitX/streak](https://github.com/InlitX/streak)  
> **Fork Repository**: [0xNDM/streak](https://github.com/0xNDM/streak)  
> **Target Focus**: Windows Desktop Productivity & Focus Management  

---

## 1. Overview & Motivation

Streak is originally an offline-first, private habit tracker built with Flutter for Android, iOS, Linux, and Windows. In upstream Streak, **Focus** (a Pomodoro and countdown timer) exists primarily as a secondary utility launched via an app bar pill or modal sheet.

This fork transforms Streak into a **focus-first desktop app on Windows**, while preserving 100% of its habit-tracking capabilities, database schema, and cross-platform architecture.

---

## 2. Platform Divergence: Windows vs. Other Platforms

To avoid disrupting mobile and other desktop platforms, all primary navigation and UI layout shifts are scoped specifically to **Windows Desktop** (`Platform.isWindows`).

```
+--------------------------------------------------------------------------------------------------+
|                                     Platform Divergence Matrix                                   |
+------------------------------+----------------------------------+--------------------------------+
| Feature                      | Windows Desktop (This Fork)      | Other Platforms (Android/iOS)  |
+------------------------------+----------------------------------+--------------------------------+
| Primary Entrypoint           | Focus tab (Top of left rail)     | Today tab (Habits)             |
| Default Launch Screen        | Focus Dashboard                  | Today (Habits)                 |
| Left Rail Order              | Focus -> Today -> Todos -> ...   | Today -> Todos -> Plan -> ...  |
| App Bar FocusPill            | Only visible when timer RUNNING  | Always visible in header       |
| Start Session Action         | Opens FocusSetup in right pane   | Opens full-screen or modal     |
| Session Management           | History list with Delete action  | History in nested settings/sub |
| Timer Completion             | Auto-ends, saves, & dismisses    | Manual completion stop dialog  |
+------------------------------+----------------------------------+--------------------------------+
```

### Detailed Divergence Points

#### A. Left Navigation Rail (`lib/app/home_shell.dart`)
- **Windows**:
  - `_Tab.focus` is added as the top-most item in the navigation rail, above `_Tab.today`.
  - When the app launches, the initial default selected tab is `_Tab.focus`.
  - Pressing `Escape` or the back action from other tabs navigates back to `_Tab.focus`.
  - When viewing the Focus tab, the right detail sidebar displays a dedicated Focus placeholder instead of the generic habit placeholder.
- **Android, iOS, macOS, Linux, Web**:
  - Bottom navigation bar and side rails retain `_Tab.today` as the first and default item.
  - Zero disruption to mobile layouts or upstream behavior.

#### B. Header Focus Pill in `HomePage` (`lib/features/habits/pages/home_page.dart`)
- **Windows**:
  - The header `FocusPill` only appears when a session is actively running (`focus.isActive == true`). When idle, the header is uncluttered because Focus is already prominently featured in the navigation rail.
- **Other Platforms**:
  - Unconditionally displays the `FocusPill` in the app bar as in upstream.

---

## 3. New Components & Pages

### 1. `FocusDashboardPage` (`lib/features/focus/pages/focus_dashboard_page.dart`)
The main desktop dashboard rendered when the Focus tab is selected. Features two sub-tabs adapted to the active theme style (Express, Classic, or Minimal):

#### Sub-tab: **Today**
1. **Focus Today Hero Card (`FocusTodayHero`)**:
   - Stylized large typography showing total focused hours/minutes today (e.g. `2h 30m`, `45m`, `0m`).
   - Daily focus goal progress bar and percentage against `settings.focusDailyGoal`.
   - Live running session indicator displaying real-time countdown, pause/running status, and quick-resume banner.
   - Primary **Start session** / **Resume Active Session** button.
2. **Right Sidebar Launcher**:
   - Clicking "Start session" calls `openFocus(context)`, mounting `FocusSetupPage` directly into the Windows split scaffold's right detail pane (`_DetailPane`).
3. **Today's Session History**:
   - Shows all completed focus sessions for the current day, sorted newest first.
   - Displays duration (e.g., `25m`, `1h 10m`).
   - Displays localized time range from system clock (`DateFormat.jm`, e.g. `9:30 AM – 9:55 AM`).
   - Habit association badge, color chip, custom label tags, and completion checkmark.
4. **Session Deletion**:
   - Each session card includes a trash icon button.
   - Clicking trash prompts `showAppConfirmDialog`.
   - Upon confirmation, it rolls back credited habit time via `countFocusTime(habits, focus, session, undo: true)`, removes the session ID from Hive storage, and displays a feedback snackbar.

#### Sub-tab: **Details**
1. **Metric Overview Tiles (`FocusMetricCard`)**: Week, Month, Total, and Average session duration.
2. **Interactive Period Charts (`FocusPeriodBar` & `FocusRangeBars`)**: Interactive Week, Month, and Year focus duration bars with offset navigation.
3. **Annual Activity Map (`FocusActivityMap`)**: Full GitHub-style annual heatmap powered by `YearHeatmap` mapped to daily focus minutes.
4. **Distribution Rankings**: Breakdowns of focus time per habit and per custom label.

### 2. Supporting Modular Widgets (`lib/features/focus/widgets/focus_dashboard_widgets.dart`)
- `FocusTodayHero`: Hero card for today's hours, goal progress, active session badge, and start button.
- `FocusSessionCard`: Card displaying duration, localized start-end times, habit glyph, tag, completion icon, and delete callback.
- `FocusActivityMap`: Heatmap wrapper integrating `YearHeatmap`.
- `FocusMetricCard`: Summary stat card for Details tab.

---

## 4. Core Focus Engine Enhancements (Cross-Platform)

### 1. Auto-End & Auto-Save (`lib/features/focus/state/focus_controller.dart`)
- **Upstream Behavior**: When a standard countdown reached zero, the timer played an alert sound but remained in an open, uncompleted state until the user manually opened `FocusPage` and clicked stop/save.
- **Fork Enhancement**:
  - When `reachedTarget` evaluates to true on a countdown timer, a 2-second celebration window triggers, followed by `_autoEnd = Timer(const Duration(seconds: 2), () async { if (_open && reachedTarget) await stop(completed: true); });`.
  - Automatically saves the session to Hive storage (`LocalStore.writeFocusSession`) and invokes `onRoundSaved?.call(session)`.
  - If `FocusPage` is open, it detects `!focus.isActive`, displays an `AppSnackbar` confirming the saved duration, and dismisses itself automatically.
  - Interacting with `pause()`, `reset()`, or `addMinute()` safely cancels the `_autoEnd` timer.

### 2. Double-Crediting Prevention (`lib/features/focus/state/focus_actions.dart` & `focus_page.dart`)
- In `FocusController.stop()`, `onRoundSaved?.call(session)` is called, which triggers `creditFocusRound(habits, focus, session)` attached in `HomeShellState`.
- To prevent double-crediting habit time:
  - `FocusPage._confirmStop` checks `if (focus.onRoundSaved == null)` before running manual habit crediting.
  - `applyFocusAction` checks `if (focus.onRoundSaved != null) return;`.
  - `countFocusTime` defends against double increments with `if (!undo && session.counted) return;`.

---

## 5. Database Schema & Persistence Guarantees

- **Hive Box Preservation**: All focus sessions continue to reside in Hive's standard `'focus'` box (`LocalStore._focusBox = 'focus'`).
- **Data Compatibility**: No breaking changes were made to `FocusSession.toMap()` or `fromMap()`.
- **Import / Export Compatibility**:
  - Full backup archives (`.zip`) created by upstream Streak can be imported cleanly into this fork without data loss.
  - Exports generated by this fork can be restored into upstream or other devices without migration errors.

---

## 6. Build & CI Configuration

### GitHub Actions (`.github/workflows/windows.yml`)
- The upstream workflow is preserved with `workflow_dispatch`:
  - **Running without a tag**: Extracts the version (`2.3.0`) from `pubspec.yaml`, builds the Windows release, packages it using Inno Setup 6.7.1, and uploads `Streak-windows-x64-setup.exe` to the workflow run's **Artifacts** section.
  - **Running with a tag (e.g. `v2.3.0`)**: Builds the installer and publishes it directly to GitHub **Releases** (`https://github.com/0xNDM/streak/releases`).

---

## 7. Automated Test Suite

- [`test/home_shell_test.dart`](file:///N:/Programming/streak/test/home_shell_test.dart):
  - Validates that Windows launches directly to the Focus dashboard.
  - Validates classic navigation and gestures across tabs.
- [`test/focus_dashboard_test.dart`](file:///N:/Programming/streak/test/focus_dashboard_test.dart):
  - Focus dashboard is the primary initial tab on Windows.
  - Today sub-tab renders today's sessions with duration and start-end time ranges.
  - Details sub-tab renders charts, metric cards, and the activity map.
  - "Start session" triggers navigation to `FocusSetupPage`.
  - Deleting a focus session prompts confirmation, updates UI, and removes from `LocalStore`.
  - Database roundtrip persistence test for `FocusSession`.
