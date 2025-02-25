import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recordings_provider.dart';
import '../providers/settings_provider.dart';
import 'package:just_audio/just_audio.dart'; // Add this dependency
import '../models/recording.dart'; // Add this import statement
import 'package:intl/intl.dart'; // Add this import statement
import 'dart:io'; // Add this import statement

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
      setState(() {
        _elapsedTime = position;
      });
    });

    _audioPlayer.playerStateStream.listen((PlayerState state) {
      if (state.playing) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });

    // Add listener to update UI when audioUrl is updated
    Provider.of<RecordingsProvider>(context, listen: false).addListener(() {
      setState(() {});
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<Duration> _getRecordingDuration(Recording recording) async {
    final player = AudioPlayer();
    if (File(recording.filePath).existsSync()) {
      await player.setFilePath(recording.filePath);
    } else {
      await player.setUrl(recording.audioUrl);
    }
    return player.duration ?? Duration.zero;
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
                        if (_audioPlayer.playing) {
                          await _audioPlayer.pause();
                        } else {
                          if (File(_selectedRecording!.filePath).existsSync()) {
                            await _audioPlayer.setFilePath(_selectedRecording!.filePath);
                          } else {
                            await _audioPlayer.setUrl(_selectedRecording!.audioUrl);
                          }
                          await _audioPlayer.play();
                        }
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _selectedRecording != null
                    ? () async {
                        await _audioPlayer.stop();
                        setState(() {
                          _elapsedTime = Duration.zero;
                        });
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
                    return FutureBuilder<Duration>(
                      future: _getRecordingDuration(recording),
                      builder: (context, snapshot) {
                        final duration = snapshot.data ?? Duration.zero;
                        final formattedDuration = _formatDuration(duration);
                        return Dismissible(
                          key: Key(recording.id),
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
                              recordingsProvider.setActiveRecording(recording); // Call without using the return value
                              setState(() {
                                _selectedRecording = recording;
                              });
                            },
                          ),
                        );
                      },
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