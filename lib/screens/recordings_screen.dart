import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../providers/recordings_provider.dart';
import '../providers/settings_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../models/recording.dart';
import 'package:intl/intl.dart';
import 'dart:io'
    as io; // Use alias to differentiate between dart:io and dart:html
import 'package:flutter/foundation.dart'
    show kIsWeb; // Import kIsWeb to check platform

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  RecordingsScreenState createState() => RecordingsScreenState();
}

class RecordingsScreenState extends State<RecordingsScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Recording? _selectedRecording;
  late AnimationController _animationController;
  Duration _elapsedTime = Duration.zero;
  bool _isSpeedActive = false;
  final GlobalKey _playbackSpeedKey = GlobalKey();

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
        if (!state.playing &&
                state.processingState == ProcessingState.completed ||
            state.processingState == ProcessingState.idle) {
          _resetPlaybackSpeed(); // Ensure speed resets when playback ends
          _animationController.reverse();
          // Optionally reset selection when playback completes naturally
          // setState(() {
          //   _selectedRecording = null;
          //   _elapsedTime = Duration.zero;
          // });
        } else if (state.playing) {
          _animationController.forward();
        } else if (state.processingState == ProcessingState.ready) {
          if (state.playing) {
            _animationController.forward();
          }
        } else {
          _animationController.reverse();
        }
      }
    });

    _audioPlayer.speedStream.listen((double speed) {
      if (mounted) {
        setState(() {
          _isSpeedActive = speed != 1.0;
        });
      }
    });

    // Trigger showcase for playback speed tooltip
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      // Only show if user has seen home showcase but not recordings showcase
      if (settings.hasSeenHomeShowcase && !settings.hasSeenRecordingsShowcase) {
        ShowCaseWidget.of(context).startShowCase([_playbackSpeedKey]);
        settings.completeRecordingsShowcase();
      }
    });
  }

  Future<void> _resetPlaybackSpeed() async {
    // Only reset if speed was potentially changed
    if (_audioPlayer.speed != 1.0) {
      try {
        // print("Resetting speed to 1.0"); // Debug removed
        await _audioPlayer.setSpeed(1.0);
      } catch (e) {
        // print("Error resetting speed: $e"); // Debug removed
      }
    }
    // Ensure flag is reset regardless of whether setSpeed was called
    if (_isSpeedActive && mounted) {
      setState(() {
        _isSpeedActive = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _togglePlayPause(Recording recording) async {
    // Store context before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // If different recording selected, stop current and start new one
      if (_selectedRecording != recording) {
        await _audioPlayer.stop(); // Stop first
        await _resetPlaybackSpeed(); // Reset speed when changing recording
        if (kIsWeb) {
          await _audioPlayer.setUrl(recording.audioUrl);
        } else {
          // Check file existence before setting path
          final fileExists = await io.File(recording.filePath).exists();
          if (fileExists) {
            await _audioPlayer.setFilePath(recording.filePath);
          } else {
            // Fallback to URL if local file doesn't exist
            await _audioPlayer.setUrl(recording.audioUrl);
          }
        }
        // Check if mounted before updating state after await
        if (!mounted) return;
        setState(() {
          _selectedRecording = recording; // Update selection
          _elapsedTime = Duration.zero; // Reset elapsed time for new recording
        });
        await _audioPlayer.play();
      } else {
        // Same recording, toggle play/pause
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        } else {
          // Ensure speed is normal when resuming normally
          await _resetPlaybackSpeed();
          await _audioPlayer.play();
        }
      }
    } catch (e) {
      // print("Error in _togglePlayPause: $e"); // Debug removed
      // Check if mounted before showing SnackBar
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text(
                'Error playing recording: ${e.toString()}')), // Use e.toString()
      );
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer.stop();
      await _resetPlaybackSpeed();
      if (mounted) {
        setState(() {
          _elapsedTime = Duration.zero;
          // Optionally clear selection on stop
          // _selectedRecording = null;
        });
      }
    } catch (e) {
      // Handle error silently or log
    }
  }

  Future<void> playRecording(Recording recording) async {
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

  Future<bool> _showDeleteConfirmationDialog(
      BuildContext context, String title) async {
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
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // CORRECTED: Define reader here for use in callbacks
    final recordingsProviderReader =
        Provider.of<RecordingsProvider>(context, listen: false);
    // Use watch here to rebuild when recordings list changes
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
                // CORRECTED: Use _togglePlayPause
                onPressed: _selectedRecording != null
                    ? () async {
                        await _togglePlayPause(_selectedRecording!);
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                // CORRECTED: Use _stopPlayback
                onPressed: _selectedRecording != null
                    ? _stopPlayback // Call the stop function
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
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: recordingsProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Showcase(
                  key: _playbackSpeedKey,
                  title: '1.5x Playback Speed',
                  description:
                      'Long press on a playing recording to speed up playback to 1.5x. Release to return to normal speed.',
                  tooltipBackgroundColor: Colors.blue,
                  textColor: Colors.white,
                  child: ListView.builder(
                    itemCount: recordingsProvider.recordings.length,
                    itemBuilder: (context, index) {
                      final recording = recordingsProvider.recordings[index];
                      final formattedDate = DateFormat('MM/dd/yyyy hh:mm a')
                          .format(recording.createdAt.toDate());
                      final formattedDuration =
                          _formatDuration(recording.duration);
                      // CORRECTED: Renamed variable for clarity and used it
                      final bool isCurrentlySelected =
                          _selectedRecording?.id == recording.id;

                      return Dismissible(
                        key: ValueKey(recording.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          // Store context before await
                          final currentContext = context;
                          return await _showDeleteConfirmationDialog(
                              currentContext, recording.title);
                        },
                        onDismissed: (direction) async {
                          // Store context and scaffoldMessenger before await
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          // final currentContext = context; // Not needed after await here

                          if (isCurrentlySelected) {
                            await _stopPlayback();
                            if (!mounted) return;
                            setState(() {
                              _selectedRecording = null;
                            });
                          }
                          //Use reader for provider action
                          await recordingsProviderReader
                              .deleteRecording(recording);
                          if (!mounted) return;
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                                content: Text('${recording.title} deleted')),
                          );
                        },
                        background: Container(
                          // This is the background revealed during swipe
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        // CORRECTED: GestureDetector wraps ListTile and is the CHILD of Dismissible
                        child: GestureDetector(
                          onTap: () async {
                            await _togglePlayPause(recording);
                            // Use reader for provider action
                            recordingsProviderReader
                                .setActiveRecording(recording);
                          },
                          onLongPressStart: (_) async {
                            // CORRECTED: Use isCurrentlySelected
                            if (isCurrentlySelected && _audioPlayer.playing) {
                              try {
                                await _audioPlayer.setSpeed(1.5);
                                if (mounted) {
                                  setState(() {
                                    _isSpeedActive = true;
                                  });
                                }
                              } catch (e) {
                                /* Handle error */
                              }
                            }
                          },
                          onLongPressEnd: (_) async {
                            // CORRECTED: Use isCurrentlySelected
                            if (isCurrentlySelected && _isSpeedActive) {
                              await _resetPlaybackSpeed();
                            }
                          },
                          child: ListTile(
                            // CORRECTED: Use isCurrentlySelected
                            tileColor: isCurrentlySelected
                                ? Colors.blue.shade100
                                : null,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(recording.title),
                                Text(formattedDuration,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        color:
                                            Color.fromARGB(255, 64, 80, 226))),
                              ],
                            ),
                            subtitle: Text(formattedDate),
                            // onTap is handled by GestureDetector
                          ),
                        ), // End GestureDetector
                      ); // End Dismissible
                    },
                  ),
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
