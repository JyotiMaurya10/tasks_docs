class CursorModel {
  final String userId;
  final String displayName; // anonymous id or display name
  final int baseOffset; // caret index in text
  final int extentOffset; // selection end
  final int colorIndex; // choose color to show
  final DateTime? updatedAt; // timestamp for activity tracking

  CursorModel({
    required this.userId,
    required this.displayName,
    required this.baseOffset,
    required this.extentOffset,
    required this.colorIndex,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'displayName': displayName,
    'baseOffset': baseOffset,
    'extentOffset': extentOffset,
    'colorIndex': colorIndex,
    'updatedAt': updatedAt,
  };

  factory CursorModel.fromMap(Map<String, dynamic> m) => CursorModel(
    userId: m['userId'],
    displayName: m['displayName'] ?? m['userId'],
    baseOffset: (m['baseOffset'] ?? 0) as int,
    extentOffset: (m['extentOffset'] ?? 0) as int,
    colorIndex: (m['colorIndex'] ?? 0) as int,
    updatedAt: m['updatedAt'] != null ? DateTime.fromMillisecondsSinceEpoch((m['updatedAt'] as dynamic).millisecondsSinceEpoch as int) : null,
  );
}
