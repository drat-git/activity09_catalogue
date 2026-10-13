class Folder {
  const Folder({this.id, required this.name, required this.createdAt, this.cardCount = 0});
  final int? id;
  final String name;
  final String createdAt;
  final int cardCount;

  factory Folder.fromMap(Map<String, dynamic> row) => Folder(
    id: row['id'] as int,
    name: row['name'] as String,
    createdAt: row['created_at'] as String,
    cardCount: row['card_count'] as int? ?? 0,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'created_at': createdAt,
  };
}

class CardRecord {
  const CardRecord({this.id, required this.title, required this.suit,
    required this.folderId, this.notes = '', this.imageRef});
  static const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
  final int? id;
  final String title;
  final String suit;
  final int folderId;
  final String notes;
  final String? imageRef;

  factory CardRecord.fromMap(Map<String, dynamic> row) => CardRecord(
    id: row['id'] as int,
    title: row['title'] as String,
    suit: row['suit'] as String,
    folderId: row['folder_id'] as int,
    notes: row['notes'] as String,
    imageRef: row['image_ref'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'suit': suit,
    'notes': notes,
    'image_ref': imageRef,
    'folder_id': folderId,
  };
}
