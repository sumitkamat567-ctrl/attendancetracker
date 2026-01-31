import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadTimetablePage extends StatefulWidget {
  const UploadTimetablePage({super.key});

  @override
  State<UploadTimetablePage> createState() => _UploadTimetablePageState();
}

class _UploadTimetablePageState extends State<UploadTimetablePage> {
  File? _image;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Timetable"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: _image == null
                  ? _emptyState()
                  : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_image!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            _uploadButton(),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.image, size: 90, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          "Upload your timetable image",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _uploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _pickImage,
        icon: const Icon(Icons.upload),
        label: const Text("Choose Image"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
