import 'package:cloud_firestore/cloud_firestore.dart';

class Recording {
  final String id;
  final String title;
  final String filePath;
  final String setListId;
  final String audioUrl;
  final Timestamp createdAt;
  final Duration duration; // Add this field

  Recording({
    required this.id,
    required this.title,
    required this.filePath,
    required this.setListId,
    required this.audioUrl,
    required this.createdAt,
    required this.duration, // Add this field
  });

  Recording copyWith({
    String? id,
    String? title,
    String? filePath,
    String? setListId,
    String? audioUrl,
    Timestamp? createdAt,
    Duration? duration, // Add this field
  }) {
    return Recording(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      setListId: setListId ?? this.setListId,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration, // Add this field
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
      duration: Duration(seconds: data['duration'] ?? 0), // Add this field
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'filePath': filePath,
      'setListId': setListId,
      'audioUrl': audioUrl,
      'createdAt': createdAt,
      'duration': duration.inSeconds, // Add this field
    };
  }

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      filePath: json['filePath'] ?? '',
      setListId: json['setListId'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      createdAt: Timestamp.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      duration: Duration(seconds: json['duration'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'setListId': setListId,
      'audioUrl': audioUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'duration': duration.inSeconds,
    };
  }
}