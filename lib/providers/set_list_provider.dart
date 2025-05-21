// lib/providers/set_list_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For WriteBatch and Timestamp
import '/models/set_list.dart';
import '/services/firestore_service.dart';
import 'package:uuid/uuid.dart'; // For generating IDs if needed
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

  // Simplified addSetList, assuming CreateSetListScreen prepares most of it
  Future<void> addSetList(String title, DateTime date, List<String> bitIds) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) {
      _log.warning("Cannot add setlist: User not authenticated.");
      return;
    }
    final newOrder = _setLists.length; // New setlists go to the end

    final newSetList = SetList(
      id: const Uuid().v4(), // Generate ID client-side for optimistic updates or use Firestore's auto-ID
      title: title,
      date: date,
      bits: bitIds,
      createdAt: Timestamp.now(), // Client-side timestamp for optimistic
      updatedAt: Timestamp.now(), // Client-side timestamp for optimistic
      order: newOrder,
    );

    try {
      // Optimistic add (optional)
      // _setLists.add(newSetList);
      // notifyListeners();
      
      final generatedId = await _firestoreService.addSetList(newSetList.copyWith(id: '')); // Let Firestore generate ID if preferred
      // If Firestore generates ID, you might need to update the local newSetList.id or re-fetch/rely on stream.
      // For simplicity, if Uuid is used, the ID is already set.
      _log.info("SetList added successfully to Firestore with order ${newSetList.order}");
    } catch (e) {
      _log.severe("Failed to add setlist: $e");
      // Revert optimistic add if implemented
      throw e;
    }
  }

  Future<void> updateSetList(SetList setList) async { // Used by rename, date change etc.
    final user = _firestoreService.auth.currentUser;
    if (user == null) return;

    setList.updatedAt = Timestamp.now(); // Ensure updatedAt is current
    
    // Optimistic update (optional)
    // final index = _setLists.indexWhere((sl) => sl.id == setList.id);
    // if (index != -1) _setLists[index] = setList;
    // notifyListeners();

    try {
      await _firestoreService.updateSetList(setList);
    } catch (e) {
      _log.severe("Failed to update setlist ${setList.id}: $e");
      // Revert optimistic update
      throw e;
    }
  }


  Future<void> deleteSetList(String setListId) async {
    await _firestoreService.deleteSetList(setListId);
    // Stream will update. Optimistic:
    // _setLists.removeWhere((sl) => sl.id == setListId);
    // notifyListeners();
    // Deleting might require re-ordering subsequent items in Firestore.
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
        _setLists[i].order = i;
        _setLists[i].updatedAt = Timestamp.now(); // Update timestamp on reorder
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
      batch.update(slRef, {'order': slToUpdate.order, 'updatedAt': slToUpdate.updatedAt});
    }

    try {
      await batch.commit();
      _log.info("Successfully persisted reordered setlists to Firestore.");
    } catch (e) {
      _log.severe("Failed to persist setlist order to Firestore: $e");
      _fetchSetLists(); // Re-fetch to ensure consistency
      throw e;
    }
  }

  // --- Other methods like renameSetList, duplicateSetList, addBitToSetlist, removeBitFromSetlist ---
  // Ensure these methods correctly update the SetList object and then call updateSetList.

  Future<void> renameSetList(String setListId, String newTitle) async {
    final index = _setLists.indexWhere((sl) => sl.id == setListId);
    if (index != -1) {
      // Create a new object or ensure the existing one is prepared for update
      SetList updatedSetList = _setLists[index].copyWith(
        title: newTitle,
        updatedAt: Timestamp.now(),
      );
      _setLists[index] = updatedSetList; // Optimistic local update
      notifyListeners();
      await updateSetList(updatedSetList); // Persist
    }
  }

  Future<void> duplicateSetList(SetList originalSetList, String newTitle, DateTime newDate) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) return;

    final newOrder = _setLists.length; // Duplicate goes to the end
    final duplicatedSetList = SetList(
      id: const Uuid().v4(), // New ID for the duplicate
      title: newTitle,
      date: newDate,
      bits: List<String>.from(originalSetList.bits), // Copy the bits
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      order: newOrder,
    );
    await addSetList(duplicatedSetList.title, duplicatedSetList.date, duplicatedSetList.bits); // Use the simplified addSetList
  }
  
  Future<void> addBitToSetlist(String setlistId, String bitId) async {
    final setlistIndex = _setLists.indexWhere((s) => s.id == setlistId);
    if (setlistIndex != -1) {
      final setlist = _setLists[setlistIndex];
      if (!setlist.bits.contains(bitId)) {
        // Create a new list for bits to ensure change detection if SetList is immutable
        final newBitIds = List<String>.from(setlist.bits)..add(bitId);
        final updatedSetlist = setlist.copyWith(
          bits: newBitIds,
          updatedAt: Timestamp.now(),
        );
        _setLists[setlistIndex] = updatedSetlist; // Optimistic update
        notifyListeners();
        await updateSetList(updatedSetlist);
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
          updatedAt: Timestamp.now(),
        );
        _setLists[setlistIndex] = updatedSetlist; // Optimistic update
        notifyListeners();
        await updateSetList(updatedSetlist);
      }
    }
  }
}