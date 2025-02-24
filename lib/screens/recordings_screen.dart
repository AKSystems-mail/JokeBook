import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recordings_provider.dart';
import '../providers/settings_provider.dart';
import 'package:audioplayers/audioplayers.dart'; // Add this dependency
import '../models/recording.dart'; // Add this import statement
import 'package:intl/intl.dart'; // Add this import statement

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

    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        _elapsedTime = position;
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<Duration> _getRecordingDuration(String url) async {
    await _audioPlayer.setSourceUrl(url);
    final result = await _audioPlayer.getDuration();
    return Duration(milliseconds: result!.inMilliseconds);
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
                        if (_audioPlayer.state == PlayerState.playing) {
                          await _audioPlayer.pause();
                          _animationController.reverse();
                        } else {
                          await _audioPlayer.play(UrlSource(_selectedRecording!.audioUrl));
                          _animationController.forward();
                        }
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _selectedRecording != null
                    ? () async {
                        await _audioPlayer.stop();
                        _animationController.reverse();
                        setState(() {
                          _elapsedTime = Duration.zero;
                        });
                      }
                    : null,
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    _formatDuration(_elapsedTime),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
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
                      future: _getRecordingDuration(recording.audioUrl),
                      builder: (context, snapshot) {
                        final duration = snapshot.data ?? Duration.zero;
                        final formattedDuration = _formatDuration(duration);
                        return Dismissible(
                          key: Key(recording.id),
                          direction: DismissDirection.endToStart,
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
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(recording.title),
                                Text(formattedDuration, style: TextStyle(fontSize: 18, color: const Color.fromARGB(255, 64, 80, 226))),
                              ],
                            ),
                            subtitle: Text(formattedDate),
                            onTap: () {
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