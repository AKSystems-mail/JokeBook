// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/models/bit.dart';
import '/models/set_list.dart';
import 'package:logging/logging.dart';
import '/models/recording.dart';

class FirestoreService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Logger _log = Logger('FirestoreService');

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get db => _db;

  Future<void> addBit(Bit bit) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Adding bit with ID ${bit.id} for user $userId');
    _log.info('Bit data: ${bit.toFirestore()}'); // Log toFirestore()

    return _db
        .collection('users')
        .doc(userId)
        .collection('bits')
        .doc(bit.id)
        .set(bit.toFirestore()) // Use toFirestore()
        .then((_) {
      _log.info('addBit function completed successfully');
    }).catchError((error) {
      _log.severe('Error adding bit to Firestore:', error);
      throw error;
    });
  }

  Future<void> updateBit(Bit bit) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _log.severe('User not authenticated!');
        throw Exception('User not authenticated!');
      }
      final userId = user.uid;
      _log.info('Updating bit with ID ${bit.id} for user $userId');
      await _db
          .collection('users')
          .doc(userId)
          .collection('bits')
          .doc(bit.id)
          .update(bit.toFirestore()); // Use toFirestore()
    } catch (e) {
      _log.severe('Error updating bit in Firestore:', e);
      rethrow;
    }
  }

  Future<void> deleteBit(String bitId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Deleting bit with ID $bitId for user $userId');
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('bits')
          .doc(bitId)
          .delete();
    } catch (e) {
      _log.severe('Error deleting bit in Firestore:', e);
      rethrow;
    }
  }

  Stream<List<SetList>> getSetListsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      return Stream.empty();
    }
    final userId = user.uid;
    _log.info('Getting all set lists for user $userId');
    return _db
        .collection('users')
        .doc(userId)
        .collection('setLists')
        .orderBy('order', descending: false)
        .snapshots()
        .map((snapshot) {
      _log.fine('Received ${snapshot.docs.length} set lists from Firestore');
      // *** CORRECTED: Pass the DocumentSnapshot directly ***
      return snapshot.docs.map((doc) => SetList.fromFirestore(doc)).toList();
          }).handleError((error) {
      _log.severe('Error getting set lists stream from Firestore:', error);
      return []; 
    });
  }

  Future<String> addSetList(SetList setList) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid; // Get userId for logging clarity

    Map<String, dynamic> dataToSet = setList.toFirestore();
    // Ensure server timestamps are used for new documents if not already set
    dataToSet['createdAt'] = dataToSet['createdAt'] ?? FieldValue.serverTimestamp();
    dataToSet['updatedAt'] = dataToSet['updatedAt'] ?? FieldValue.serverTimestamp();


    DocumentReference docRef = _db
        .collection('users')
        .doc(userId)
        .collection('setLists')
        .doc(); // Firestore generates ID

    await docRef.set(dataToSet); // Use the map which includes 'order'
    _log.info('addSetList function completed successfully for ID ${docRef.id}');
    return docRef.id; // Return the new ID
  }

  Future<void> updateSetList(SetList setList) async { // setList object now contains 'order'
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated for updateSetList!');
      throw Exception('User not authenticated!');
    }
    if (setList.id.isEmpty) {
      _log.warning('Attempted to update set list with empty ID.');
      throw Exception('SetList ID cannot be empty for update.');
    }
    final userId = user.uid;
    _log.info('Updating set list with ID ${setList.id}, order ${setList.order} for user $userId');

    Map<String, dynamic> dataToUpdate = setList.toFirestore();
    dataToUpdate['updatedAt'] = FieldValue.serverTimestamp(); // Always update 'updatedAt' on an update

    await _db
        .collection('users')
        .doc(userId)
        .collection('setLists')
        .doc(setList.id)
        .update(dataToUpdate); // toFirestore() now includes 'order'
    _log.info('updateSetList function completed successfully for ID ${setList.id}');
  }

  Future<void> deleteSetList(String setListId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Deleting set list with ID $setListId for user $userId');
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('setLists')
          .doc(setListId)
          .delete();
    } catch (e) {
      _log.severe('Error deleting set list in Firestore:', e);
      rethrow;
    }
  }

  Future<SetList> getSetList(String setListId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Getting set list with ID $setListId for user $userId');
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('setLists')
        .doc(setListId)
        .get();
    if (!doc.exists) {
      throw Exception('Set list not found');
    }
    return SetList.fromFirestore(doc);
  }

  Stream<List<Bit>> getBitsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      return Stream.empty();
    }
    final userId = user.uid;
    _log.info('Getting all bits for user $userId');
    return _db
        .collection('users')
        .doc(userId)
        .collection('bits')
        .orderBy('order', descending: false) // <-- ORDER BY NEW FIELD
        .snapshots()
        .map((snapshot) {
      _log.fine('Received ${snapshot.docs.length} bits from Firestore');
      return snapshot.docs.map((doc) => Bit.fromFirestore(doc)).toList();
    }).handleError((error) {
      _log.severe('Error getting bits stream from Firestore:', error);
      return [];
    });
  }

  Future<List<Recording>> getRecordings() async {
    if (_auth.currentUser == null) {
      _log.severe('User not authenticated!');
      return [];
    }
    final userId = _auth.currentUser!.uid;
    _log.info('Getting all recordings for user $userId');
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('recordings')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Recording.fromFirestore(doc)).toList();
  }

  Future<void> addRecording(Recording recording) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Adding recording with ID ${recording.id} for user $userId');
    await _db
        .collection('users')
        .doc(userId)
        .collection('recordings')
        .doc(recording.id)
        .set(recording.toFirestore()) // Use toFirestore()
        .then((_) {
      _log.info('addRecording function completed successfully');
    }).catchError((error) {
      _log.severe('Error adding recording to Firestore:', error);
      throw error;
    });
  }

  Future<void> deleteRecording(Recording recording) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Deleting recording with ID ${recording.id} for user $userId');
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('recordings')
          .doc(recording.id)
          .delete();
    } catch (e) {
      _log.severe('Error deleting recording in Firestore:', e);
    }
  }
}
