import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Album Virtual',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const GalleryPage();
          } else {
            return const LoginPage();
          }
        },
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String errorMessage = '';

  Future<void> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message ?? 'Erro desconhecido');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: const Text('Entrar')),
            Text(errorMessage, style: const TextStyle(color: Colors.red)),
            TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                ),
                child: const Text('Não tem conta? Cadastre-se')
            )
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String errorMessage = '';

  Future<void> register() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message ?? 'Erro desconhecido');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: register, child: const Text('Cadastrar')),
            Text(errorMessage, style: const TextStyle(color: Colors.red))
          ],
        ),
      ),
    );
  }
}

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  String searchQuery = '';
  DateTime? startDate;
  DateTime? endDate;

  Stream<QuerySnapshot> getImagesStream() {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    Query query = FirebaseFirestore.instance
        .collection('images')
        .where('userEmail', isEqualTo: userEmail);

    if (searchQuery.isNotEmpty) {
      query = query
          .where('title', isGreaterThanOrEqualTo: searchQuery)
          .where('title', isLessThanOrEqualTo: '$searchQuery\uf8ff');
    }

    if (startDate != null && endDate != null) {
      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
    }

    return query.orderBy('date').snapshots();
  }


  Future<void> selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = DateTime.fromMillisecondsSinceEpoch(picked.end.millisecondsSinceEpoch + 86340000);
      });
    }
  }

  Future<void> deleteImage(String docId, String imageUrl) async {
    try {
      // Deleta do Storage
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();

      // Deleta do Firestore
      await FirebaseFirestore.instance.collection('images').doc(docId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao deletar imagem: $e')),
      );
    }
  }


  void logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galeria de Imagens'),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout, color: Colors.red,),
            tooltip: 'Sair',
          ),
          IconButton(onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UploadImagePage()),
          ), icon: const Icon(Icons.add), tooltip: 'Adicionar foto',)
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por título',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: selectDateRange,
                  child: const Text('Selecionar intervalo de datas'),
                ),
                const SizedBox(width: 10),
                if (startDate != null && endDate != null)
                  Text('${startDate!.day}/${startDate!.month}/${startDate!.year} - ${endDate!.day}/${endDate!.month}/${endDate!.year}', style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getImagesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhuma imagem encontrada.'));
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: Image.network(data['imageUrl'], width: 60, height: 60, fit: BoxFit.cover),
                        title: Text(data['title'] ?? ''),
                        subtitle: Text(data['description'] ?? ''),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text((data['date'] as Timestamp).toDate().toLocal().toString().split(' ')[0]),
                            Flexible(
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Excluir imagem',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirmar exclusão'),
                                      content: const Text('Tem certeza que deseja excluir esta imagem?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(context); // fecha o dialog
                                            await deleteImage(docs[index].id, data['imageUrl']);
                                          },
                                          child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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