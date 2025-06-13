import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadImagePage extends StatefulWidget {
  @override
  _UploadImagePageState createState() => _UploadImagePageState();
}

class _UploadImagePageState extends State<UploadImagePage> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  File? _imageFile;
  DateTime? selectedDateTime;
  bool isUploading = false;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> selectDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
    );

    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(DateTime.now()),
      );

      if (pickedTime != null) {
        final combined = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          selectedDateTime = combined;
        });
      }
    }
  }

  Future<void> uploadImage() async {
    if (_imageFile == null || titleController.text.isEmpty || selectedDateTime == null) return;

    setState(() => isUploading = true);

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child('images/$fileName');
    await ref.putFile(_imageFile!);
    final downloadUrl = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('images').add({
      'title': titleController.text,
      'description': descriptionController.text,
      'date': Timestamp.fromDate(selectedDateTime!),
      'imageUrl': downloadUrl,
      'userEmail': FirebaseAuth.instance.currentUser?.email,
    });

    setState(() => isUploading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final formattedDateTime = selectedDateTime != null
        ? '${selectedDateTime!.day}/${selectedDateTime!.month}/${selectedDateTime!.year} '
        '${selectedDateTime!.hour.toString().padLeft(2, '0')}:${selectedDateTime!.minute.toString().padLeft(2, '0')}'
        : 'Nenhuma data e hora selecionada';

    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Imagem')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Título')),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Descrição')),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: pickImage, child: const Text('Selecionar Imagem')),
              if (_imageFile != null) Image.file(_imageFile!, height: 150),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: selectDateTime, child: const Text('Selecionar Data e Hora')),
              const SizedBox(height: 8),
              Text(formattedDateTime, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: isUploading ? null : uploadImage,
                child: isUploading ? const CircularProgressIndicator() : const Text('Enviar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}