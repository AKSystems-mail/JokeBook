// lib/providers/recordings_provider.dart

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
import 'package:just_audio/just_audio.dart';
import 'dart:io' as io; // Use alias to differentiate between dart:io and dart:html
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb to check platform

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
  bool isDisposed = false; // Flag to indicate if the provider is disposed.
  bool _isLoading = false; // Flag to indicate if loading is in progress.

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
      _log.warning("Attempted to start recording on disposed provider.");
      return; // Do nothing if the provider is disposed
    }
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
       _log.severe("Microphone permission not granted.");
       // Optionally show a message to the user
       throw RecordingPermissionException("Microphone permission not granted");
    }

    // Ensure previous recording is stopped if any state inconsistency occurred
    if (_mRecorder.isRecording || _isRecording) {
       _log.warning("Recorder state indicates recording, attempting stop before starting new one.");
       await _mRecorder.stopRecorder();
       _isRecording = false;
       _stopTimer(); // Ensure timer is stopped too
    }


    await initRecorder(); // Ensure recorder is open
    String filePath = await getAudioFile(setListId); // Ensure this generates .aac path

    try {
      _log.info("Starting recorder with enhanced quality settings...");
      await _mRecorder.startRecorder(
          toFile: filePath,
          codec: Codec.aacADTS, // Keep AAC for compatibility
          // --- Quality Adjustments ---
          sampleRate: 44100,     // Use CD quality sample rate (adjust if needed, e.g., 48000)
          bitRate: 192000,      // Increase bitrate to 192 kbps (common good quality)
                                // You can try 128000 (128kbps) or 256000 (256kbps)
          numChannels: 1        // Set to 1 for mono (smaller files), use 2 for stereo if needed
          // -------------------------
      );

           // Specify codec
      _isRecording = true;
      activeRecording = Recording(
        id: DateTime.now().toString(),
        title: recordingTitle, // Use the new title here
        filePath: filePath,
        setListId: setListId ?? '',
        audioUrl: '',
        createdAt: Timestamp.fromDate(DateTime.now()),
        duration: Duration.zero, // Initialize duration
      );
      startTime = DateTime.now();
      _startTimer();
      notifyListeners();
    } catch (e) {
       _log.severe("Error starting recorder: $e");
       // Reset state if start failed
       _isRecording = false;
       activeRecording = null;
       startTime = null;
       _stopTimer();
       notifyListeners();
       // Rethrow or handle the error appropriately
       throw Exception("Failed to start recording: ${e.toString()}");
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
      for (var i = 0; i < recordingsList.length; i++) {
        final duration = await _getRecordingDuration(recordingsList[i]);
        recordingsList[i] = recordingsList[i].copyWith(duration: duration);
      }
      recordings = recordingsList;
      notifyListeners();
    } catch (e) {
      _log.warning("Error fetching recordings: $e");
    }
  }

  Future<Duration> _getRecordingDuration(Recording recording) async {
    final player = AudioPlayer();
    final completer = Completer<Duration>();

    player.durationStream.listen((duration) {
      if (duration != null && !completer.isCompleted) {
        completer.complete(duration);
      }
    });

    if (kIsWeb) {
      await player.setUrl(recording.audioUrl);
    } else {
      if (io.File(recording.filePath).existsSync()) {
        await player.setFilePath(recording.filePath);
      } else {
        await player.setUrl(recording.audioUrl);
      }
    }

    return completer.future;
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