import 'package:flutter/material.dart';

class FocusLabel {
  const FocusLabel({
    required this.id,
    required this.name,
    required this.colorValue,
    this.parentId,
    this.archived = false,
  });

  final String id;
  final String name;
  final int colorValue;
  final String? parentId;
  final bool archived;

  bool get isChild => parentId != null;

  Color get color => Color(colorValue);

  FocusLabel copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? parentId,
    bool? archived,
  }) =>
      FocusLabel(
        id: id ?? this.id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        parentId: parentId ?? this.parentId,
        archived: archived ?? this.archived,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': colorValue,
        if (parentId != null) 'parentId': parentId,
        if (archived) 'archived': true,
      };

  factory FocusLabel.fromMap(Map<String, dynamic> map) => FocusLabel(
        id: map['id'] as String,
        name: (map['name'] ?? '') as String,
        colorValue: ((map['color'] ?? 0) as num).toInt(),
        parentId: map['parentId'] is String && (map['parentId'] as String).isNotEmpty
            ? map['parentId'] as String
            : null,
        archived: map['archived'] == true,
      );
}
