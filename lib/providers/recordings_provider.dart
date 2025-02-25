import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import '../models/recording.dart';
import '../services/firestore_service.dart';
import '../models/set_list.dart';

class RecordingsProvider with ChangeNotifier {
  final FlutterSoundRecorder _mRecorder = FlutterSoundRecorder();
  final _log = Logger('RecordingsProvider');
  bool _isRecording = false;
  String currentRecordingTitle = '';
  DateTime? startTime;
  Timer? _timer;
  Duration _currentDuration = Duration.zero;
  List<Recording> recordings = [];
  Recording? activeRecording;
  bool isDisposed = false;
  bool _isLoading = false;

  Duration get currentDuration => _currentDuration;
  bool get isLoading => _isLoading;

  String get formattedRecordingDuration {
    final minutes =
        _currentDuration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _currentDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> startRecording(String recordingTitle, String? setListId) async {
    if (isDisposed) {
      return; // Do nothing if the provider is disposed
    }
    if (await Permission.microphone.request().isGranted) {
      await initRecorder();
      String filePath = await getAudioFile(setListId);
      await _mRecorder.startRecorder(
          toFile: filePath, codec: Codec.aacADTS); // Specify codec
      _isRecording = true;
      activeRecording = Recording(
        id: DateTime.now().toString(),
        title: recordingTitle, // Use the new title here
        filePath: filePath,
        setListId: setListId ?? '',
        audioUrl: '',
        createdAt: Timestamp.fromDate(DateTime.now()),
      );
      startTime = DateTime.now();
      _startTimer();
      notifyListeners();
    }
  }

  Future<void> stopRecording(BuildContext context) async {
    if (_isRecording) {
      try {
        await _mRecorder.stopRecorder();
        _isRecording = false;
        _stopTimer();

        if (activeRecording != null) {
          // Upload the recording to Firebase Storage
          File recordingFile = File(activeRecording!.filePath);
          String userId = FirebaseAuth.instance.currentUser!.uid; // Correct way to get UID
          String storagePath = 'users/$userId/recordings/${activeRecording!.id}.aac';
          UploadTask uploadTask = FirebaseStorage.instance
              .ref()
              .child(storagePath)
              .putFile(recordingFile);

          // Listen for state changes, errors, and completion of the upload.
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            _log.info('Task state: ${snapshot.state}');
            _log.info('Progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100} %');
          }, onError: (e) {
            _log.severe('Error during upload: $e');
          });

          TaskSnapshot taskSnapshot = await uploadTask;
          String downloadUrl = await taskSnapshot.ref.getDownloadURL();

          // Update the recording with the download URL
          activeRecording = activeRecording!.copyWith(audioUrl: downloadUrl);

          // Save the recording details to Firestore
          await FirestoreService().addRecording(activeRecording!);

          // Add the recording to the local list
          recordings.add(activeRecording!);

          // Notify listeners after the upload is complete
          notifyListeners();
        }
      } catch (e) {
        _log.warning("Error stopping and saving recording: $e");
      }
    }
  }

  Future<String> getAudioFile(String? setListId) async {
    String newRecordingTitle;

    if (setListId != null) {
      try {
        SetList setList = await FirestoreService().getSetList(setListId);
        DateTime date = setList.createdAt; // Use the set list's creation date
        String formattedDate =
            "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}";
        newRecordingTitle = "${setList.title} - $formattedDate";
      } catch (e) {
        _log.warning("Error fetching set list: $e");
        newRecordingTitle = "No set list";
      }
    } else {
      newRecordingTitle = "No set list";
    }

    currentRecordingTitle = newRecordingTitle;

    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    String filePath = '$tempPath/${DateTime.now().millisecondsSinceEpoch}.aac';
    return filePath;
  }

  Future<void> initRecorder() async {
    await _mRecorder.openRecorder();
  }

  Future<void> fetchRecordings() async {
    try {
      List<Recording> recordingsList = await FirestoreService().getRecordings();
      recordings = recordingsList;
      notifyListeners();
    } catch (e) {
      _log.warning("Error fetching recordings: $e");
    }
  }

  void setActiveRecording(Recording recording) {
    activeRecording = recording;
    notifyListeners();
  }

  Future<void> deleteRecording(Recording recording) async {
    try {
      // Delete the recording from Firebase Storage
      await FirebaseStorage.instance.refFromURL(recording.audioUrl).delete();

      // Delete the recording details from Firestore
      await FirestoreService().deleteRecording(recording);

      // Remove the recording from the local list
      recordings.removeWhere((r) => r.id == recording.id);
      notifyListeners();
    } catch (e) {
      _log.warning("Error deleting recording: $e");
    }
  }

  bool isRecording() => _isRecording;

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentDuration = DateTime.now().difference(startTime!);
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }
}