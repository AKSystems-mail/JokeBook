import 'package:flutter_test/flutter_test.dart';
import 'package:YourAppName/screens/recordings_screen.dart';
import 'package:YourAppName/providers/recordings_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:YourAppName/services/firestore_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:YourAppName/models/recording.dart'; // Added for Recording model
import 'mock_definitions.mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

void main() {
  late MockFirestoreService mockFirestoreService;
  // MockAudioPlayer might not be directly used by RecordingsProvider anymore
  late MockAudioPlayer mockAudioPlayer;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    mockAudioPlayer = MockAudioPlayer();
  });

  testWidgets('RecordingsScreen displays recordings', (WidgetTester tester) async {
    // RecordingsProvider constructor is now parameterless.
    // This test will now use the real FirestoreService and AudioRecorder.
    final recordingsProvider = RecordingsProvider();

    final recording = Recording( // Recording model is now imported
      id: '1',
      title: 'Test Recording',
      filePath: 'path/to/file',
      setListId: 'setListId',
      audioUrl: 'url/to/audio',
      createdAt: Timestamp.now(),
      duration: Duration(seconds: 120),
    );

    // This when() will not work as expected without injecting the mockFirestoreService.
    when(mockFirestoreService.getRecordings()).thenAnswer((_) async => [recording]);
    when(mockAudioPlayer.setUrl(any)).thenAnswer((_) async => Duration(seconds: 120));
    when(mockAudioPlayer.duration).thenReturn(Duration(seconds: 120));

    await tester.pumpWidget(
      ChangeNotifierProvider<RecordingsProvider>.value(
        value: recordingsProvider,
        child: MaterialApp(
          home: RecordingsScreen(),
        ),
      ),
    );

    // Trigger fetchRecordings()
    await recordingsProvider.fetchRecordings();
    await tester.pumpAndSettle();

    expect(find.text('Recordings'), findsOneWidget);
    expect(find.text('Test Recording'), findsOneWidget);
    expect(find.text('02:00'), findsOneWidget);
  });
}