// lib/providers/set_list_provider.dart

import 'package:flutter/material.dart';
import '/models/set_list.dart';
import '/services/firestore_service.dart';


class SetListProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<SetList> _setLists = [];

  List<SetList> get setLists => _setLists;

  SetListProvider() {
    _firestoreService.getSetListsStream().listen((setLists) {
      _setLists = setLists;
      notifyListeners();
    });
  }

  Future<void> addSetList(SetList setList) async {
    await _firestoreService.addSetList(setList);
    notifyListeners();
  }

  Future<void> updateSetList(SetList setList) async {
    await _firestoreService.updateSetList(setList);
    final index = _setLists.indexWhere((s) => s.id == setList.id);
    if (index != -1) {
      _setLists[index] = setList;
      notifyListeners();
    }
  }

  Future<void> deleteSetList(String setListId) async {
    await _firestoreService.deleteSetList(setListId);
    _setLists.removeWhere((setList) => setList.id == setListId);
    notifyListeners();
  }

  void reorderSetLists(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final SetList setList = _setLists.removeAt(oldIndex);
    _setLists.insert(newIndex, setList);
    notifyListeners();
  }

  void reorderBitsInSetList(String setListId, int oldIndex, int newIndex) {
    final setList = _setLists.firstWhere((setList) => setList.id == setListId);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final String bitId = setList.bits.removeAt(oldIndex);
    setList.bits.insert(newIndex, bitId);
    updateSetList(setList);
  }

  void duplicateSetList(SetList setList, String newName, DateTime newDate) {
    final newSetList = SetList(
      id: DateTime.now().toString(),
      title: newName,
      date: newDate,
      bits: List<String>.from(setList.bits),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    addSetList(newSetList);
  }

  void renameSetList(String id, String newName) {
    final setList = _setLists.firstWhere((setList) => setList.id == id);
    setList.title = newName;
    updateSetList(setList);
  }
}