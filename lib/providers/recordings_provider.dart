import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recording.dart';
import '../services/firestore_service.dart';
import '../models/set_list.dart'; // Import SetList
import 'package:logging/logging.dart';

class RecordingsProvider with ChangeNotifier {
  final FlutterSoundRecorder _mRecorder = FlutterSoundRecorder();
  final _log = Logger('RecordingsProvider');
  final FlutterSoundPlayer _mPlayer = FlutterSoundPlayer();
  bool _isRecording = false;
  final bool _isPlaying = false;
  String currentRecordingTitle = '';
  DateTime? startTime;
  String? currentSetListId;
  Timer? _timer;
  Duration _currentDuration = Duration.zero;
  List<Recording> recordings = [];
  Recording? activeRecording;
  bool isDisposed = false;
  final bool _isLoading = false;

  Duration get currentDuration => _currentDuration;
  FlutterSoundPlayer get player => _mPlayer;
  bool get isLoading => _isLoading;

  String get formattedRecordingDuration {
    final minutes = _currentDuration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _currentDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
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
        createdAt: DateTime.now(),
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
      } finally {
        _isRecording = false;
        _stopTimer();
        _handleRecordingStopped(context);
      }
      notifyListeners();
    }
  }

  bool isRecording() => _isRecording;
  bool isPlaying() => _isPlaying;

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

  Future<void> togglePlayPause() async {
    if (activeRecording != null) {
      if (_isPlaying) {
        _stopSubscription();
      } else {
        _startSubscription();
      }
    }
  }

  Future<void> startPlayer() async {
    if (activeRecording != null && activeRecording!.audioUrl.isNotEmpty) {
      await _mPlayer.startPlayer(fromURI: activeRecording!.audioUrl);
    } else {
      _log.warning("No audio URL available to play.");
    }
  }

  void _handleRecordingStopped(BuildContext context) {
    if (activeRecording != null) {
      showRecordingConfirmationDialog(context, activeRecording!.title);
    }
  }

  Future<void> showRecordingConfirmationDialog(BuildContext context, String recordingTitle) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Recording?'),
          content: Text('Would you like to save this recording as:\n"$recordingTitle"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Call the saveRecording method
                addRecording(recordingTitle);
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  void addRecording(String recordingTitle) {
    // Add logic to save the recording
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentDuration = DateTime.now().difference(startTime!);
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _startSubscription() {
    // Add logic to start subscription
  }

  void _stopSubscription() {
    // Add logic to stop subscription
  }

  Future<void> initRecorder() async {
    await _mRecorder.openRecorder();
  }

  Future<void> fetchRecordings() async {
    // Add logic to fetch recordings
  }

  void setActiveRecording(Recording recording) {
    activeRecording = recording;
    notifyListeners();
  }

  Future<void> deleteRecording(Recording recording) async {
    // Add logic to delete recording
  }
}