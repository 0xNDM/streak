# Fork Documentation: Streak (Focus Desktop Edition)

> **Upstream Repository**: [InlitX/streak](https://github.com/InlitX/streak)  
> **Fork Repository**: [0xNDM/streak](https://github.com/0xNDM/streak)  
> **Target Focus**: Windows Desktop Productivity & Focus Management (Focus Desktop Edition)  

---

## 1. Overview & Motivation

**Streak** is originally an offline-first, private habit tracker built with Flutter for Android, Windows, and Linux. In upstream Streak, **Focus** (a Pomodoro countdown/stopwatch timer) exists primarily as a secondary utility launched via an app bar pill or modal sheet, while the app revolves primarily around the habit checklist.

This fork reimagines Streak as an **executive, focus-first desktop productivity suite on Windows**, while preserving 100% of its habit-tracking capabilities, database schema, and cross-platform architecture. It elevates Focus to the central operational dashboard, introducing executive analytics, interactive timelines, multi-label tagging, proportional bubble clouds, and desktop-native dialog ergonomics.

---

## 2. Platform Divergence Matrix

To avoid disrupting mobile and other desktop platforms, primary navigation and UI layout shifts are intelligently scoped to **Windows Desktop** (`Platform.isWindows`).

```
+---------------------------------------------------------------------------------------------------------------+
|                                          Platform Divergence Matrix                                           |
+------------------------------+-------------------------------------------+------------------------------------+
| Feature                      | Windows Desktop (This Fork)               | Upstream / Other Platforms         |
+------------------------------+-------------------------------------------+------------------------------------+
| Primary Entrypoint           | Focus tab (top of left navigation rail)   | Today tab (Habits)                 |
| Default Launch Screen        | Executive Focus Dashboard                 | Habit Checklist (Today)            |
| Left Rail Order              | Focus -> Habit -> Todos -> Plan -> ...    | Today -> Todos -> Plan -> ...      |
| Navigation Tab Label         | Habits renamed to "Habit"                 | Named "Today"                      |
| App Bar FocusPill            | Only visible in header when timer RUNS    | Always visible in header           |
| Start Session Action         | Modal Dialog (`FocusSetupDialog`)         | Full-screen or modal sheet         |
| Session Management           | History with 12h editing, delete & rollback | History in nested settings/dialog |
| Timer Completion             | Auto-ends at 00:00, saves, celebratory    | Manual completion stop dialog      |
| Top-level Sub-Navigation     | Flat PillTabs (Today vs. Analytics)       | None (single view)                 |
| Multi-Tag Focus              | Multiple labels/tags with color pills     | Single label string                |
| Focus Targets                | Independent per-day and per-week targets  | Global static settings only        |
| Analytics Visualizations     | Bubble Cloud, 24h Timeline, Heatmap, KPIs | Standard period bar charts         |
| Desktop Ergonomics           | Centered modal dialogs for setup & habits | Full-page navigation pushes        |
+------------------------------+-------------------------------------------+------------------------------------+
```

---

## 3. Detailed Architectural & UI Divergence

### 3.1 Executive Focus Dashboard (`FocusDashboardPage`)
Located in `lib/features/focus/pages/focus_dashboard_page.dart`, the Focus Dashboard serves as the command center for Windows desktop. The page features a lifetime metrics header strip and dual sub-tabs (`Today` and `Analytics`) switchable via frosted `PillTabs` in the AppBar:

#### A. Lifetime Metrics Strip (`FocusDashboardHeader`)
- Always visible at the top of the dashboard.
- Displays three core lifetime statistics formatted with bold 30px tabular typography:
  1. **LOCKED IN**: Total focus hours accumulated across all historical sessions.
  2. **ACTIVE DAYS**: Count of unique calendar days on which focus sessions were logged.
  3. **DAY STREAK**: Current unbroken daily focus streak.

#### B. Sub-Tab: Today
A responsive 2-column layout (constrained to a maximum width of 1300px with a 48px central gap):
1. **Today's Focus Time Hero Card (`_buildHeroCard`)** (Left Column, `flex: 5`):
   - Flat surface container (`surfaceContainerHighest` with 0.45 opacity).
   - "TODAY'S FOCUS TIME" header with goal percentage and "HIT" celebration badge when goal is reached.
   - Large 56px tabular figures showing total time focused today (e.g. `2h 15m`).
   - Daily progress bar and comparison against daily target (e.g. `2.2h / 3h`).
   - Quick-edit pencil button opening the **Independent Daily Target Dialog**.
   - Prominent **Start Session** / **Active Session** button with live status icons (play, flame, check).
   - Real-time active session banner with pause/resume state and quick navigation to the active timer.
2. **Today's Sessions Column (`_buildSessionsColumn`)** (Right Column, `flex: 4` + `flex: 2` right spacer):
   - Intentionally narrowed with an empty right spacer for visual balance and desktop readability.
   - Shows the **3 most recent completed sessions** for the day, with a session count badge.
   - "See all X sessions" button opening a dedicated popup modal (`showPeriodSessionsDialog`).
   - "All History" button opening the full date-grouped historical archive modal (`showFocusHistoryDialog`).
3. **Session Cards (`FocusSessionCard`)**:
   - Displays duration (`1h`, `45m`) directly alongside the session's tags.
   - If a habit is attached, displays its icon glyph and a colored habit pill.
   - All session labels/tags are rendered as distinct, color-coded pills using `focus.colorForLabel(tag)`.
   - If no habit or tag exists, displays *only* the duration (clean, no generic "Focus" fallback text).
   - Displays localized start-end times (`DateFormat.jm`, e.g., `9:00 AM – 10:00 AM`) and completion badge.
   - Inline trash icon button that prompts confirmation before deleting and rolling back credited habit time.
4. **Weekly Continuous Timeline (`WeeklyContinuousTimeline`)**:
   - Centered across the bottom of both columns, constrained to **60% width**.
   - Displays 7 horizontal daily tracks spanning a 24-hour time ruler (`00:00` to `24:00`).
   - Visualizes exact session start times and durations as color-coded pills.
   - Rich hover tooltips display habit title, tags, exact time range, and duration.
   - Week offset controls allow stepping backward and forward through past weeks.

#### C. Sub-Tab: Analytics
A structured, flat analytical dashboard providing deep productivity insights:
1. **Row 1: Weekly Target Comparison & 2×2 KPI Grid**:
   - **Weekly Focus Target Card (`WeeklyFocusComparisonCard`)**: Left column. Compares weekly focus time against the weekly target with progress bar, hours remaining, week-over-week percentage change (`+X% vs last week`), and a pencil button to edit this week's target.
   - **Focus KPI Grid (`FocusKpiGrid`)**: Right column. Compact 2×2 metric grid displaying:
     - *Longest Session* (e.g. `2h 30m`)
     - *Best Focus Day* with date (e.g. `4.5h (Oct 8)`)
     - *This Month* total focus time
     - *Longest Streak* in days
2. **Row 2: Focus Time Range Chart**:
   - Flat container with Week, Month, and Year segment toggles.
   - Interactive bar chart (`FocusPeriodBar` & `FocusRangeBars`).
   - Tapping any bar opens `showPeriodSessionsDialog` showing all individual sessions contributing to that bar.
3. **Row 3: Day of Week & Time of Day Averages**:
   - Equal-height side-by-side cards utilizing `IntrinsicHeight`.
   - **Weekday Averages (`FocusWeekdayAveragesCard`)**: Compares All-Time vs. This-Month average focus time per day of the week.
   - **Time of Day Breakdown (`FocusTimeOfDayCard`)**: Distributes focus time across 4 local periods: Morning (04:00–11:00), Afternoon (11:00–17:00), Evening (17:00–22:00), and Night (22:00–04:00).
4. **Row 4: Annual Activity Map (`FocusActivityMap`)**:
   - Full-width GitHub-style activity heatmap mapped to daily focus minutes.
   - Responsive cell sizing calculated dynamically via `LayoutBuilder` so the full year renders cleanly without horizontal scrollbars.
5. **Row 5: Focused On Bubble Cloud (`FocusTagCloud`)**:
   - Displays the **Top 10 labels** for the selected timeframe (Week, Month, All Time).
   - Proportional **Bubble Chart** (Last.fm style): Each label is rendered as a circle where the circle's radius scales with the square root of its duration ($\sqrt{\text{share}}$, true area scaling).
   - Bubbles scale from a readable minimum of `54px` up to `~190px` for dominant tags.
   - Smart text fitting: Words are never cut mid-word across lines; font sizes scale down automatically inside an inner safe container (`FittedBox`); 2-word labels stack cleanly onto 2 lines.
   - Hover tooltips display total duration and label name.

---

### 3.2 Multi-Tag Focus & Label Management

- **Multi-Label Sessions**: `FocusSession` schema v2 stores `List<String> labelIds`; the old `label`/`tags` fields are no longer read.
- **Global Label Catalog**: Labels are independent of habits and persist in `LocalStore` under `focusLabelCatalog`.
- **Label Picker (`FocusLabelPicker`)**: Selects multiple labels during setup, creates labels on the fly, and manages them through long-press actions.
- **Hierarchical Labels**: Optional one-level parent/child labels. Selecting a parent clears its selected children and vice versa; historical names remain resolvable after archiving.
- **Label Management**:
  - Labels can be renamed with retroactive display updates across all historical sessions.
  - Archiving hides a label from future picks while preserving its history.
  - Permanent deletion removes the label and its ID from past sessions.
- **Custom Hex Color Picker**: Allows inputting raw hex codes (`#RRGGBB`) in addition to preset palette swatches.

---

### 3.3 Independent Daily & Weekly Targets

- **Daily Targets**: Independent targets per day (`focus.dailyTargetFor(date)` / `focus.setDailyTarget(date, minutes)`). `0` means Off and hides the goal progress.
- **Weekly Targets**: Independent targets per week (`focus.weeklyTargetFor(date)` / `focus.setWeeklyTarget(date, hours)`).
- Quick modal dialogs allow selecting from standard presets or entering custom numbers.

---

### 3.4 Desktop Ergonomics & Modal Dialogs

Instead of mobile-oriented full-page pushes, desktop interactions are refactored into centered, keyboard-accessible dialogs:
- **`FocusSetupDialog`**: Quick modal for configuring duration (presets: 30m, 1h, 2h, custom), habit association, and tags before starting a session.
- **`HabitFormDialog` & `HabitDetailsDialog`**: Desktop modal dialogs for creating, editing, and inspecting habits.
- **`FocusHistoryDialog`**: Date-grouped modal archive of all historical focus sessions.
- **`FocusPeriodSessionsDialog`**: Filtered session list for inspecting sessions on any given day, week, or bar tap.
- **12-Hour Session Editing**: Recent sessions can be edited from history or session cards. The end time stays fixed while duration and labels change; time-habit credit is undone and re-applied. A label-only edit keeps existing credit.
- **Close Guard**: Closing the Windows window while a focus session is active prompts to end the session and close or keep going. Completed sessions close silently.
- **Navigation Shortcuts**: `Ctrl+Tab` / `Ctrl+Shift+Tab` cycles tabs; `Escape` navigates back or closes dialogs cleanly.
- **Mini Timer Rail Chip (`MiniTimerChip`)**: Live pill in the left navigation rail displaying the active countdown.

---

### 3.5 Core Focus Engine Enhancements

1. **Auto-End & Auto-Save**:
   - Countdown timers automatically complete at `00:00`.
   - Instantly triggers audio alert, plays celebration feedback, saves session to Hive, credits habit time, and dismisses the timer screen without requiring manual interaction.
2. **Double-Crediting Prevention**:
   - Each run has a persisted `runId`, and a `counted` marker prevents duplicate habit credit across auto-completes, restarts, and manual stops.
3. **Crash Recovery Without Auto-Resume**:
   - A 15-second heartbeat stores `lastSeen`. If the app dies, the interrupted session is finalized at `lastSeen` instead of resuming; sessions under 30 seconds are discarded.
4. **Session Deletion with Habit Rollback**:
   - Deleting a session rolls back credited habit time via `countFocusTime(habits, focus, session, undo: true)` and purges the session from Hive.
5. **Logical-Day Splitting**:
   - Sessions crossing the day cutoff are split on demand (`FocusSession.slices()`), so time-of-day, daily goals, and habit progress stay accurate.

---

## 4. Database Schema & Persistence Guarantees

- **Hive Storage Preservation**: All focus data resides in Hive's standard `'focus'` box (`LocalStore._focusBox = 'focus'`).
- **Session Schema v2**: Stored sessions include `endedAt`, `labelIds`, and `schema: 2`. Legacy `label`/`tags` values are ignored rather than migrated at runtime.
- **Label Catalog Backup**: `focusLabelCatalog` is included in exported archives.
- **Import / Export Compatibility**: Full backup archives (`.zip`) created by this fork restore labels and sessions. Older upstream archives still import their sessions without labels.

---

## 5. Automated Test Suite

- [`test/focus_dashboard_test.dart`](file:///N:/Programming/streak/test/focus_dashboard_test.dart):
  - Focus dashboard is initial tab on Windows.
  - Today sub-tab renders hero card, duration, start-end ranges, and 3-session cap.
  - "See all sessions" dialog opens and displays full list.
  - Analytics sub-tab renders KPI grid, weekly target, and charts.
  - "Start session" modal dialog trigger.
  - Session deletion prompts confirm dialog and deletes from store.
  - Roundtrip serialization and persistence test for `FocusSession`.
- [`test/home_shell_test.dart`](file:///N:/Programming/streak/test/home_shell_test.dart):
  - Windows launches directly into Focus tab.
  - Tab order and back navigation behavior on Windows vs other platforms.
