// lib/providers/recordings_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart'; // Using 'record' package
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import '../models/recording.dart';
import '../services/firestore_service.dart';
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

  StreamSubscription<User?>? _authSubscription;
  final Set<String> _downloadingIds = {};

  Duration get currentDuration => _currentDuration;
  bool get isLoading => _isLoading;

  String get formattedRecordingDuration {
    final minutes =
        _currentDuration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _currentDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  RecordingsProvider() {
    _log.info("RecordingsProvider initializing...");
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _loadCachedRecordings().then((_) {
          fetchRecordings();
        });
      } else {
        recordings = [];
        _isLoading = false;
        _downloadingIds.clear();
        notifyListeners();
      }
    });
  }

  Future<String> getLocalRecordingPath(String recordingId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${appDir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return '${recordingsDir.path}/$recordingId.aac';
  }

  Future<void> _loadCachedRecordings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_recordings_${user.uid}');
      if (cachedData != null) {
        final List<dynamic> decodedList = jsonDecode(cachedData);
        final cachedRecordings = await Future.wait(decodedList.map((item) async {
          final recording = Recording.fromJson(Map<String, dynamic>.from(item));
          final localPath = await getLocalRecordingPath(recording.id);
          return recording.copyWith(filePath: localPath);
        }));

        if (recordings.isEmpty && !isDisposed) {
          recordings = cachedRecordings;
          notifyListeners();
        }
      }
    } catch (e) {
      _log.warning("Error loading cached recordings: $e");
    }
  }

  Future<void> _saveRecordingsToCache(List<Recording> list) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final listJson = list.map((r) => r.toJson()).toList();
      await prefs.setString('cached_recordings_${user.uid}', jsonEncode(listJson));
    } catch (e) {
      _log.warning("Error saving recordings to cache: $e");
    }
  }

  Future<void> _preloadRecordings(List<Recording> list) async {
    // Only preload the most recent 15 recordings to keep network/bandwidth lightweight
    final itemsToPreload = list.take(15).toList();

    for (final recording in itemsToPreload) {
      if (isDisposed) return;
      if (recording.audioUrl.isEmpty) continue;

      final localPath = await getLocalRecordingPath(recording.id);
      final file = File(localPath);

      if (!await file.exists() && !_downloadingIds.contains(recording.id)) {
        _downloadingIds.add(recording.id);
        
        // Asynchronously download in the background without blocking the loop or UI
        _downloadAudioFile(recording.audioUrl, file, recording.id);
      }
    }
  }

  Future<void> _downloadAudioFile(String url, File file, String recordingId) async {
    try {
      _log.info("Preloading audio for recording $recordingId...");
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.writeToFile(file);
      _log.info("Successfully preloaded audio for recording $recordingId");
    } catch (e) {
      _log.warning("Failed to preload audio for recording $recordingId: $e");
      // Clean up incomplete file if any
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    } finally {
      _downloadingIds.remove(recordingId);
    }
  }

  // --- MODIFIED startRecording ---
  Future<void> startRecording(String recordingTitle, String? setListId) async {
    if (isDisposed) {
      _log.warning("Attempted to start recording on disposed provider.");
      return;
    }

    final String recordingId = DateTime.now().millisecondsSinceEpoch.toString();

    // 1. Optimistic UI update
    _isRecording = true;
    notifyListeners();

    try {
      _log.info("--- 1. startRecording called. ---");

      _log.info("--- 2. Requesting microphone permission... ---");
      if (!await _audioRecorder.hasPermission()) {
          _log.severe("--- 3. Microphone permission was not granted. Aborting. ---");
          _isRecording = false;
          notifyListeners();
          return;
      }
      _log.info("--- 3. Microphone permission is granted. ---");

      if (await _audioRecorder.isRecording()) {
         _log.warning("Recorder state indicates it's already recording. Stopping it first.");
         await _audioRecorder.stop();
      }

      String filePath = await getAudioFile(recordingTitle, setListId, recordingId);
      _log.info("--- 4. File path created: $filePath ---");

      _log.info("--- 5. Calling _audioRecorder.start... ---");
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 48000,
          bitRate: 384000,
          numChannels: 2,
        ),
        path: filePath,
      );
      _log.info("--- 6. _audioRecorder.start call finished. ---");

      startTime = DateTime.now();
      _currentDuration = Duration.zero; // Reset UI timer
      _startTimer();
      activeRecording = Recording(
        id: recordingId,
        title: currentRecordingTitle,
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

  // --- REVISED stopRecording with DETAILED LOGGING ---
  Future<void> stopRecording(BuildContext context) async {
    _log.info("--- A. stopRecording called. ---");

    if (_isRecording && startTime != null) {
      _log.info("--- B. _isRecording is true. Proceeding. ---");
      final elapsed = DateTime.now().difference(startTime!);

      if (elapsed.inMilliseconds < 1000) {
        _log.warning("--- C. EXIT: Recording too short (< 1s). Aborting. ---");
        return;
      }

      try {
        _log.info("--- D. Calling _audioRecorder.stop()... ---");
        final path = await _audioRecorder.stop();
        _log.info("--- E. _audioRecorder.stop() returned path: $path ---");
        
        _stopTimer();
        _isRecording = false; // Set state after all async operations are complete

        if (activeRecording != null && path != null) {
          _log.info("--- F. activeRecording and path are valid. Checking file... ---");
          
          File recordingFile = File(path);
          final fileLength = await recordingFile.length();
          _log.info("--- G. Recorded file length: $fileLength bytes. ---");

          if (fileLength < 1024) { // Check for a reasonably small size, not just 0
            _log.severe("--- H. EXIT: Recording file is empty or too small. Aborting upload. ---");
            activeRecording = null;
            notifyListeners();
            return;
          }

          _log.info("--- I. Starting Firebase upload... ---");
          String userId = FirebaseAuth.instance.currentUser!.uid;
          String storagePath = 'users/$userId/recordings/${activeRecording!.id}.aac';
          UploadTask uploadTask = FirebaseStorage.instance
              .ref()
              .child(storagePath)
              .putFile(recordingFile);

          TaskSnapshot taskSnapshot = await uploadTask;
          String downloadUrl = await taskSnapshot.ref.getDownloadURL();
          _log.info("--- J. Upload complete. Saving to Firestore. ---");

          activeRecording = activeRecording!.copyWith(
            audioUrl: downloadUrl,
            filePath: path,
            duration: elapsed, // Use accurate duration
          );

          await FirestoreService().addRecording(activeRecording!);
          recordings.add(activeRecording!);
          
          // Update cache
          _saveRecordingsToCache(recordings);
          
          _log.info("--- K. SUCCESS: Recording saved. Notifying listeners. ---");
          notifyListeners();

        } else {
          _log.severe("--- L. EXIT: Stop condition failed: activeRecording is null or path from stop() was null. ---");
          activeRecording = null;
          notifyListeners();
        }
      } catch (e) {
        _log.severe("--- X. EXIT: CATCH BLOCK ERROR in stopRecording: $e ---");
        _isRecording = false;
        activeRecording = null;
        _stopTimer();
        notifyListeners();
      }
    } else {
      _log.warning("--- M. EXIT: stopRecording called, but _isRecording was false or startTime was null. ---");
    }
  }

  Future<String> getAudioFile(String recordingTitle, String? setListId, String recordingId) async {
    String newRecordingTitle;

    if (setListId != null && recordingTitle.isNotEmpty) {
      DateTime date = DateTime.now();
      String formattedDate =
          "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}";
      newRecordingTitle = "$recordingTitle - $formattedDate";
    } else {
      newRecordingTitle = "No set list";
    }

    currentRecordingTitle = newRecordingTitle;

    return await getLocalRecordingPath(recordingId);
  }

  Future<void> fetchRecordings() async {
    try {
      if (recordings.isEmpty) {
        _isLoading = true;
        notifyListeners();
      }

      List<Recording> recordingsList = await FirestoreService().getRecordings();
      
      // Update in-memory file paths dynamically at runtime based on documents directory
      final cachedRecordings = await Future.wait(recordingsList.map((recording) async {
        final localPath = await getLocalRecordingPath(recording.id);
        return recording.copyWith(filePath: localPath);
      }));

      recordings = List.from(cachedRecordings);
      _isLoading = false;
      notifyListeners();

      // Save to cache asynchronously
      _saveRecordingsToCache(cachedRecordings);

      // Start preloading the most recent 15 recordings
      _preloadRecordings(cachedRecordings);

      // Resolve zero-duration (legacy) recordings in the background
      _resolveLegacyDurations(cachedRecordings);
    } catch (e) {
      _log.warning("Error fetching recordings: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _resolveLegacyDurations(List<Recording> initialList) async {
    bool updatedAny = false;
    for (var i = 0; i < initialList.length; i++) {
      final recording = initialList[i];
      if (recording.duration.inSeconds == 0) {
        try {
          final resolvedDuration = await _getRecordingDuration(recording);
          if (resolvedDuration.inSeconds > 0) {
            initialList[i] = recording.copyWith(duration: resolvedDuration);
            // Save the resolved duration back to Firestore to self-heal the record
            await FirestoreService().updateRecording(initialList[i]);
            updatedAny = true;
          }
        } catch (e) {
          _log.warning("Failed to auto-heal duration for recording ${recording.id}: $e");
        }
      }
    }

    // Only trigger a rebuild if we actually healed any zero durations
    if (updatedAny && !isDisposed) {
      recordings = List.from(initialList);
      // Update cache
      _saveRecordingsToCache(recordings);
      notifyListeners();
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
      final localPath = await getLocalRecordingPath(recording.id);
      final localFile = File(localPath);
      if (await localFile.exists()) {
        await localFile.delete();
        _log.info("Deleted local file for recording ${recording.id}");
      }
      await FirestoreService().deleteRecording(recording);
      recordings.removeWhere((r) => r.id == recording.id);
      // Update cache
      _saveRecordingsToCache(recordings);
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
      _authSubscription?.cancel();
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