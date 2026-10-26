import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/utils/app_dirs.dart';
import 'package:streak/features/focus/data/focus_label.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_audio.dart';
import 'package:streak/services/focus_service.dart';
import 'package:streak/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class FocusTask {
  FocusTask({required this.id, this.title = '', this.done = false});

  final String id;
  String title;
  bool done;
}

class FocusController extends ChangeNotifier {
  FocusController() {
    _sessions = LocalStore.readFocusSessions();
    _labels = LocalStore.readFocusLabels();
    _recoveryMap = LocalStore.settingMap('focusActive');
  }

  final ValueNotifier<int> completedTick = ValueNotifier(0);
  bool _celebrated = false;
  Map<String, dynamic>? _recoveryMap;

  void _persist() {
    if (!_open) {
      unawaited(LocalStore.writeSetting('focusActive', <String, dynamic>{}));
      return;
    }
    unawaited(
      LocalStore.writeSetting('focusActive', {
        'habitId': _habitId,
        'labelIds': _labelIds,
        'target': _targetMinutes,
        'focus': _focusMinutes,
        'break': _breakMinutes,
        'isBreak': _isBreak,
        'round': _round,
        'acc': _accumulated,
        'since': _since?.toUtc().toIso8601String() ?? '',
        'lastSeen': _lastSeen?.toUtc().toIso8601String() ?? '',
        'runId': _runId,
        'open': _open,
        'completed': _isCompleted,
        if (_pendingCompleted != null)
          'pending': _pendingCompleted!.toMap(),
      }),
    );
  }

  late List<FocusSession> _sessions;
  List<FocusLabel> _labels = [];
  final List<FocusTask> _tasks = [];

  String _habitId = '';
  List<String> _labelIds = [];
  int _targetMinutes = 25;
  int _focusMinutes = 25;
  int _breakMinutes = 0;
  bool _isBreak = false;
  bool _soundOnBreak = false;
  bool _soundOnPause = false;
  Future<void> Function(FocusSession session)? onRoundSaved;
  int _round = 1;
  bool _open = false;
  bool _isCompleted = false;
  FocusSession? _savedCompletedSession;
  FocusSession? _pendingCompleted;
  bool _awaiting = false;
  int _switchIn = 0;
  int _accumulated = 0;
  DateTime? _since;
  DateTime? _lastSeen;
  String _runId = '';
  Timer? _ticker;
  Timer? _heartbeat;
  List<FocusSession>? _view;
  List<FocusSession>? _slices;
  Map<String, int>? _perDay;
  int _revision = 0;

  bool get isCompleted => _isCompleted;
  FocusSession? get savedCompletedSession => _savedCompletedSession;

  int get revision => _revision;

  List<FocusSession> get sessions => _view ??= List.unmodifiable(_sessions);

  @override
  void notifyListeners() {
    _revision++;
    _view = null;
    _slices = null;
    _perDay = null;
    super.notifyListeners();
  }

  void _tick() => super.notifyListeners();

  void reload() {
    _sessions = LocalStore.readFocusSessions();
    _labels = LocalStore.readFocusLabels();
    notifyListeners();
  }

  Future<void> recoverIfNeeded() async {
    final map = _recoveryMap;
    if (map == null || map.isEmpty) return;
    _recoveryMap = null;
    if (map['open'] != true) {
      await LocalStore.writeSetting('focusActive', <String, dynamic>{});
      return;
    }
    final wasCompleted = map['completed'] == true;
    final pendingRaw = map['pending'];
    FocusSession? pending;
    if (pendingRaw is Map) {
      try {
        pending = FocusSession.fromMap(Map<String, dynamic>.from(pendingRaw));
      } catch (e) {
        debugPrint('Could not recover a pending focus session: $e');
      }
    }
    final runId = (map['runId'] ?? '').toString();
    final stored = _sessionById(pending?.id ?? runId);
    if (wasCompleted) {
      final session = stored ?? pending;
      if (session != null && stored == null) {
        await LocalStore.writeFocusSession(session);
        _upsert(session);
      }
      if (session != null && !session.counted) {
        await _handOff(session);
      }
      await LocalStore.writeSetting('focusActive', <String, dynamic>{});
      notifyListeners();
      return;
    }

    final isBreak = map['isBreak'] == true;
    final target = ((map['target'] ?? 25) as num).toInt();
    final focusMinutes = ((map['focus'] ?? target) as num).toInt();
    final accumulated = ((map['acc'] ?? 0) as num).toInt();
    final sinceRaw = (map['since'] ?? '').toString();
    final since = sinceRaw.isEmpty
        ? null
        : DateTime.tryParse(sinceRaw)?.toLocal();
    final lastSeenRaw = (map['lastSeen'] ?? '').toString();
    final lastSeen =
        (DateTime.tryParse(lastSeenRaw)?.toLocal()) ??
            since ??
            DateTime.now();
    var seconds = accumulated;
    if (since != null) seconds += lastSeen.difference(since).inSeconds;
    if (target > 0) seconds = seconds.clamp(0, target * 60);
    if (isBreak || seconds < 30 || runId.isEmpty) {
      await LocalStore.writeSetting('focusActive', <String, dynamic>{});
      return;
    }
    if (stored != null && stored.seconds >= seconds) {
      if (!stored.counted) await _handOff(stored);
      await LocalStore.writeSetting('focusActive', <String, dynamic>{});
      return;
    }
    final labelIds = map['labelIds'] is List
        ? List<String>.from(map['labelIds'] as List)
        : const <String>[];
    final completed = target > 0 && seconds >= target * 60;
    final session = FocusSession(
      id: runId,
      habitId: (map['habitId'] ?? '').toString(),
      targetMinutes: focusMinutes,
      seconds: seconds,
      completed: completed,
      startedAt: lastSeen.subtract(Duration(seconds: seconds)),
      endedAt: lastSeen,
      labelIds: labelIds,
    );
    await LocalStore.writeFocusSession(session);
    _upsert(session);
    await _handOff(session);
    await LocalStore.writeSetting('focusActive', <String, dynamic>{});
    notifyListeners();
  }

  Future<void> removeSessions(Set<String> ids) async {
    if (ids.isEmpty) return;
    await LocalStore.removeFocusSessions(ids);
    _sessions = _sessions.where((s) => !ids.contains(s.id)).toList();
    notifyListeners();
  }

  static const editWindow = Duration(hours: 12);

  bool canEditSession(FocusSession session, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(session.endedAt);
    return !elapsed.isNegative && elapsed <= editWindow;
  }

  Future<FocusSession?> editSession({
    required String id,
    required int seconds,
    required List<String> labelIds,
  }) async {
    final old = _sessionById(id);
    if (old == null || seconds <= 0 || !canEditSession(old)) return null;
    final updated = old.copyWith(
      seconds: seconds,
      startedAt: old.endedAt.subtract(Duration(seconds: seconds)),
      labelIds: labelIds,
      counted: seconds == old.seconds ? old.counted : false,
    );
    await _keep(updated);
    notifyListeners();
    return updated;
  }

  Future<void> markCounted(String id) async {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final counted = _sessions[index].asCounted;
    _sessions[index] = counted;
    _view = null;
    _slices = null;
    _perDay = null;
    await LocalStore.writeFocusSession(counted);
  }

  FocusSession? _sessionById(String id) {
    if (id.isEmpty) return null;
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  void _upsert(FocusSession session) {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index == -1) {
      _sessions.add(session);
    } else {
      _sessions[index] = session;
    }
    _view = null;
    _slices = null;
    _perDay = null;
  }

  Future<FocusSession> addSession({
    required String habitId,
    required DateTime startedAt,
    required int minutes,
    DateTime? endedAt,
    List<String> labelIds = const [],
  }) async {
    final ended = endedAt ?? startedAt.add(Duration(minutes: minutes));
    final session = FocusSession(
      id: const Uuid().v4(),
      habitId: habitId,
      targetMinutes: minutes,
      seconds: minutes * 60,
      completed: true,
      startedAt: startedAt,
      endedAt: ended,
      labelIds: labelIds,
    );
    await _keep(session);
    notifyListeners();
    return session;
  }

  Future<void> _handOff(FocusSession session) async {
    final callback = onRoundSaved;
    if (callback != null) await callback(session);
  }

  Future<void> _keep(FocusSession session) async {
    _upsert(session);
    try {
      await LocalStore.writeFocusSession(session);
    } catch (e) {
      debugPrint('Could not save a focus session: $e');
    }
  }

  List<FocusTask> get tasks => List.unmodifiable(_tasks);
  int get pendingTasks => _tasks.where((t) => !t.done).length;

  String get habitId => _habitId;
  List<String> get labelIds => List.unmodifiable(_labelIds);
  bool get isBreak => _isBreak;
  int get round => _round;
  bool get isPomodoro => _breakMinutes > 0;
  static const longBreakEvery = 4;
  int get _longBreakMinutes => LocalStore.setting('focusLongBreak', 0);
  bool get isLongBreak =>
      _isBreak && _longBreakMinutes > 0 && _round % longBreakEvery == 0;
  int get targetMinutes => _targetMinutes;
  int get targetSeconds => _targetMinutes * 60;

  bool get isActive => _open;
  bool get isRunning => _since != null;
  bool get isAwaiting => _awaiting;

  static const switchDelay = 5;

  int get switchIn => _switchIn;

  int elapsedAt(DateTime at) {
    final live = _since == null ? 0 : at.difference(_since!).inSeconds;
    final total = _accumulated + live;
    return isFlow ? total : total.clamp(0, targetSeconds);
  }

  int get elapsedSeconds => elapsedAt(DateTime.now());

  bool get isFlow => _targetMinutes <= 0;

  int get remainingSeconds =>
      isFlow ? 0 : (targetSeconds - elapsedSeconds).clamp(0, targetSeconds);

  int get displaySeconds => isFlow ? elapsedSeconds : remainingSeconds;

  double get progress => isFlow
      ? (elapsedSeconds % 60) / 60
      : (elapsedSeconds / targetSeconds).clamp(0.0, 1.0);

  bool get reachedTarget => !isFlow && elapsedSeconds >= targetSeconds;

  DateTime get _phaseEnd => _since == null
      ? DateTime.now()
      : _since!.add(Duration(seconds: targetSeconds - _accumulated));

  void start({
    required String habitId,
    required int targetMinutes,
    int breakMinutes = 0,
    List<String> labelIds = const [],
  }) {
    _habitId = habitId;
    _labelIds = List<String>.from(labelIds);
    _targetMinutes = targetMinutes;
    _focusMinutes = targetMinutes;
    _breakMinutes = targetMinutes <= 0 ? 0 : breakMinutes;
    _isBreak = false;
    _round = 1;
    _open = true;
    _isCompleted = false;
    _savedCompletedSession = null;
    _pendingCompleted = null;
    _accumulated = 0;
    _tasks.clear();
    _since = DateTime.now();
    _lastSeen = _since;
    _runId = const Uuid().v4();
    _celebrated = false;
    _startTicker();
    _startHeartbeat();
    _persist();
    _sync();
    notifyListeners();
  }

  void pause({DateTime? at}) {
    unawaited(FocusAudio.stopAlert());
    if (_since == null) return;
    _accumulated = elapsedAt(at ?? DateTime.now());
    _since = null;
    _lastSeen = at ?? DateTime.now();
    _stopTicker();
    _stopHeartbeat();
    _persist();
    _sync();
    notifyListeners();
    _soundOnPause = FocusAudio.playing.value;
    if (_soundOnPause) unawaited(FocusAudio.pause());
  }

  void resume({DateTime? at}) {
    if (_since != null) return;
    _since = at ?? DateTime.now();
    _lastSeen = _since;
    _startTicker();
    _startHeartbeat();
    _persist();
    _sync();
    notifyListeners();
    if (!_soundOnPause) return;
    _soundOnPause = false;
    unawaited(FocusAudio.resume());
  }

  void continueNow() {
    if (!_awaiting && !(isPomodoro && reachedTarget)) return;
    _awaiting = false;
    unawaited(FocusAudio.stopAlert());
    _advancePhase();
  }

  void reset() {
    _awaiting = false;
    _switchIn = 0;
    _isCompleted = false;
    _savedCompletedSession = null;
    _pendingCompleted = null;
    unawaited(FocusAudio.stopAlert());
    _accumulated = 0;
    _runId = const Uuid().v4();
    _since = isRunning ? DateTime.now() : null;
    _lastSeen = _since;
    _celebrated = false;
    if (isRunning) {
      _startTicker();
      _startHeartbeat();
    }
    _persist();
    _sync();
    notifyListeners();
  }

  void addMinute() {
    if (!_open || isFlow) return;
    _awaiting = false;
    _switchIn = 0;
    unawaited(FocusAudio.stopAlert());
    if (reachedTarget) {
      _accumulated = targetSeconds;
      if (isRunning) _since = DateTime.now();
    }
    _targetMinutes++;
    _lastSeen = DateTime.now();
    _celebrated = false;
    if (isRunning) _startTicker();
    _persist();
    _sync();
    notifyListeners();
  }

  void skipBreak() {
    _awaiting = false;
    unawaited(FocusAudio.stopAlert());
    if (_isBreak) _advancePhase();
  }

  void addTask() {
    _tasks.add(FocusTask(id: DateTime.now().microsecondsSinceEpoch.toString()));
    notifyListeners();
  }

  void setTaskTitle(String id, String title) {
    for (final task in _tasks) {
      if (task.id == id) task.title = title;
    }
  }

  void toggleTask(String id) {
    for (final task in _tasks) {
      if (task.id == id) task.done = !task.done;
    }
    notifyListeners();
  }

  void removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<FocusSession?> apply(FocusAction action) async {
    if (!_open) return null;
    switch (action.kind) {
      case FocusAction.pause:
        pause(at: action.at);
      case FocusAction.resume:
        resume(at: action.at);
      case FocusAction.stop:
        return stop(completed: reachedTarget || isFlow, at: action.at);
      case FocusAction.minute:
        addMinute();
      case FocusAction.skip:
        skipBreak();
      case FocusAction.next:
        continueNow();
    }
    return null;
  }

  Future<FocusSession?> finishCompleted() async {
    final session = _savedCompletedSession;
    await _clearActive();
    notifyListeners();
    return session;
  }

  Future<void> _clearActive() async {
    _stopTicker();
    _stopHeartbeat();
    _awaiting = false;
    _switchIn = 0;
    unawaited(FocusAudio.stopAlert());
    if (FocusAudio.current.value.isNotEmpty) unawaited(FocusAudio.stop());
    _accumulated = 0;
    _since = null;
    _lastSeen = null;
    _habitId = '';
    _labelIds = [];
    _tasks.clear();
    _celebrated = false;
    _isBreak = false;
    _soundOnBreak = false;
    _soundOnPause = false;
    _breakMinutes = 0;
    _round = 1;
    _open = false;
    _isCompleted = false;
    _savedCompletedSession = null;
    _pendingCompleted = null;
    _runId = '';
    _sync();
    await LocalStore.writeSetting('focusActive', <String, dynamic>{});
  }

  Future<FocusSession?> stop({required bool completed, DateTime? at}) async {
    if (_isCompleted) return finishCompleted();
    final endedAt = at ?? DateTime.now();
    final dropped = isPomodoro &&
        !completed &&
        LocalStore.setting('focusWholeRounds', false);
    final seconds = _isBreak || dropped ? 0 : elapsedAt(endedAt);
    final labelIds = [..._labelIds];
    final habitId = _habitId;
    final target = _focusMinutes;
    final runId = _runId;

    if (seconds < 30 || runId.isEmpty) {
      await _clearActive();
      notifyListeners();
      return null;
    }

    final session = FocusSession(
      id: runId,
      habitId: habitId,
      targetMinutes: target,
      seconds: seconds,
      completed: completed,
      startedAt: endedAt.subtract(Duration(seconds: seconds)),
      endedAt: endedAt,
      labelIds: labelIds,
    );
    await _keep(session);
    await _handOff(session);
    await _clearActive();
    notifyListeners();
    return session;
  }

  Future<void> _saveRound(FocusSession session) async {
    await _keep(session);
    notifyListeners();
    await _handOff(session);
  }

  Future<void> _finishNaturally() async {
    _stopTicker();
    _stopHeartbeat();
    _awaiting = false;
    _switchIn = 0;
    final endedAt = _lastSeen = DateTime.now();
    final seconds = elapsedAt(endedAt);
    final session = FocusSession(
      id: _runId.isEmpty ? const Uuid().v4() : _runId,
      habitId: _habitId,
      targetMinutes: _focusMinutes,
      seconds: seconds,
      completed: true,
      startedAt: endedAt.subtract(Duration(seconds: seconds)),
      endedAt: endedAt,
      labelIds: [..._labelIds],
    );
    _isCompleted = true;
    _savedCompletedSession = session;
    _pendingCompleted = session;
    _accumulated = seconds;
    _since = null;
    _persist();
    _sync();
    notifyListeners();

    try {
      await _keep(session);
      final saved = _sessionById(session.id) ?? session;
      _savedCompletedSession = saved;
      await _handOff(saved);
      final updated = _sessionById(session.id) ?? saved;
      _savedCompletedSession = updated;
      _pendingCompleted = null;
      _persist();
    } catch (e) {
      debugPrint('Could not credit a completed focus session: $e');
    }
    notifyListeners();
  }

  void _advancePhase() {
    final endedAt = _lastSeen = DateTime.now();
    if (!_isBreak) {
      final seconds = elapsedAt(endedAt);
      if (seconds >= 30) {
        unawaited(
          _saveRound(
            FocusSession(
              id: _runId.isEmpty ? const Uuid().v4() : _runId,
              habitId: _habitId,
              targetMinutes: _focusMinutes,
              seconds: seconds,
              completed: true,
              startedAt: endedAt.subtract(Duration(seconds: seconds)),
              endedAt: endedAt,
              labelIds: [..._labelIds],
            ),
          ),
        );
      }
      _runId = const Uuid().v4();
    } else {
      _round++;
    }
    _isBreak = !_isBreak;
    _awaiting = false;
    _switchIn = 0;
    _targetMinutes = !_isBreak
        ? _focusMinutes
        : isLongBreak
        ? _longBreakMinutes
        : _breakMinutes;
    _accumulated = 0;
    _since = DateTime.now();
    _lastSeen = _since;
    _celebrated = false;
    _startTicker();
    _startHeartbeat();
    _persist();
    _sync();
    notifyListeners();
    unawaited(_holdSound());
  }

  Future<void> _holdSound() async {
    try {
      if (_isBreak) {
        _soundOnBreak = FocusAudio.playing.value;
        if (_soundOnBreak) await FocusAudio.pause();
      } else if (_soundOnBreak) {
        _soundOnBreak = false;
        await FocusAudio.resume();
      }
    } catch (e) {
      debugPrint('Focus sound hold failed: $e');
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_switchIn > 0) {
        if (--_switchIn == 0) return _advancePhase();
        _sync();
        return _tick();
      }
      if (!_celebrated && reachedTarget) {
        _celebrated = true;
        completedTick.value++;
        if (!isMobile) unawaited(_announceEnd(breakEnded: _isBreak));
        final always = isPomodoro && LocalStore.setting('focusHold', false);
        final hold = always || (isPomodoro && _isBreak);
        unawaited(
          FocusAudio.alert(
            LocalStore.setting('focusAlert', ''),
            loop: always,
          ),
        );
        if (hold) {
          _awaiting = true;
          _stopTicker();
          _persist();
          _sync();
          notifyListeners();
        } else if (isPomodoro) {
          _switchIn = switchDelay;
          _sync();
        } else {
          unawaited(_finishNaturally());
        }
      }
      _tick();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_open || !isRunning) return;
      _lastSeen = DateTime.now();
      _persist();
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  int get _anchorMs {
    final since = _since;
    if (since == null) return 0;
    final began = since.millisecondsSinceEpoch - _accumulated * 1000;
    return isFlow ? began : began + targetSeconds * 1000 + 999;
  }

  Future<(String, String)> _endTexts({required bool breakEnded}) async {
    final strings = await NotificationService().localizations();
    if (breakEnded) return (strings.focus_break_over, strings.focus_notif_back);
    if (isPomodoro) return (strings.focus_done_title, strings.focus_notif_break);
    return (strings.focus_done_title, strings.focus_notif_body);
  }

  Future<void> _announceEnd({required bool breakEnded}) async {
    final (title, body) = await _endTexts(breakEnded: breakEnded);
    await NotificationService().showFocusEnd(
      title: title,
      body: body,
      habitId: _habitId,
    );
  }

  Future<void> _syncEndAlarm() async {
    final notifications = NotificationService();
    try {
      if (!_open || !isRunning) return await notifications.cancelFocusEnd();
      if (isFlow || reachedTarget || !isMobile) return;
      if (Platform.isAndroid) return await notifications.cancelFocusEnd();
      final (title, body) = await _endTexts(breakEnded: _isBreak);
      await notifications.scheduleFocusEnd(
        title: title,
        body: body,
        after: Duration(seconds: remainingSeconds),
      );
    } catch (e) {
      debugPrint('Focus end alarm failed: $e');
    }
  }

  Future<void> _pushed = Future.value();

  void _sync() {
    _pushed = _pushed.then((_) => _push());
  }

  Future<void> _push() async {
    unawaited(_syncEndAlarm());
    try {
      if (!_open || _isCompleted) {
        await FocusService.hide();
        return;
      }
      final strings = await NotificationService().localizations();
      if (!_open || _isCompleted) {
        await FocusService.hide();
        return;
      }
      final habit = _habitId.isEmpty ? null : LocalStore.habitName(_habitId);
      final labelText = labelNames(_labelIds).join(', ');
      final name = labelText.isEmpty
          ? habit
          : habit == null
          ? labelText
          : '$habit · $labelText';
      final done = _awaiting || _switchIn > 0 || (reachedTarget && !isPomodoro);
      final label = _awaiting
          ? strings.focus_continue
          : _switchIn > 0
          ? (_isBreak ? strings.focus_back_in : strings.focus_break_in)('$_switchIn')
          : done
          ? strings.focus_target_reached
          : _isBreak
              ? (isLongBreak ? strings.focus_long_break : strings.focus_break)
              : !isRunning
                  ? strings.focus_paused
                  : isFlow
                      ? strings.focus_flowtime
                      : strings.focus_notif_running;
      final phase = _awaiting
          ? 'waiting'
          : done
          ? 'done'
          : _isBreak
              ? 'break'
              : isRunning
                  ? 'running'
                  : 'paused';
      final (endTitle, endBody) = await _endTexts(breakEnded: _isBreak);
      await FocusService.show(
        habitId: _habitId,
        title: name ?? strings.focus,
        state: isPomodoro
            ? '$label  ·  ${strings.focus_round(_round)}'
            : label,
        phase: phase,
        running: isRunning && !done,
        done: done,
        countDown: !isFlow,
        seconds: displaySeconds,
        anchor: _anchorMs,
        total: isFlow ? 0 : targetSeconds,
        channelName: strings.focus_notif_channel,
        pauseLabel: strings.focus_pause,
        resumeLabel: strings.focus_resume,
        stopLabel: strings.focus_end,
        continueLabel: strings.focus_continue,
        skipLabel: strings.focus_skip_break,
        minuteLabel: '+${strings.minutes_short('1')}',
        endTitle: endTitle,
        endBody: endBody,
      );
    } catch (e) {
      debugPrint('Focus notification sync failed: $e');
    }
  }

  static const maxLabels = 50;

  static const defaultTagColors = [
    Color(0xFF3B82F6),
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFF43F5E),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
  ];

  List<FocusLabel> get allLabels => List.unmodifiable(_labels);

  List<FocusLabel> get labels {
    final active = _labels.where((label) => !label.archived).toList();
    final byName = (FocusLabel a, FocusLabel b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    final result = <FocusLabel>[];
    for (final parent in active.where((label) => label.parentId == null).toList()
      ..sort(byName)) {
      result.add(parent);
      final children =
          active.where((label) => label.parentId == parent.id).toList()
            ..sort(byName);
      result.addAll(children);
    }
    final topIds = active
        .where((label) => label.parentId == null)
        .map((label) => label.id)
        .toSet();
    for (final orphan in active.where(
      (label) => label.parentId != null && !topIds.contains(label.parentId),
    )) {
      result.add(orphan);
    }
    return List.unmodifiable(result);
  }

  List<FocusLabel> childrenOf(String parentId) => List.unmodifiable(
        _labels.where((label) => !label.archived && label.parentId == parentId),
      );

  FocusLabel? labelById(String id) {
    for (final label in _labels) {
      if (label.id == id) return label;
    }
    return null;
  }

  String labelName(String id) => labelById(id)?.name ?? '';

  String labelDisplayName(String id) {
    final label = labelById(id);
    if (label == null) return '';
    final parent = label.parentId == null ? null : labelById(label.parentId!);
    return parent == null ? label.name : '${parent.name} > ${label.name}';
  }

  List<String> labelNames(Iterable<String> ids) {
    final names = <String>[];
    for (final id in ids) {
      final name = labelDisplayName(id);
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
    return names;
  }

  Color colorForLabel(String id) {
    final label = labelById(id);
    if (label != null) return label.color;
    final hash = id.hashCode.abs();
    return defaultTagColors[hash % defaultTagColors.length];
  }

  bool labelNameTaken(String name, {String? parentId, String? exceptId}) {
    final clean = name.trim().toLowerCase();
    return _labels.any(
      (label) =>
          !label.archived &&
          label.id != exceptId &&
          label.parentId == parentId &&
          label.name.toLowerCase() == clean,
    );
  }

  Future<FocusLabel?> createLabel({
    required String name,
    Color? color,
    String? parentId,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    if (parentId != null) {
      final parent = labelById(parentId);
      if (parent == null || parent.archived || parent.isChild) parentId = null;
    }
    final existing = _labels.where(
      (label) =>
          !label.archived &&
          label.parentId == parentId &&
          label.name.toLowerCase() == clean.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first;
    if (_labels.where((label) => !label.archived).length >= maxLabels) {
      return null;
    }
    final id = const Uuid().v4();
    final value = (color ??
            defaultTagColors[clean.toLowerCase().hashCode.abs() %
                defaultTagColors.length])
        .toARGB32();
    final label = FocusLabel(
      id: id,
      name: clean,
      colorValue: value,
      parentId: parentId,
    );
    _labels.add(label);
    await LocalStore.writeFocusLabels(_labels);
    notifyListeners();
    return label;
  }

  Future<bool> renameLabel(String id, String name, {Color? color}) async {
    final index = _labels.indexWhere((label) => label.id == id);
    if (index == -1) return false;
    final clean = name.trim();
    if (clean.isEmpty) return false;
    final current = _labels[index];
    if (labelNameTaken(clean, parentId: current.parentId, exceptId: id)) {
      return false;
    }
    _labels[index] = FocusLabel(
      id: current.id,
      name: clean,
      colorValue: (color ?? current.color).toARGB32(),
      parentId: current.parentId,
      archived: current.archived,
    );
    await LocalStore.writeFocusLabels(_labels);
    notifyListeners();
    return true;
  }

  Future<void> archiveLabel(String id) async {
    final ids = {
      id,
      ..._labels.where((label) => label.parentId == id).map((label) => label.id),
    };
    var changed = false;
    for (var i = 0; i < _labels.length; i++) {
      if (ids.contains(_labels[i].id) && !_labels[i].archived) {
        _labels[i] = _labels[i].copyWith(archived: true);
        changed = true;
      }
    }
    if (!changed) return;
    await LocalStore.writeFocusLabels(_labels);
    notifyListeners();
  }

  Future<void> deleteLabelPermanently(String id) async {
    final ids = {
      id,
      ..._labels.where((label) => label.parentId == id).map((label) => label.id),
    };
    _labels.removeWhere((label) => ids.contains(label.id));
    await LocalStore.writeFocusLabels(_labels);
    for (var i = 0; i < _sessions.length; i++) {
      final session = _sessions[i];
      if (!session.labelIds.any(ids.contains)) continue;
      final updated = session.copyWith(
        labelIds: session.labelIds.where((labelId) => !ids.contains(labelId))
            .toList(),
      );
      _sessions[i] = updated;
      await LocalStore.writeFocusSession(updated);
    }
    notifyListeners();
  }

  Future<void> deleteLabel(String id, {bool permanent = false}) =>
      permanent ? deleteLabelPermanently(id) : archiveLabel(id);

  List<FocusSession> get _allSlices =>
      _slices ??= [for (final session in _sessions) ...session.slices()];

  int get totalSeconds =>
      _sessions.fold(0, (sum, session) => sum + session.seconds);

  int get sessionCount => _sessions.length;

  int secondsForHabit(String habitId) => _sessions
      .where((s) => s.habitId == habitId)
      .fold(0, (sum, session) => sum + session.seconds);

  int secondsForDay(DateTime day) => _allSlices
      .where((s) => s.countedOn.dayKey == day.dayKey)
      .fold(0, (sum, session) => sum + session.seconds);

  int secondsForHabitSince(String habitId, DateTime from) => _allSlices
      .where((s) =>
          s.habitId == habitId && !s.countedOn.atMidnight.isBefore(from))
      .fold(0, (sum, session) => sum + session.seconds);

  List<FocusSession> sessionsForHabitOnDay(String habitId, DateTime day) =>
      _allSlices
          .where((s) => s.habitId == habitId && s.countedOn.dayKey == day.dayKey)
          .toList();

  Map<String, int> get _secondsPerDay => _perDay ??= _sumPerDay();

  Map<String, int> _sumPerDay() {
    final sums = <String, int>{};
    for (final session in _allSlices) {
      final key = '${session.habitId}|${session.countedOn.dayKey}';
      sums[key] = (sums[key] ?? 0) + session.seconds;
    }
    return sums;
  }

  int secondsForHabitOnDay(String habitId, DateTime day) =>
      _secondsPerDay['$habitId|${day.dayKey}'] ?? 0;

  Future<void> removeForHabit(String habitId) async {
    _sessions.removeWhere((s) => s.habitId == habitId);
    await LocalStore.removeFocusFor(habitId);
    notifyListeners();
  }

  static const _dailyTargetsKey = 'focusDailyTargets';
  static const _weeklyTargetsKey = 'focusWeeklyTargets';

  int dailyTargetFor(DateTime date, int defaultMinutes) {
    final map = LocalStore.settingMap(_dailyTargetsKey);
    final val = map[date.dayKey];
    if (val is int) return val;
    if (val is num) return val.toInt();
    return defaultMinutes;
  }

  Future<void> setDailyTarget(DateTime date, int minutes) async {
    final map = LocalStore.settingMap(_dailyTargetsKey);
    map[date.dayKey] = minutes;
    await LocalStore.writeSetting(_dailyTargetsKey, map);
    notifyListeners();
  }

  static String weekKey(DateTime date, int weekStart) =>
      date.startOfWeek(weekStart).dayKey;

  int weeklyTargetFor(DateTime date, int defaultHours, {int weekStart = 1}) {
    final map = LocalStore.settingMap(_weeklyTargetsKey);
    final key = weekKey(date, weekStart);
    final val = map[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    return defaultHours;
  }

  Future<void> setWeeklyTarget(DateTime date, int hours, {int weekStart = 1}) async {
    final map = LocalStore.settingMap(_weeklyTargetsKey);
    final key = weekKey(date, weekStart);
    map[key] = hours;
    await LocalStore.writeSetting(_weeklyTargetsKey, map);
    notifyListeners();
  }

  DateTime? get firstSessionDate {
    if (_sessions.isEmpty) return null;
    DateTime? first;
    for (final s in _allSlices) {
      final d = s.countedOn;
      if (first == null || d.isBefore(first)) {
        first = d;
      }
    }
    return first;
  }

  int get totalActiveDaysCount {
    if (_sessions.isEmpty) return 0;
    final days = <String>{};
    for (final s in _allSlices) {
      days.add(s.countedOn.dayKey);
    }
    return days.length;
  }

  int get totalElapsedDaysSinceStart {
    final first = firstSessionDate;
    if (first == null) return 0;
    final now = AppClock.now().atMidnight;
    final start = first.atMidnight;
    final diff = now.difference(start).inDays + 1;
    return diff <= 0 ? 1 : diff;
  }

  Map<int, double> get weekdayAverageSeconds {
    final first = firstSessionDate;
    if (first == null || _sessions.isEmpty) {
      return {for (var i = 1; i <= 7; i++) i: 0.0};
    }
    final today = AppClock.now().atMidnight;
    final start = first.atMidnight;

    final weekdayOccurrences = <int, int>{for (var i = 1; i <= 7; i++) i: 0};
    var cursor = start;
    while (!cursor.isAfter(today)) {
      weekdayOccurrences[cursor.weekday] = (weekdayOccurrences[cursor.weekday] ?? 0) + 1;
      cursor = cursor.addDays(1);
    }

    final weekdayTotals = <int, int>{for (var i = 1; i <= 7; i++) i: 0};
    for (final session in _allSlices) {
      final weekday = session.countedOn.weekday;
      weekdayTotals[weekday] = (weekdayTotals[weekday] ?? 0) + session.seconds;
    }

    final averages = <int, double>{};
    for (var i = 1; i <= 7; i++) {
      final occurrences = weekdayOccurrences[i] ?? 0;
      averages[i] = occurrences == 0 ? 0.0 : (weekdayTotals[i] ?? 0) / occurrences;
    }
    return averages;
  }

  Map<int, double> get currentMonthWeekdayAverageSeconds {
    final now = AppClock.now();
    final startOfMonth = DateTime(now.year, now.month, 1).atMidnight;
    final today = now.atMidnight;

    final weekdayOccurrences = <int, int>{for (var i = 1; i <= 7; i++) i: 0};
    var cursor = startOfMonth;
    while (!cursor.isAfter(today)) {
      weekdayOccurrences[cursor.weekday] = (weekdayOccurrences[cursor.weekday] ?? 0) + 1;
      cursor = cursor.addDays(1);
    }

    final weekdayTotals = <int, int>{for (var i = 1; i <= 7; i++) i: 0};
    for (final session in _allSlices) {
      final d = session.countedOn;
      if (d.year == now.year && d.month == now.month) {
        weekdayTotals[d.weekday] = (weekdayTotals[d.weekday] ?? 0) + session.seconds;
      }
    }

    final averages = <int, double>{};
    for (var i = 1; i <= 7; i++) {
      final occurrences = weekdayOccurrences[i] ?? 0;
      averages[i] = occurrences == 0 ? 0.0 : (weekdayTotals[i] ?? 0) / occurrences;
    }
    return averages;
  }

  int get currentStreak =>
      focusStreaks(_allSlices, now: AppClock.now()).current;

  List<MapEntry<String, int>> labelRankingForPeriod(String period, int weekStart) {
    final now = AppClock.now();
    DateTime from;
    if (period == 'week') {
      from = now.startOfWeek(weekStart).atMidnight;
    } else if (period == 'month') {
      from = DateTime(now.year, now.month, 1).atMidnight;
    } else {
      from = DateTime(1970);
    }

    final map = <String, int>{};
    for (final session in _allSlices) {
      if (!session.countedOn.atMidnight.isBefore(from)) {
        for (final labelId in session.labelIds) {
          if (labelId.isNotEmpty) {
            map[labelId] = (map[labelId] ?? 0) + session.seconds;
          }
        }
      }
    }
    return (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Map<String, int> get monthlyTotalSeconds {
    final totals = <String, int>{};
    final now = AppClock.now();
    for (var i = 5; i >= 0; i--) {
      final dt = DateTime(now.year, now.month - i);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      totals[key] = 0;
    }
    for (final s in _allSlices) {
      final dt = s.countedOn;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      if (totals.containsKey(key)) {
        totals[key] = (totals[key] ?? 0) + s.seconds;
      }
    }
    return totals;
  }

  ({int morningSec, int afternoonSec, int eveningSec, int nightSec, int totalSec})
      timeOfDayBreakdown({required bool isWeekly, required DateTime now, required int weekStart}) {
    var morning = 0;
    var afternoon = 0;
    var evening = 0;
    var night = 0;

    final weekFrom = now.startOfWeek(weekStart).atMidnight;
    final weekTo = weekFrom.addDays(7);
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    for (final session in _allSlices) {
      final dt = session.countedOn;
      if (isWeekly) {
        if (dt.isBefore(weekFrom) || !dt.isBefore(weekTo)) continue;
      } else {
        if (dt.isBefore(monthStart) || !dt.isBefore(monthEnd)) continue;
      }

      final hour = session.startedAt.toLocal().hour;
      final sec = session.seconds;

      if (hour >= 4 && hour < 11) {
        morning += sec;
      } else if (hour >= 11 && hour < 17) {
        afternoon += sec;
      } else if (hour >= 17 && hour < 22) {
        evening += sec;
      } else {
        night += sec;
      }
    }

    final total = morning + afternoon + evening + night;

    return (
      morningSec: morning,
      afternoonSec: afternoon,
      eveningSec: evening,
      nightSec: night,
      totalSec: total,
    );
  }

  @override
  void dispose() {
    _stopTicker();
    _stopHeartbeat();
    super.dispose();
  }
}
