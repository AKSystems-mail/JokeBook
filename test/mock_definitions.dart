import 'package:mockito/annotations.dart';
import 'package:YourAppName/services/firestore_service.dart'; // Corrected package name
import 'package:just_audio/just_audio.dart';

part 'mock_definitions.mocks.dart'; // Added part directive

@GenerateMocks([FirestoreService, AudioPlayer])
void main() {} // main function is often kept empty or used for other test setup