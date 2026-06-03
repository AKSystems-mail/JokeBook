// lib/providers/set_list_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for User type
import 'package:cloud_firestore/cloud_firestore.dart'; // For WriteBatch and Timestamp
import '/models/set_list.dart';
import '/services/firestore_service.dart';
import 'package:uuid/uuid.dart'; // For generating IDs
import 'package:logging/logging.dart';

class SetListProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<SetList> _setLists = [];
  bool _isLoading = true;
  String? _error;
  static final Logger _log = Logger('SetListProvider');

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<SetList>>? _setListsSubscription;

  List<SetList> get setLists => _setLists;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SetListProvider() {
    _log.info("SetListProvider initializing...");
    _authSubscription = _firestoreService.auth.authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToSetLists();
      } else {
        _unsubscribeFromSetLists();
        _setLists = [];
        _isLoading = false;
        _error = null;
        notifyListeners();
      }
    });
  }

  void _subscribeToSetLists() {
    _setListsSubscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _setListsSubscription = _firestoreService.getSetListsStream().listen((fetchedSetLists) {
      _setLists = fetchedSetLists; // This list is now ordered by 'order' from Firestore
      _isLoading = false;
      _error = null;
      _log.info("SetLists fetched/updated: ${_setLists.length} items.");
      notifyListeners();
    }, onError: (e, stackTrace) {
      _log.severe("Error in SetListProvider stream listener: $e", e, stackTrace);
      _isLoading = false;
      _error = "Failed to load set lists.";
      _setLists = [];
      notifyListeners();
    });
  }

  void _unsubscribeFromSetLists() {
    _setListsSubscription?.cancel();
    _setListsSubscription = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _setListsSubscription?.cancel();
    super.dispose();
  }

  Future<void> addSetList(String title, DateTime date, List<String> bitIds) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) {
      _log.warning("Cannot add setlist: User not authenticated.");
      return;
    }

    // Define newOrder before using it
    // final newOrder = _setLists.length; // New setlists go to the end

    final newSetList = SetList(
      id: const Uuid().v4(), // Generate ID client-side
      title: title,
      date: date,
      bits: bitIds,
      createdAt: DateTime.now(), // Use DateTime.now()
      updatedAt: DateTime.now(), // Use DateTime.now()
      order: 0, // Use the defined newOrder
    );

    WriteBatch batch = _firestoreService.db.batch();
    final userSetListsRef = _firestoreService.db.collection('users').doc(user.uid).collection('setLists');

    // 1. Shift order of all existing setlists by +1
    for (final existingSetList in _setLists) {
      final docRef = userSetListsRef.doc(existingSetList.id);
      batch.update(docRef, {'order': (existingSetList.order ?? 0) + 1});
    }

    // 2. Add the new setlist with order 0
    final newDocRef = userSetListsRef.doc(newSetList.id);
    batch.set(newDocRef, newSetList.toFirestore());

    try {
      await batch.commit();
      _log.info("SetList added successfully with order 0. New ID: ${newSetList.id}");
      // The stream will automatically update the UI.
    } catch (e, s) {
      _log.severe("Failed to add setlist with shifted order: $e", e, s);
      throw Exception('Failed to save new setlist: $e');
    }
  }


  Future<void> updateSetList(SetList setList) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) return;

    // Ensure updatedAt is current, create a new instance if SetList is immutable or for clarity
    final SetList updatedSetList = setList.copyWith(
      updatedAt: DateTime.now(),
    );
    

    try {
      await _firestoreService.updateSetList(updatedSetList);
    } catch (e) {
      _log.severe("Failed to update setlist ${updatedSetList.id}: $e");
      // Revert optimistic update
      rethrow; // Use rethrow
    }
  }

  Future<void> deleteSetList(String setListId) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) {
      _log.warning("Cannot delete setlist: User not authenticated.");
      throw Exception('User not authenticated.');
    }

    final setListToRemove = _setLists.firstWhere((sl) => sl.id == setListId, orElse: () => throw Exception("Setlist not found locally for deletion"));
    final removedOrder = setListToRemove.order;

    if (removedOrder == null) {
      _log.warning("Setlist $setListId to be deleted has null order. Deleting without reordering others.");
      await _firestoreService.deleteSetList(setListId);
      return;
    }

    WriteBatch batch = _firestoreService.db.batch();
    final userSetListsRef = _firestoreService.db.collection('users').doc(user.uid).collection('setLists');

    // 1. Delete the setlist
    batch.delete(userSetListsRef.doc(setListId));

    // 2. Decrement order of subsequent setlists
    for (final sl in _setLists) {
      if (sl.id != setListId && sl.order != null && sl.order! > removedOrder) {
        batch.update(userSetListsRef.doc(sl.id), {'order': sl.order! - 1});
      }
    }

    try {
      await batch.commit();
      _log.info("SetList $setListId deleted and subsequent orders shifted.");
    } catch (e, s) {
      _log.severe("Failed to delete setlist $setListId and shift orders: $e", e, s);
      throw Exception('Failed to delete setlist: $e');
    }
  }

  Future<void> reorderSetLists(int oldIndex, int newIndexFromListView) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) {
      _log.warning("Cannot reorder setlists: User not authenticated.");
      return;
    }

    int newActualIndex = newIndexFromListView;
    if (newActualIndex > oldIndex) {
      newActualIndex -= 1;
    }

    if (oldIndex < 0 || oldIndex >= _setLists.length || newActualIndex < 0 || newActualIndex >= _setLists.length) {
      _log.warning("Invalid reorder indices for setlists: old=$oldIndex, new=$newActualIndex. List length: ${_setLists.length}");
      return;
    }

    final SetList item = _setLists.removeAt(oldIndex);
    _setLists.insert(newActualIndex, item);

    List<SetList> setListsToUpdateInFirestore = [];
    for (int i = 0; i < _setLists.length; i++) {
      if (_setLists[i].order != i) {
        _setLists[i] = _setLists[i].copyWith(
          order: i,
          updatedAt: DateTime.now(),
        );
        setListsToUpdateInFirestore.add(_setLists[i]);
      }
    }
    notifyListeners();

    if (setListsToUpdateInFirestore.isEmpty) {
      _log.info("No actual order change for setlists, skipping Firestore batch update.");
      return;
    }

    WriteBatch batch = _firestoreService.db.batch();
    for (final slToUpdate in setListsToUpdateInFirestore) {
      DocumentReference slRef = _firestoreService.db.collection('users').doc(user.uid).collection('setLists').doc(slToUpdate.id);
      batch.update(slRef, {'order': slToUpdate.order, 'updatedAt': Timestamp.fromDate(slToUpdate.updatedAt)});
    }

    try {
      await batch.commit();
      _log.info("Successfully persisted reordered setlists to Firestore.");
    } catch (e) {
      _log.severe("Failed to persist setlist order to Firestore: $e");
      _subscribeToSetLists();
      rethrow;
    }
  }

  Future<void> renameSetList(String setListId, String newTitle) async {
    final index = _setLists.indexWhere((sl) => sl.id == setListId);
    if (index != -1) {
      SetList updatedSetList = _setLists[index].copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      );
      _setLists[index] = updatedSetList; // Optimistic local update
      notifyListeners();
      await updateSetList(updatedSetList); // Persist (updateSetList handles its own updatedAt)
    }
  }

  Future<void> duplicateSetList(SetList originalSetList, String newTitle, DateTime newDate) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) return;

    // The addSetList method will handle setting createdAt, updatedAt, and order for the new duplicated list.
    // It will also generate a new ID.
    await addSetList(
        newTitle, 
        newDate, 
        List<String>.from(originalSetList.bits) // Ensure bits are copied
    );
  }
  
  Future<void> addBitToSetlist(String setlistId, String bitId) async {
    final setlistIndex = _setLists.indexWhere((s) => s.id == setlistId);
    if (setlistIndex != -1) {
      final setlist = _setLists[setlistIndex];
      if (!setlist.bits.contains(bitId)) {
        final newBitIds = List<String>.from(setlist.bits)..add(bitId);
        final updatedSetlist = setlist.copyWith(
          bits: newBitIds,
          updatedAt: DateTime.now(),
        );
        _setLists[setlistIndex] = updatedSetlist; // Optimistic update
        notifyListeners();
        await updateSetList(updatedSetlist); // updateSetList handles its own updatedAt
      }
    }
  }

  Future<void> removeBitFromSetlist(String setlistId, String bitId) async {
    final setlistIndex = _setLists.indexWhere((s) => s.id == setlistId);
    if (setlistIndex != -1) {
      final setlist = _setLists[setlistIndex];
      if (setlist.bits.contains(bitId)) {
        final newBitIds = List<String>.from(setlist.bits)..remove(bitId);
        final updatedSetlist = setlist.copyWith(
          bits: newBitIds,
          updatedAt: DateTime.now(),
        );
        _setLists[setlistIndex] = updatedSetlist; // Optimistic update
        notifyListeners();
        await updateSetList(updatedSetlist); // updateSetList handles its own updatedAt
      }
    }
  }
}