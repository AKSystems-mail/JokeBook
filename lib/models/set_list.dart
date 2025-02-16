import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

part 'set_list.g.dart';

final _logger = Logger('SetList');

@HiveType(typeId: 1)
class SetList extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  List<String> bits;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  SetList({
    required this.id,
    required this.title,
    required this.date,
    required this.bits,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SetList.fromFirestore(DocumentSnapshot doc) {
    if (doc.data() == null) {
      _logger.info('Error: Document data is null');
      return SetList(
        id: doc.id,
        title: '',
        date: DateTime.now(),
        bits: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    if (!data['bits'].every((element) => element is String)) {
      _logger.info('Error: bits field contains non-string elements');
      throw ArgumentError('bits field must contain only strings');
    }
    return SetList(
      id: doc.id,
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      bits: List<String>.from(data['bits'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'bits': bits,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
