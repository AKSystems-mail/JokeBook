// lib/providers/recordings_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:record/record.dart'; // Using 'record' package
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import '../models/recording.dart';
import '../services/firestore_service.dart';
import '../models/set_list.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

class RecordingsProvider with ChangeNotifier {
  final AudioRecorder _audioRecorder = AudioRecorder();
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

  // --- MODIFIED startRecording ---
  Future<void> startRecording(String recordingTitle, String? setListId) async {
    if (isDisposed) {
      _log.warning("Attempted to start recording on disposed provider.");
      return;
    }

    try {
      _log.info("--- 1. startRecording called. ---");

      _log.info("--- 2. Requesting microphone permission... ---");
      if (!await _audioRecorder.hasPermission()) {
          _log.severe("--- 3. Microphone permission was not granted. Aborting. ---");
          return;
      }
      _log.info("--- 3. Microphone permission is granted. ---");

      if (await _audioRecorder.isRecording()) {
         _log.warning("Recorder state indicates it's already recording. Stopping it first.");
         await _audioRecorder.stop();
      }
      _isRecording = false;
      _stopTimer();

      String filePath = await getAudioFile(setListId);
      _log.info("--- 4. File path created: $filePath ---");

      _log.info("--- 5. Calling _audioRecorder.start... ---");
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 48000,
          bitRate: 362000,
          numChannels: 2,
        ),
        path: filePath,
      );
      _log.info("--- 6. _audioRecorder.start call finished. ---");

      // Update state AFTER start is confirmed
      _isRecording = true;
      startTime = DateTime.now();
      _currentDuration = Duration.zero; // Reset UI timer
      _startTimer();
      activeRecording = Recording(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: recordingTitle,
        filePath: filePath,
        setListId: setListId ?? '',
        audioUrl: '',
        createdAt: Timestamp.now(),
        duration: Duration.zero,
      );
      notifyListeners();
      _log.info("--- 7. State updated, recording is now active. ---");

    } catch (e) {
      _log.severe("--- X. CATCH BLOCK ERROR in startRecording: $e ---");
      _isRecording = false;
      activeRecording = null;
      startTime = null;
      _stopTimer();
      notifyListeners();
    }
  }

  // --- MODIFIED stopRecording ---
  Future<void> stopRecording(BuildContext context) async {
    // Check internal flag and if a recording was actually started
    if (_isRecording && startTime != null) {
      // Calculate the actual time elapsed since recording started
      final elapsed = DateTime.now().difference(startTime!);

      // Prevent stopping if recording is too short (e.g., less than 1 second)
      if (elapsed.inMilliseconds < 1000) {
        _log.warning("Recording too short (< 1s). Ignoring stop command.");
        // Optionally provide feedback to the user via a SnackBar or other means
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Recording too short")));
        return;
      }

      try {
        final path = await _audioRecorder.stop();
        _stopTimer(); // Stop the UI timer

        // Use the accurately calculated elapsed time as the final duration
        final finalDuration = elapsed;
        _isRecording = false; // Set state after all async operations are complete

        if (activeRecording != null && path != null) {
          _log.info('Recording stopped, file saved at: $path');

          File recordingFile = File(path);
          // Check if the created file has content before uploading
          if (await recordingFile.length() == 0) {
            _log.severe("Recording file is empty. Aborting upload.");
            activeRecording = null; // Clear the active recording
            notifyListeners();
            return;
          }

          // Proceed with upload logic
          String userId = FirebaseAuth.instance.currentUser!.uid;
          String storagePath = 'users/$userId/recordings/${activeRecording!.id}.aac';
          UploadTask uploadTask = FirebaseStorage.instance
              .ref()
              .child(storagePath)
              .putFile(recordingFile);

          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            _log.info('Task state: ${snapshot.state}');
            _log.info('Progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100} %');
          }, onError: (e) {
            _log.severe('Error during upload: $e');
          });

          TaskSnapshot taskSnapshot = await uploadTask;
          String downloadUrl = await taskSnapshot.ref.getDownloadURL();

          // Update the active recording with the final, accurate data
          activeRecording = activeRecording!.copyWith(
            audioUrl: downloadUrl,
            filePath: path,
            duration: finalDuration, // <<< USE ACCURATE DURATION
          );

          await FirestoreService().addRecording(activeRecording!);
          recordings.add(activeRecording!);
          
          // Final state update to refresh UI
          notifyListeners();
        } else {
          // If stop fails or something is null, reset state
          _log.warning("Stop recording called, but activeRecording or path was null.");
          activeRecording = null;
          notifyListeners();
        }
      } catch (e) {
        _log.warning("Error stopping and saving recording: $e");
        // Reset state on error
        _isRecording = false;
        activeRecording = null;
        _stopTimer();
        notifyListeners();
      }
    }
  }

  Future<String> getAudioFile(String? setListId) async {
    String newRecordingTitle;

    if (setListId != null) {
      try {
        SetList setList = await FirestoreService().getSetList(setListId);
        DateTime date = setList.createdAt;
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
    // If duration is already valid from Firestore, use it.
    if (recording.duration.inSeconds > 0) {
      return recording.duration;
    }
    
    // Fallback to fetching it if duration is zero (for older recordings)
    final player = AudioPlayer();
    final completer = Completer<Duration>();

    player.durationStream.listen((duration) {
      if (duration != null && !completer.isCompleted) {
        completer.complete(duration);
      }
    });

    try {
      if (kIsWeb) {
        await player.setUrl(recording.audioUrl);
      } else {
        final file = io.File(recording.filePath);
        if (await file.exists() && await file.length() > 0) {
          await player.setFilePath(recording.filePath);
        } else if (recording.audioUrl.isNotEmpty) {
          await player.setUrl(recording.audioUrl);
        } else {
          if (!completer.isCompleted) completer.complete(Duration.zero);
        }
      }
    } catch (e) {
      _log.warning("Error getting duration for recording ${recording.id}: $e");
      if (!completer.isCompleted) completer.complete(Duration.zero);
    }

    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      _log.warning("Timeout getting duration for recording ${recording.id}");
      return Duration.zero;
    }).whenComplete(() => player.dispose());
  }

  void setActiveRecording(Recording recording) {
    activeRecording = recording;
    notifyListeners();
  }

  Future<void> deleteRecording(Recording recording) async {
    try {
      if (recording.audioUrl.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(recording.audioUrl).delete();
      }
      await FirestoreService().deleteRecording(recording);
      recordings.removeWhere((r) => r.id == recording.id);
      notifyListeners();
    } catch (e) {
      _log.warning("Error deleting recording: $e");
    }
  }

  bool isRecording() => _isRecording;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (startTime != null) {
        _currentDuration = DateTime.now().difference(startTime!);
        notifyListeners();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    if (!isDisposed) {
      _log.info("Disposing RecordingsProvider");
      _audioRecorder.dispose();
      _timer?.cancel();
      isDisposed = true;
      super.dispose();
    }
  }
}

// Define the custom exception class
class RecordingPermissionException implements Exception {
  final String message;
  RecordingPermissionException(this.message);

  @override
  String toString() => 'RecordingPermissionException: $message';
}