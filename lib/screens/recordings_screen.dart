import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recordings_provider.dart';
import '../providers/settings_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../models/recording.dart';
import 'package:intl/intl.dart';
import 'dart:io' as io; // Use alias to differentiate between dart:io and dart:html
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb to check platform

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  _RecordingsScreenState createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Recording? _selectedRecording;
  late AnimationController _animationController;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    Provider.of<RecordingsProvider>(context, listen: false).fetchRecordings();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _audioPlayer.positionStream.listen((Duration position) {
      if (mounted) {
        setState(() {
          _elapsedTime = position;
        });
      }
    });

    _audioPlayer.playerStateStream.listen((PlayerState state) {
      if (mounted) {
        if (state.playing) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      }
    });

    // Add listener to update UI when audioUrl is updated
    Provider.of<RecordingsProvider>(context, listen: false).addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _playRecording(Recording recording) async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        if (kIsWeb) {
          await _audioPlayer.setUrl(recording.audioUrl);
        } else {
          if (io.File(recording.filePath).existsSync()) {
            await _audioPlayer.setFilePath(recording.filePath);
          } else {
            await _audioPlayer.setUrl(recording.audioUrl);
          }
        }
        await _audioPlayer.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing recording: $e')),
      );
    }
  }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context, String title) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Recording'),
          content: Text('Are you sure you want to delete "$title"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final recordingsProvider = Provider.of<RecordingsProvider>(context);

    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: settingsProvider.backgroundColor,
            title: const Text('Recordings'),
            actions: [
              IconButton(
                icon: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: _animationController,
                ),
                onPressed: _selectedRecording != null
                    ? () async {
                        await _playRecording(_selectedRecording!);
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _selectedRecording != null
                    ? () async {
                        await _audioPlayer.stop();
                        if (mounted) {
                          setState(() {
                            _elapsedTime = Duration.zero;
                          });
                        }
                      }
                    : null,
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Text(
                    _formatDuration(_elapsedTime),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 20, // Increase the font size here
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: recordingsProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: recordingsProvider.recordings.length,
                  itemBuilder: (context, index) {
                    final recording = recordingsProvider.recordings[index];
                    final formattedDate = DateFormat('MM/dd/yyyy hh:mm a').format(recording.createdAt.toDate());
                    final formattedDuration = _formatDuration(recording.duration);
                    return Dismissible(
                      key: ValueKey(recording.id), // Ensure unique keys
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await _showDeleteConfirmationDialog(context, recording.title);
                      },
                      onDismissed: (direction) async {
                        await recordingsProvider.deleteRecording(recording);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${recording.title} deleted')),
                        );
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        tileColor: _selectedRecording == recording ? Colors.blue.shade100 : null,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(recording.title),
                            Text(formattedDuration, style: TextStyle(fontSize: 18, color: const Color.fromARGB(255, 64, 80, 226))),
                          ],
                        ),
                        subtitle: Text(formattedDate),
                        onTap: () async {
                          recordingsProvider.setActiveRecording(recording);
                          if (mounted) {
                            setState(() {
                              _selectedRecording = recording;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }
}