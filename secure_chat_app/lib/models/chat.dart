/// Represents one chat room. Key is stored separately in secure storage.
/// [autoDeleteAfter] null = manual, 3600 = 1h, 86400 = 24h, 604800 = 7 days.
class Chat {
  final String id;
  final String name;
  final String myAlias;
  final bool qrDismissed;
  final bool isCreator;
  final int? autoDeleteAfter;

  const Chat({
    required this.id,
    required this.name,
    required this.myAlias,
    required this.qrDismissed,
    required this.isCreator,
    this.autoDeleteAfter,
  });

  Chat copyWith({
    String? id,
    String? name,
    String? myAlias,
    bool? qrDismissed,
    bool? isCreator,
    int? autoDeleteAfter,
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      myAlias: myAlias ?? this.myAlias,
      qrDismissed: qrDismissed ?? this.qrDismissed,
      isCreator: isCreator ?? this.isCreator,
      autoDeleteAfter: autoDeleteAfter ?? this.autoDeleteAfter,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'myAlias': myAlias,
        'qrDismissed': qrDismissed,
        'isCreator': isCreator,
        if (autoDeleteAfter != null) 'autoDeleteAfter': autoDeleteAfter,
      };

  static Chat fromJson(Map<String, dynamic> json) => Chat(
        id: json['id'] as String,
        name: json['name'] as String,
        myAlias: json['myAlias'] as String,
        qrDismissed: json['qrDismissed'] as bool? ?? false,
        isCreator: json['isCreator'] as bool? ?? false,
        autoDeleteAfter: json['autoDeleteAfter'] as int?,
      );
}
