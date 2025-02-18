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

class _RecordingsScreenState extends State<RecordingsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Recording? _selectedRecording;

  @override
  void initState() {
    super.initState();
    Provider.of<RecordingsProvider>(context, listen: false).fetchRecordings();
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
                icon: const Icon(Icons.play_arrow),
                onPressed: _selectedRecording != null
                    ? () async {
                        await _audioPlayer.play(UrlSource(_selectedRecording!.audioUrl));
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.pause),
                onPressed: _selectedRecording != null
                    ? () async {
                        await _audioPlayer.pause();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _selectedRecording != null
                    ? () async {
                        await _audioPlayer.stop();
                      }
                    : null,
              ),
            ],
          ),
          body: recordingsProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: recordingsProvider.recordings.length,
                  itemBuilder: (context, index) {
                    final recording = recordingsProvider.recordings[index];
                    final formattedDate = DateFormat('MM/dd/yyyy hh:mm').format(recording.createdAt.toDate());
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
    super.dispose();
  }
}