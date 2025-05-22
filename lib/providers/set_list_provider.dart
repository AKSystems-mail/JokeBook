// lib/providers/set_list_provider.dart

import 'package:flutter/material.dart';
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

  List<SetList> get setLists => _setLists;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SetListProvider() {
    _log.info("SetListProvider initializing...");
    _fetchSetLists();
  }

  void _fetchSetLists() {
    _isLoading = true;
    _error = null;
    _firestoreService.getSetListsStream().listen((fetchedSetLists) {
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

  Future<void> addSetList(String title, DateTime date, List<String> bitIds) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) {
      _log.warning("Cannot add setlist: User not authenticated.");
      return;
    }

    // Define newOrder before using it
    final newOrder = _setLists.length; // New setlists go to the end

    final newSetList = SetList(
      id: const Uuid().v4(), // Generate ID client-side
      title: title,
      date: date,
      bits: bitIds,
      createdAt: DateTime.now(), // Use DateTime.now()
      updatedAt: DateTime.now(), // Use DateTime.now()
      order: newOrder, // Use the defined newOrder
    );

    try {
      // Optimistic add (optional, if you uncomment, ensure SetList model is fully populated)
      // _setLists.add(newSetList);
      // notifyListeners();

      await _firestoreService.addSetList(newSetList); // Pass the newSetList directly
      _log.info("SetList added successfully to Firestore with order ${newSetList.order}");
    } catch (e) {
      _log.severe("Failed to add setlist: $e");
      // Revert optimistic add if implemented
      rethrow; // Use rethrow
    }
  }


  Future<void> updateSetList(SetList setList) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) return;

    // Ensure updatedAt is current, create a new instance if SetList is immutable or for clarity
    final SetList updatedSetList = setList.copyWith(
      updatedAt: DateTime.now(),
    );
    
    // Optimistic update (optional)
    // final index = _setLists.indexWhere((sl) => sl.id == updatedSetList.id);
    // if (index != -1) _setLists[index] = updatedSetList;
    // notifyListeners();

    try {
      await _firestoreService.updateSetList(updatedSetList);
    } catch (e) {
      _log.severe("Failed to update setlist ${updatedSetList.id}: $e");
      // Revert optimistic update
      rethrow; // Use rethrow
    }
  }

  Future<void> deleteSetList(String setListId) async {
    await _firestoreService.deleteSetList(setListId);
    // Stream will update. Optimistic:
    // _setLists.removeWhere((sl) => sl.id == setListId);
    // notifyListeners();
    // Deleting might require re-ordering subsequent items in Firestore. Consider this logic if needed.
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
        // Create a new instance with updated order and timestamp
        _setLists[i] = _setLists[i].copyWith(
          order: i,
          updatedAt: DateTime.now(),
        );
        setListsToUpdateInFirestore.add(_setLists[i]);
      }
    }
    notifyListeners(); // Update UI immediately

    if (setListsToUpdateInFirestore.isEmpty) {
      _log.info("No actual order change for setlists, skipping Firestore batch update.");
      return;
    }

    WriteBatch batch = _firestoreService.db.batch();
    for (final slToUpdate in setListsToUpdateInFirestore) {
      DocumentReference slRef = _firestoreService.db
          .collection('users')
          .doc(user.uid)
          .collection('setLists')
          .doc(slToUpdate.id);
      // Ensure DateTime is converted to Timestamp for Firestore batch
      batch.update(slRef, {'order': slToUpdate.order, 'updatedAt': Timestamp.fromDate(slToUpdate.updatedAt)});
    }

    try {
      await batch.commit();
      _log.info("Successfully persisted reordered setlists to Firestore.");
    } catch (e) {
      _log.severe("Failed to persist setlist order to Firestore: $e");
      _fetchSetLists(); // Re-fetch to ensure consistency
      rethrow; // Use rethrow
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