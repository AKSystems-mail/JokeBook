import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/models/bit.dart';
import '/models/set_list.dart';
import 'package:logging/logging.dart';
import '/models/recording.dart';

class FirestoreService {
  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Authentication instance
  final FirebaseFirestore _db = FirebaseFirestore.instance; // Firestore instance
  static final Logger _log = Logger('FirestoreService'); // Logger for this service

  // Create a new user with email and password
  Future<void> createUserWithEmailAndPassword(String email, String password) async {
    try {
      _log.info('Creating user with email: $email');
      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Get user ID
      final userId = userCredential.user!.uid;
      // Create a new document in the 'users' collection with the user's ID
      await _db.collection('users').doc(userId).set({
        'createdAt': FieldValue.serverTimestamp(),
      });
      _log.info('User created successfully with ID: $userId');
    } on FirebaseAuthException catch (e) {
      _log.severe('Failed to create user: $e');
      rethrow; // Re-throw the error to be handled by the caller
    } catch (e) {
      _log.severe('An unexpected error occurred during user creation: $e');
      rethrow; // Re-throw the error
    }
  }

  // Add a new Bit
  Future<void> addBit(Bit bit) {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Adding bit with ID ${bit.id} for user $userId');
    return _db.collection('users').doc(userId).collection('bits').doc(bit.id).set(bit.toMap())
        .then((_) {
          _log.info('addBit function completed successfully');
        });
  }

  // Update a Bit
  Future<void> updateBit(Bit bit) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _log.severe('User not authenticated!');
        throw Exception('User not authenticated!');
      }
      final userId = user.uid;
      _log.info('Updating bit with ID ${bit.id} for user $userId');
      await _db.collection('users').doc(userId).collection('bits').doc(bit.id)
          .update(bit.toMap());
    } catch (e) {
      _log.severe('Error updating bit in Firestore:', e); // Log the error with level severe
      rethrow; // Re-throw the error to be handled by the caller
    }
  }

  // Delete a Bit
  Future<void> deleteBit(String id) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Deleting bit with ID $id for user $userId');
    try {
      await _db.collection('users').doc(userId).collection('bits').doc(id)
          .delete();
    } catch (e) {
      _log.severe('Error deleting bit in Firestore:', e);
    }
  }

  // Get a Bit by ID
  Future<Bit> getBit(String id) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Getting bit with ID $id for user $userId');
    DocumentSnapshot doc = await _db
        .collection('users')
        .doc(userId)
        .collection('bits')
        .doc(id)
        .get();
    return Bit.fromFirestore(doc);
  }

  // Get all Bits for the current user
  Stream<List<Bit>> getBits() {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Getting all bits for user $userId');
    return _db.collection('users').doc(userId).collection('bits')
        .snapshots().map((snapshot) {
          _log.fine('Received ${snapshot.docs.length} bits from Firestore');
          return snapshot.docs.map((doc) => Bit.fromFirestore(doc)).toList();
        }
    );
  }

  // Add a new SetList
  Future<void> addSetList(SetList setList) {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Adding set list with ID ${setList.id} for user $userId');
    return _db.collection('users').doc(userId).collection('setLists')
        .doc(setList.id).set(setList.toMap());
  }

  // Get a SetList by ID
  Future<SetList> getSetList(String id) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Getting set list with ID $id for user $userId');
    DocumentSnapshot doc = await _db.collection('users').doc(userId)
        .collection('setLists').doc(id).get();
    return SetList.fromFirestore(doc);
  }

  // Update a SetList
  Future<void> updateSetList(SetList setList) {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Updating set list with ID ${setList.id} for user $userId');
    return _db.collection('users').doc(userId).collection('setLists')
        .doc(setList.id).update(setList.toMap());
  }

  // Delete a SetList
  Future<void> deleteSetList(String id) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Deleting set list with ID $id for user $userId');
    try {
      await _db.collection('users').doc(userId).collection('setLists').doc(id)
          .delete();
    } catch (e) {
      _log.severe('Error deleting set list in Firestore:', e);
    }
  }

  // Get all SetLists for the current user as a stream
  Stream<List<SetList>> getSetListsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Getting all set lists stream for user $userId');
    return _db.collection('users').doc(userId).collection('setLists').orderBy('createdAt', descending: true)
        .snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SetList.fromFirestore(doc)).toList();
    });
  }

  // Get all Recordings for the current user
  Future<List<Recording>> getRecordings() async {
    if (_auth.currentUser == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = _auth.currentUser!.uid;
    _log.info('Getting all recordings for user $userId');
    final snapshot = await _db.collection('users').doc(userId).collection('recordings').orderBy('createdAt', descending: true).get(); 
    
    return snapshot.docs.map((doc) => Recording.fromFirestore(doc)).toList();
  }

  // Add a new Recording
  Future<void> addRecording(Recording recording) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Adding recording with ID ${recording.id} for user $userId');
    await _db.collection('users').doc(userId).collection('recordings').doc(recording.id).set(recording.toMap());
  }

  // Delete a Recording
  Future<void> deleteRecording(Recording recording) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Deleting recording with ID ${recording.id} for user $userId');
    try {
      await _db.collection('users').doc(userId).collection('recordings').doc(recording.id).delete();
    } catch (e) {
      _log.severe('Error deleting recording in Firestore:', e);
    }
  }
}