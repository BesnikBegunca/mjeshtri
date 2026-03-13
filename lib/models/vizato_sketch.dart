import 'dart:convert';
import 'package:flutter/material.dart';

enum DrawTool {
  line,
  rect,
  text,
}

class SketchItem {
  final String type; // line, rect, text
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String label;
  final String colorHex;
  final double strokeWidth;

  SketchItem({
    required this.type,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.label,
    required this.colorHex,
    required this.strokeWidth,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'label': label,
      'colorHex': colorHex,
      'strokeWidth': strokeWidth,
    };
  }

  factory SketchItem.fromMap(Map<String, dynamic> map) {
    return SketchItem(
      type: (map['type'] ?? '').toString(),
      x1: (map['x1'] ?? 0).toDouble(),
      y1: (map['y1'] ?? 0).toDouble(),
      x2: (map['x2'] ?? 0).toDouble(),
      y2: (map['y2'] ?? 0).toDouble(),
      label: (map['label'] ?? '').toString(),
      colorHex: (map['colorHex'] ?? '#FF000000').toString(),
      strokeWidth: (map['strokeWidth'] ?? 2).toDouble(),
    );
  }

  String toJsonString() => jsonEncode(toMap());

  factory SketchItem.fromJsonString(String source) =>
      SketchItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class SketchProject {
  final int? id;
  final String name;
  final String notes;
  final String itemsJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  SketchProject({
    this.id,
    required this.name,
    required this.notes,
    required this.itemsJson,
    required this.createdAt,
    required this.updatedAt,
  });

  List<SketchItem> get items {
    final raw = jsonDecode(itemsJson);
    if (raw is! List) return [];
    return raw
        .map((e) => SketchItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  SketchProject copyWith({
    int? id,
    String? name,
    String? notes,
    String? itemsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SketchProject(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      itemsJson: itemsJson ?? this.itemsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      'items_json': itemsJson,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SketchProject.fromMap(Map<String, dynamic> map) {
    return SketchProject(
      id: map['id'] as int?,
      name: (map['name'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      itemsJson: (map['items_json'] ?? '[]').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

String colorToHex(Color c) {
  return '#'
          '${c.alpha.toRadixString(16).padLeft(2, '0')}'
          '${c.red.toRadixString(16).padLeft(2, '0')}'
          '${c.green.toRadixString(16).padLeft(2, '0')}'
          '${c.blue.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

Color colorFromHex(String hex) {
  final value = hex.replaceAll('#', '');
  final normalized = value.length == 6 ? 'FF$value' : value;
  return Color(int.parse(normalized, radix: 16));
}
