import 'package:streak/core/extensions/date_extensions.dart';

class FocusSession {
  FocusSession({
    required this.id,
    required this.habitId,
    required this.targetMinutes,
    required this.seconds,
    required this.completed,
    required this.startedAt,
    required this.endedAt,
    this.counted = false,
    List<String> labelIds = const [],
    this.schema = 2,
  }) : labelIds = List.unmodifiable(labelIds.where((id) => id.isNotEmpty));

  final String id;
  final String habitId;
  final int targetMinutes;
  final int seconds;
  final bool completed;
  final DateTime startedAt;
  final DateTime endedAt;
  final bool counted;
  final List<String> labelIds;
  final int schema;

  int get minutes => seconds ~/ 60;

  DateTime get countedOn => logicalDayOf(endedAt);

  static DateTime logicalDayOf(DateTime moment) =>
      moment.subtract(const Duration(seconds: 1)).subtract(
            Duration(hours: AppClock.cutoffHour),
          ).atMidnight;

  List<FocusSession> slices() {
    if (seconds <= 0 || !endedAt.isAfter(startedAt)) return [this];

    final pieces = <FocusSession>[];
    var start = startedAt;
    var left = seconds;
    while (left > 0) {
      final border = dayBorderAfter(start);
      final span = border.difference(start).inSeconds;
      if (span <= 0) break;
      final take = left < span ? left : span;
      final end = start.add(Duration(seconds: take));
      left -= take;
      pieces.add(
        _pieceOf(
          pieces.length + 1,
          start,
          end,
          take,
          last: left <= 0,
        ),
      );
      start = end;
    }
    if (pieces.isEmpty) return [this];
    if (pieces.length == 1 && left <= 0) return [this];
    return pieces;
  }

  List<FocusSession> split() => slices();

  FocusSession _pieceOf(
    int index,
    DateTime start,
    DateTime end,
    int span, {
    required bool last,
  }) =>
      FocusSession(
        id: index == 1 ? id : '$id-$index',
        habitId: habitId,
        targetMinutes: targetMinutes,
        seconds: span,
        completed: completed && last,
        startedAt: start,
        endedAt: end,
        counted: counted,
        labelIds: labelIds,
        schema: schema,
      );

  FocusSession get asCounted => FocusSession(
        id: id,
        habitId: habitId,
        targetMinutes: targetMinutes,
        seconds: seconds,
        completed: completed,
        startedAt: startedAt,
        endedAt: endedAt,
        counted: true,
        labelIds: labelIds,
        schema: schema,
      );

  FocusSession copyWith({
    String? id,
    String? habitId,
    int? targetMinutes,
    int? seconds,
    bool? completed,
    DateTime? startedAt,
    DateTime? endedAt,
    bool? counted,
    List<String>? labelIds,
  }) =>
      FocusSession(
        id: id ?? this.id,
        habitId: habitId ?? this.habitId,
        targetMinutes: targetMinutes ?? this.targetMinutes,
        seconds: seconds ?? this.seconds,
        completed: completed ?? this.completed,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        counted: counted ?? this.counted,
        labelIds: labelIds ?? this.labelIds,
        schema: schema,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'habitId': habitId,
        'targetMinutes': targetMinutes,
        'seconds': seconds,
        'completed': completed,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'schema': 2,
        if (counted) 'counted': true,
        if (labelIds.isNotEmpty) 'labelIds': labelIds,
      };

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    final startedAt = DateTime.tryParse((map['startedAt'] ?? '') as String) ??
        DateTime.now();
    final seconds = ((map['seconds'] ?? 0) as num).toInt();
    final endedAt = DateTime.tryParse((map['endedAt'] ?? '') as String) ??
        startedAt.add(Duration(seconds: seconds));
    final rawLabels = map['labelIds'];
    final labelIds = rawLabels is List
        ? rawLabels
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList()
        : <String>[];

    return FocusSession(
      id: map['id'] as String,
      habitId: (map['habitId'] ?? '') as String,
      targetMinutes: ((map['targetMinutes'] ?? 0) as num).toInt(),
      seconds: seconds,
      completed: (map['completed'] ?? false) as bool,
      startedAt: startedAt,
      endedAt: endedAt,
      counted: map['counted'] == true,
      labelIds: labelIds,
    );
  }
}

DateTime dayBorderAfter(DateTime moment) {
  var day = moment
      .subtract(Duration(hours: AppClock.cutoffHour))
      .atMidnight
      .addDays(1);
  var border = DateTime(day.year, day.month, day.day, AppClock.cutoffHour);
  if (!border.isAfter(moment)) {
    day = day.addDays(1);
    border = DateTime(day.year, day.month, day.day, AppClock.cutoffHour);
  }
  return border;
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
}

String formatHoursShort(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0 && m == 0) return '${seconds}s';
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
