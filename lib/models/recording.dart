import 'package:cloud_firestore/cloud_firestore.dart';

class Recording {
  final String id;
  final String title;
  final String filePath;
  final String setListId;
  final String audioUrl;
  final Timestamp createdAt;

  Recording({
    required this.id,
    required this.title,
    required this.filePath,
    required this.setListId,
    required this.audioUrl,
    required this.createdAt,
  });

  Recording copyWith({
    String? id,
    String? title,
    String? filePath,
    String? setListId,
    String? audioUrl,
    Timestamp? createdAt,
  }) {
    return Recording(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      setListId: setListId ?? this.setListId,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Recording.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Recording(
      id: doc.id,
      title: data['title'] ?? '',
      filePath: data['filePath'] ?? '',
      setListId: data['setListId'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'filePath': filePath,
      'setListId': setListId,
      'audioUrl': audioUrl,
      'createdAt': createdAt,
    };
  }
}