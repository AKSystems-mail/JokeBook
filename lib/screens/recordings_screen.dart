import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recordings_provider.dart';
import 'package:audioplayers/audioplayers.dart'; // Add this dependency

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  _RecordingsScreenState createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    Provider.of<RecordingsProvider>(context, listen: false).fetchRecordings();
  }

  @override
  Widget build(BuildContext context) {
    final recordingsProvider = Provider.of<RecordingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
      ),
      body: recordingsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: recordingsProvider.recordings.length,
              itemBuilder: (context, index) {
                final recording = recordingsProvider.recordings[index];
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
                    title: Text(recording.title),
                    subtitle: Text(recording.createdAt.toString()),
                    onTap: () async {
                    await _audioPlayer.play(UrlSource(recording.audioUrl)); // Play the recording
                    },
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}