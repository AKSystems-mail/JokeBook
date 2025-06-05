// This provider has been refactored to use the 'record' package for audio recording,
// replacing the previous 'flutter_sound' implementation. Key functionalities like
// starting, stopping, and managing recording state have been adapted to the 'record' package's API.
// The core audio format (AAC) and quality settings have been preserved.
// Last refactored: 2024-10-28 for this change.
//
// lib/providers/recordings_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
<<<<<<< HEAD
import 'package:record/record.dart'; // Replaced flutter_sound
import 'package:permission_handler/permission_handler.dart';
=======
import 'package:record/record.dart'; // Import the 'record' package
import 'package:permission_handler/permission_handler.dart' as perm_handler; // Aliased
>>>>>>> 41fa4c9 (Stage 1 replacing flutter sound with record)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting in titles

import '../models/recording.dart' as app_recording; // Aliased to avoid conflict
import '../services/firestore_service.dart';
import '../models/set_list.dart';
import 'package:just_audio/just_audio.dart';
// import 'dart:io' as io; // No longer needed for specific alias
import 'package:flutter/foundation.dart' show kIsWeb;

class RecordingsProvider with ChangeNotifier {
<<<<<<< HEAD
  final AudioRecorder _audioRecorder = AudioRecorder(); // Replaced FlutterSoundRecorder
=======
  final AudioRecorder _audioRecorder = AudioRecorder(); // Using 'record' package
>>>>>>> 41fa4c9 (Stage 1 replacing flutter sound with record)
  final _log = Logger('RecordingsProvider');

  // Recording State
  bool _isRecording = false;
  String _currentRecordingTitleForDisplay = ''; // Title shown in UI during recording
  String? _currentFilePath; // Path of the file being recorded
  String? _currentSetListIdForRecording; // setListId for the current recording
  DateTime? _startTime;
  Timer? _timer;
  Duration _currentDuration = Duration.zero;
<<<<<<< HEAD
  List<Recording> recordings = [];
  Recording? activeRecording;
  bool isDisposed = false; // Flag to indicate if the provider is disposed.
  final bool _isLoading = false; // Flag to indicate if loading is in progress. Made final.
=======
>>>>>>> 41fa4c9 (Stage 1 replacing flutter sound with record)

  // Data State
  List<app_recording.Recording> recordings = [];
  bool _isLoading = false;

  // Playback State
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingPlayback = false;
  String? _currentlyPlayingId;
  Duration? _playerDuration;
  Duration? _playerPosition;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  bool isDisposed = false;

  // --- Getters ---
  bool get isRecording => _isRecording;
  Duration get currentDuration => _currentDuration;
  bool get isLoading => _isLoading;
  String get currentRecordingTitleForDisplay => _currentRecordingTitleForDisplay;

  String get formattedRecordingDuration {
    final minutes =
        _currentDuration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _currentDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Playback Getters
  bool get isPlayingPlayback => _isPlayingPlayback;
  String? get currentlyPlayingId => _currentlyPlayingId;

<<<<<<< HEAD
    // Ensure previous recording is stopped if any state inconsistency occurred
    if (await _audioRecorder.isRecording() || _isRecording) { // Updated to use _audioRecorder.isRecording()
       _log.warning("Recorder state indicates recording, attempting stop before starting new one.");
       await _audioRecorder.stop(); // Updated to use _audioRecorder.stop()
       _isRecording = false;
       _stopTimer(); // Ensure timer is stopped too
    }

    // Removed await initRecorder(); as it's not needed for 'record' package
    String filePath = await getAudioFile(setListId); // Ensure this generates .aac path

    try {
      _log.info("Starting recorder with enhanced quality settings...");
      // Updated to use _audioRecorder.start() with RecordConfig
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // Equivalent for aacADTS
          sampleRate: 48000,
          bitRate: 362000,
          numChannels: 2,
        ),
        path: filePath,
      );

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
    if (_isRecording) { // Check internal flag first
      try {
        final path = await _audioRecorder.stop(); // Updated to use _audioRecorder.stop()
        _isRecording = false;
        _stopTimer();

        if (activeRecording != null) {
          // If 'record' returns a path, we can use it. Otherwise, rely on activeRecording.filePath
          String finalPath = path ?? activeRecording!.filePath;
          _log.info('Recording stopped, file saved at: $finalPath');

          // Upload the recording to Firebase Storage
          File recordingFile = File(finalPath); // Use finalPath
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

          activeRecording = activeRecording!.copyWith(audioUrl: downloadUrl, filePath: finalPath); // Ensure filePath is updated if different

          await FirestoreService().addRecording(activeRecording!);
          recordings.add(activeRecording!);
          notifyListeners();
        }
      } catch (e) {
        _log.warning("Error stopping and saving recording: $e");
      }
=======
  String formatPlaybackDuration(Duration? duration) {
    if (duration == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
   Duration? get currentPlaybackPosition => _playerPosition;
   Duration? get totalPlaybackDuration => _playerDuration;


  RecordingsProvider() {
    _log.info("RecordingsProvider initialized");
    fetchRecordings();
  }

  Future<String> _generateRecordingTitle(String? setListId, String? customTitleHint) async {
    if (customTitleHint != null && customTitleHint.isNotEmpty) {
      return customTitleHint;
>>>>>>> 41fa4c9 (Stage 1 replacing flutter sound with record)
    }
    if (setListId != null && setListId.isNotEmpty) {
      try {
        SetList setList = await FirestoreService().getSetList(setListId);
        // Using Intl for consistent date formatting
        String formattedDate = DateFormat('MM/dd/yy').format(setList.date);
        return "${setList.title} - $formattedDate";
      } catch (e) {
        _log.warning("Error fetching set list for title generation (setListId: $setListId): $e");
        return "Recording - ${DateFormat('MM/dd/yy HH:mm').format(DateTime.now())}";
      }
    } else {
      return "General Recording - ${DateFormat('MM/dd/yy HH:mm').format(DateTime.now())}";
    }
  }

  Future<void> startRecording(String initialTitleHint, String? setListId) async {
    if (isDisposed) {
      _log.warning("Attempted to start recording on disposed provider.");
      return;
    }
    if (_isRecording) {
      _log.warning("Start recording called while already recording. Ignoring.");
      return;
    }

    if (!kIsWeb) {
      var status = await perm_handler.Permission.microphone.request();
      if (status != perm_handler.PermissionStatus.granted) {
        _log.severe("Microphone permission not granted.");
        throw RecordingPermissionException("Microphone permission not granted");
      }
    }

    if (_isPlayingPlayback) {
      await stopPlayback(); // Stop any active playback
    }

<<<<<<< HEAD
  // Removed initRecorder method as it's no longer needed.
=======
    if (await _audioRecorder.isRecording()) {
      _log.warning("AudioRecorder instance indicates it's already recording, attempting to stop it first.");
      await _audioRecorder.stop();
    }

    _currentSetListIdForRecording = setListId;
    _currentRecordingTitleForDisplay = await _generateRecordingTitle(setListId, initialTitleHint.isEmpty ? null : initialTitleHint);


    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
    _currentFilePath = '${directory.path}/$fileName';

    const recordConfig = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100, // Common, good quality
      bitRate: 128000,   // 128 kbps
      numChannels: 1,    // Mono
    );
>>>>>>> 41fa4c9 (Stage 1 replacing flutter sound with record)

    try {
      _log.info("Starting recorder to path: $_currentFilePath with config: ${recordConfig.encoder}, ${recordConfig.sampleRate}, ${recordConfig.bitRate}, ${recordConfig.numChannels}");
      await _audioRecorder.start(recordConfig, path: _currentFilePath!);

      _isRecording = true;
      _startTime = DateTime.now();
      _currentDuration = Duration.zero;
      _startTimer();
      notifyListeners();
      _log.info("Recording started successfully: $_currentRecordingTitleForDisplay");
    } catch (e, s) {
      _log.severe("Error starting recorder: $e", e, s);
      _isRecording = false;
      _currentFilePath = null;
      _currentRecordingTitleForDisplay = '';
      _currentSetListIdForRecording = null;
      _stopTimer();
      notifyListeners();
      throw Exception("Failed to start recording: ${e.toString()}");
    }
  }

  Future<void> stopRecording() async { // Removed BuildContext
    if (!_isRecording) {
      _log.info("Stop recording called but not currently recording.");
      return;
    }
    if (isDisposed) {
      _log.warning("Attempted to stop recording on disposed provider.");
      return;
    }

    try {
      final String? path = await _audioRecorder.stop();
      _isRecording = false; // Set immediately
      _stopTimer(); // Stop timer immediately
      final Duration recordedDuration = _currentDuration; // Capture before reset

      if (path != null) {
        _log.info("Recording stopped by plugin. File saved locally at: $path");
        _currentFilePath = path; // Ensure we use the path returned by the plugin

        File audioFile = File(_currentFilePath!);
        int fileSize = 0;
        if (await audioFile.exists()) {
          fileSize = await audioFile.length();
        } else {
          _log.severe("Recorded file does NOT exist at path after stopping: $_currentFilePath");
          // Reset and notify, then throw
          _resetRecordingState();
          throw Exception("Recorded file not found after stopping.");
        }

        _log.info("File size: $fileSize bytes, Duration: $recordedDuration");

        if (fileSize > 0 && recordedDuration > const Duration(milliseconds: 500)) {
          await _saveRecordingToFirebase(
            _currentFilePath!,
            _currentRecordingTitleForDisplay, // Use the title generated at start
            recordedDuration,
            fileSize,
            _currentSetListIdForRecording,
          );
        } else {
          _log.warning("Recording file is too short or empty. Not saving. Size: $fileSize, Duration: $recordedDuration");
          if (await audioFile.exists()) {
            await audioFile.delete();
            _log.info("Short/empty recording file deleted: $_currentFilePath");
          }
        }
      } else {
        _log.warning("Stopping recorder returned null path. Recording might not have been saved by the plugin.");
      }
    } catch (e, s) {
      _log.severe("Error stopping and processing recording: $e", e, s);
    } finally {
      _resetRecordingState(); // Ensure state is reset
    }
  }

  void _resetRecordingState() {
    _isRecording = false; // Ensure this is false if not already
    _currentDuration = Duration.zero;
    _currentFilePath = null;
    _currentRecordingTitleForDisplay = '';
    _currentSetListIdForRecording = null;
    _startTime = null;
    _stopTimer(); // Ensure timer is definitely stopped and nulled
    notifyListeners();
  }

  Future<void> _saveRecordingToFirebase(
    String localFilePath,
    String title,
    Duration duration,
    int fileSize,
    String? setListId,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log.warning("User not logged in, cannot save recording to Firebase.");
        _isLoading = false;
        notifyListeners();
        return;
      }

      File file = File(localFilePath);
      String fileNameOnly = localFilePath.split('/').last;
      String storagePath = 'users/${user.uid}/recordings/$fileNameOnly';
      Reference storageRef = FirebaseStorage.instance.ref().child(storagePath);

      _log.info("Uploading recording to Firebase Storage: ${storageRef.fullPath}");
      UploadTask uploadTask = storageRef.putFile(file);

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      _log.info("Upload complete. Download URL: $downloadUrl");

      // Create the Recording object to be saved in Firestore
      // FirestoreService().addRecording should handle the ID generation if it's designed to.
      // If not, generate ID here. For now, assuming FirestoreService handles it or uses the passed ID.
      String firestoreRecordingId = FirebaseFirestore.instance.collection('tmp').doc().id; // Temporary ID if service doesn't make one

      app_recording.Recording recordingToSave = app_recording.Recording(
        id: firestoreRecordingId, // This ID might be overridden by FirestoreService
        userId: user.uid,
        title: title,
        filePath: localFilePath, // Storing local path might be redundant if only URL is used later
        audioUrl: downloadUrl,
        duration: duration, // Store Duration object directly if model supports, else duration.inMilliseconds
        createdAt: Timestamp.now(),
        fileSize: fileSize,
        setListId: setListId,
      );

      await FirestoreService().addRecording(recordingToSave);
      _log.info("Recording metadata saved to Firestore for title: $title");

      await fetchRecordings(); // Refresh the list from Firestore
    } catch (e, s) {
      _log.severe("Error saving recording to Firebase: $e", e, s);
    } finally {
      _isLoading = false;
      notifyListeners();
      // Optionally delete local file after successful upload
      // File localFileToDelete = File(localFilePath);
      // if (await localFileToDelete.exists()) {
      //   await localFileToDelete.delete();
      //   _log.info("Local recording file deleted after upload: $localFilePath");
      // }
    }
  }

  Future<void> fetchRecordings() async {
    if (isDisposed) return;
    _isLoading = true;
    notifyListeners();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log.info("User not logged in for fetchRecordings. Clearing local recordings.");
        recordings = [];
        _isLoading = false;
        notifyListeners();
        return;
      }
      _log.info("Fetching recordings for user ${user.uid}");
      // Assuming FirestoreService().getRecordings() returns List<app_recording.Recording>
      final List<app_recording.Recording> fetched = await FirestoreService().getRecordings();
      if (!isDisposed) {
        recordings = fetched;
        // Duration should be stored in Firestore as int (milliseconds) and converted in model
        // No need to call _getRecordingDuration for each item here.
        recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _log.info("Fetched ${recordings.length} recordings.");
      }
    } catch (e, s) {
      _log.severe("Error fetching recordings: $e", e, s);
      if (!isDisposed) {
        recordings = [];
      }
    } finally {
      if (!isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> deleteRecording(app_recording.Recording recording) async {
    if (isDisposed) return;
    _isLoading = true;
    notifyListeners();
    try {
      _log.info("Attempting to delete recording: ${recording.id} (URL: ${recording.audioUrl})");

      if (recording.audioUrl.isNotEmpty) {
        try {
          Reference storageRef = FirebaseStorage.instance.refFromURL(recording.audioUrl);
          await storageRef.delete();
          _log.info("Recording file deleted from Firebase Storage: ${storageRef.fullPath}");
        } catch (storageError) {
          _log.warning(
              "Could not delete from Firebase Storage (may have already been deleted or path is invalid): ${recording.audioUrl}. Error: $storageError");
        }
      } else {
        _log.warning("Recording ${recording.id} has no audioUrl, cannot delete from Storage.");
      }

      await FirestoreService().deleteRecording(recording); // Pass the recording object
      _log.info("Recording metadata deleted from Firestore for ID: ${recording.id}");

      recordings.removeWhere((r) => r.id == recording.id);
      _log.info("Recording ${recording.id} removed from local list.");

      if (_currentlyPlayingId == recording.id) {
        await stopPlayback();
      }
    } catch (e, s) {
      _log.severe("Error deleting recording ${recording.id}: $e", e, s);
    } finally {
      if (!isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!_isRecording || _startTime == null) {
        timer.cancel();
        return;
      }
      _currentDuration = DateTime.now().difference(_startTime!);
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

<<<<<<< HEAD
  // Dispose method to clean up resources
  @override
  void dispose() {
    if (!isDisposed) {
      _log.info("Disposing RecordingsProvider");
      _audioRecorder.dispose();
      _timer?.cancel();
      isDisposed = true; // Set the flag
      super.dispose(); // Call super.dispose() if extending ChangeNotifier or similar
    }
  }
}

// Define the custom exception class
=======
  // --- Playback Methods ---
  Future<void> playOrPause(app_recording.Recording recording) async {
    if (isDisposed) return;
    if (_isPlayingPlayback && _currentlyPlayingId == recording.id) {
      await pausePlayback();
    } else {
      await playRecording(recording);
    }
  }

  Future<void> playRecording(app_recording.Recording recording) async {
    if (isDisposed) return;
    if (_isRecording) {
      _log.warning("Cannot play recording while another recording is in progress.");
      return;
    }
    if (_isPlayingPlayback) {
      await stopPlayback(); // Stop any current playback
    }

    _log.info("Preparing to play recording: ${recording.title} from ${recording.audioUrl}");
    _isLoading = true; // Indicate loading for playback
    _currentlyPlayingId = recording.id;
    notifyListeners();

    try {
      // Ensure URL is valid
      if (recording.audioUrl.isEmpty || !Uri.parse(recording.audioUrl).isAbsolute) {
          _log.severe("Invalid audio URL for playback: ${recording.audioUrl}");
          throw Exception("Invalid audio URL");
      }
      await _audioPlayer.setUrl(recording.audioUrl);

      _durationSubscription?.cancel();
      _durationSubscription = _audioPlayer.durationStream.listen((d) {
        if (!isDisposed) {
          _playerDuration = d;
          notifyListeners();
        }
      });

      _positionSubscription?.cancel();
      _positionSubscription = _audioPlayer.positionStream.listen((p) {
        if (!isDisposed) {
          _playerPosition = p;
          notifyListeners();
        }
      });

      _playerStateSubscription?.cancel();
      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        if (!isDisposed) {
          _isPlayingPlayback = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _log.info("Playback completed for ${recording.id}");
            // Resetting playback state more thoroughly
            _isPlayingPlayback = false;
            _playerPosition = Duration.zero; // Reset position to start
            // Keep _currentlyPlayingId to show it was the last played, or nullify:
            // _currentlyPlayingId = null;
            // _playerDuration = null;
          }
          notifyListeners();
        }
      });

      await _audioPlayer.play();
      _isPlayingPlayback = true;
      _log.info("Playback started for ${recording.id}");
    } catch (e, s) {
      _log.severe("Error playing recording ${recording.id} (URL: ${recording.audioUrl}): $e", e, s);
      _currentlyPlayingId = null;
      _isPlayingPlayback = false;
      _playerDuration = null;
      _playerPosition = null;
    } finally {
      if (!isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> pausePlayback() async {
    if (!_isPlayingPlayback || isDisposed) return;
    _log.info("Pausing playback for recording: $_currentlyPlayingId");
    await _audioPlayer.pause();
    _isPlayingPlayback = false; // State is updated by playerStateStream, but good to set
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    if (isDisposed && !_audioPlayer.playing && !_isPlayingPlayback) return;
    _log.info("Stopping playback for recording: $_currentlyPlayingId");

    await _durationSubscription?.cancel();
    _durationSubscription = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;

    await _audioPlayer.stop();

    _isPlayingPlayback = false;
    _currentlyPlayingId = null;
    _playerDuration = null;
    _playerPosition = null;
    if (!isDisposed) notifyListeners();
  }

  Future<void> seekPlayback(Duration position) async {
    if (_currentlyPlayingId == null || isDisposed) return;
    await _audioPlayer.seek(position);
    // UI will update via positionStream
  }

  @override
  void dispose() {
    _log.info("Disposing RecordingsProvider...");
    isDisposed = true;

    _audioRecorder.isRecording().then((isRec) {
      if (isRec) {
        _audioRecorder.stop().catchError((e) {
          _log.warning("Error stopping recorder during dispose: $e");
        });
      }
    }).whenComplete(() => _audioRecorder.dispose());

    _stopTimer();

    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();

    super.dispose();
    _log.info("RecordingsProvider disposed.");
  }
}

// Custom exception for recording permission issues
>>>>>>> 41fa4c9 (Stage 1 replacing flutter sound with record)
class RecordingPermissionException implements Exception {
  final String message;
  RecordingPermissionException(this.message);

  @override
  String toString() => 'RecordingPermissionException: $message';
}