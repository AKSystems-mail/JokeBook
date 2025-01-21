import 'package:flutter/material.dart';
import '/models/set_list.dart';
import '/services/firestore_service.dart';
import 'package:logging/logging.dart';

class SetListProvider with ChangeNotifier {
  final _log = Logger('SetListProvider');
  final FirestoreService _firestoreService = FirestoreService();

  List<SetList> _setLists = []; // Initialize as an empty list
  bool _isLoading = false;
  List<SetList> get setLists => _setLists;
  bool get isLoading => _isLoading;
  set isLoading(bool value) {
    _isLoading = value;
  }

  SetListProvider() {
    _listenToSetLists();
  }

  void _listenToSetLists() {
    try {
      isLoading = true;
      _firestoreService.getSetListsStream().listen((setLists) {
        setLists.sort((a, b) => b.date.compareTo(a.date));
        _setLists = setLists.reversed.toList();
        isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _log.severe('Error fetching set lists: $e', e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> addSetList(SetList setList) async {
    await _firestoreService.addSetList(setList);
    // Add to the beginning of the list
    _setLists.insert(0, setList);
    notifyListeners();
  }

  Future<void> updateSetList(SetList setList) async {
    await _firestoreService.updateSetList(setList);
    // No need to manually re-fetch, the stream will update automatically
  }

  void reorderSetLists(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final SetList setList = _setLists.removeAt(oldIndex);
    _setLists.insert(newIndex, setList);
    notifyListeners();
  }

  Future<void> removeBitFromSetLists(String bitId) async {
    _log.info("removing bit: $bitId");
    for (var setList in _setLists) {
      if (setList.bits.contains(bitId)) {
        setList.bits.remove(bitId);
        await updateSetList(setList);
        _log.info("Removed bit $bitId from set list: ${setList.title}");
      }
    }
    _log.info("Completed bit removal");
  }

  Future<void> duplicateSetList(int index) async {
    final originalSetList = _setLists[index];
    final newSetList = SetList(
      id: DateTime.now().toString(),
      title: '${originalSetList.title} (Copy)',
      date: originalSetList.date,
      bits: List.from(originalSetList.bits),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await addSetList(newSetList);
  }

  Future<void> renameSetList(int index, String newTitle) async {
    _setLists[index].title = newTitle;
    await updateSetList(_setLists[index]);
    notifyListeners();
  }

  Future<void> deleteSetList(int index) async {
    await _firestoreService.deleteSetList(_setLists[index].id);
    _setLists.removeAt(index);
    notifyListeners();
  }
}