import 'package:cloud_firestore/cloud_firestore.dart';

class Bit {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bit({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Bit.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Bit(
        id: data['id'],
        title: data['title'],
        body: data['body'],
        userId: data['userId'],
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        updatedAt: (data['updatedAt'] as Timestamp).toDate());
  }
}