class ShowComment {
  final String id;
  final int dramaId;
  final String uid;
  final String author;
  final String? avatarUrl;
  final String content;
  final double rating;
  final int createdAt;
  final int updatedAt;

  const ShowComment({
    required this.id,
    required this.dramaId,
    required this.uid,
    required this.author,
    this.avatarUrl,
    required this.content,
    this.rating = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  ShowComment copyWith({
    String? id,
    int? dramaId,
    String? uid,
    String? author,
    String? avatarUrl,
    String? content,
    double? rating,
    int? createdAt,
    int? updatedAt,
  }) {
    return ShowComment(
      id: id ?? this.id,
      dramaId: dramaId ?? this.dramaId,
      uid: uid ?? this.uid,
      author: author ?? this.author,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      content: content ?? this.content,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      'dramaId': dramaId,
      'author': author,
      if (avatarUrl != null && avatarUrl!.isNotEmpty) 'avatarUrl': avatarUrl,
      'content': content,
      'rating': rating,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory ShowComment.fromFirestore(
    String id,
    int fallbackDramaId,
    Map<String, dynamic> data,
  ) {
    return ShowComment(
      id: id,
      dramaId: (data['dramaId'] as num?)?.toInt() ?? fallbackDramaId,
      uid: (data['uid'] as String?) ?? id,
      author: (data['author'] as String?)?.trim().isNotEmpty == true
          ? (data['author'] as String).trim()
          : 'Moglog Member',
      avatarUrl: data['avatarUrl'] as String?,
      content: (data['content'] as String?) ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (data['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}
