import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TimetableOCRService {
  /// Extracts text from a provided image file using Google ML Kit.
  static Future<String> extractText(File imageFile) async {
    // 1. Create an InputImage object from the file
    final inputImage = InputImage.fromFile(imageFile);

    // 2. Initialize the TextRecognizer (defaulting to Latin script)
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      // 3. Process the image and retrieve recognized text
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      return recognizedText.text;
    } catch (e) {
      // Handle potential errors during processing
      return "Error recognizing text: $e";
    } finally {
      // 4. Always close the recognizer to free up resources
      await textRecognizer.close();
    }
  }
}