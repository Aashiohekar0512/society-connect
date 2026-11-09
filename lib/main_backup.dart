import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SocietyConnectApp());
}

class SocietyConnectApp extends StatelessWidget {
  const SocietyConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Society Connect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B5B),
        ),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Email आणि Password भरा.');
      return;
    }

    if (password.length < 6) {
      showMessage('Password किमान 6 अक्षरांचा असावा.');
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Authentication अयशस्वी झाले.');
    } catch (e) {
      showMessage('काहीतरी चुकले. पुन्हा प्रयत्न करा.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const WelcomeScreen();
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.apartment,
                      size: 76,
                      color: Color(0xFF176B5B),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Society Connect',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLogin
                          ? 'Login to your account'
                          : 'Create your account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: isLoading ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF176B5B),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isLoading
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(isLogin ? 'Login' : 'Register'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin
                            ? "Don't have an account? Register"
                            : 'Already have an account? Login',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final flatsController = TextEditingController();
  bool isSaving = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> createSociety() async {
    final name = nameController.text.trim();
    final address = addressController.text.trim();
    final flats = int.tryParse(flatsController.text.trim());
    final user = FirebaseAuth.instance.currentUser;

    if (name.isEmpty || address.isEmpty) {
      showMessage('Society name आणि address भरा.');
      return;
    }

    if (flats == null || flats < 1) {
      showMessage('Flats ची योग्य संख्या भरा.');
      return;
    }

    if (user == null) {
      showMessage('कृपया Login करा.');
      return;
    }

    setState(() => isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('societies').add({
        'societyName': name,
        'address': address,
        'flatCount': flats,
        'ownerId': user.uid,
        'ownerEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      nameController.clear();
      addressController.clear();
      flatsController.clear();
      showMessage('Society created successfully!');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showMessage('Error: ${e.message}');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    flatsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Society Connect'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please login again.'))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Society Admin Dashboard',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(user.email ?? ''),
          const SizedBox(height: 20),

          const Text(
            'Create a Society',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Society Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'Full Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: flatsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total Flats (information only)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          FilledButton(
            onPressed: isSaving ? null : createSociety,
            child: Text(
              isSaving ? 'Saving...' : 'Create Society',
            ),
          ),

          const Divider(height: 36),

          const Text(
            'My Societies',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('societies')
                .where('ownerId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Could not load societies. Please try again.',
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final societies = snapshot.data!.docs;

              if (societies.isEmpty) {
                return const Text(
                  'अजून कोणतीही Society तयार केलेली नाही.',
                );
              }

              return Column(
                children: societies.map((society) {
                  final data = society.data();
                  final societyName =
                      data['societyName'] as String? ??
                          'Unnamed Society';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.apartment),
                      ),
                      title: Text(societyName),
                      subtitle: Text(
                        data['address'] as String? ?? '',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FlatManagementScreen(
                              societyId: society.id,
                              societyName: societyName,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FlatManagementScreen extends StatefulWidget {
  final String societyId;
  final String societyName;

  const FlatManagementScreen({
    super.key,
    required this.societyId,
    required this.societyName,
  });

  @override
  State<FlatManagementScreen> createState() =>
      _FlatManagementScreenState();
}

class _FlatManagementScreenState extends State<FlatManagementScreen> {
  final wingController = TextEditingController();
  final flatNumberController = TextEditingController();
  final countController = TextEditingController(text: '20');
  final startNumberController = TextEditingController(text: '101');

  bool isSaving = false;

  CollectionReference<Map<String, dynamic>> get flatsCollection =>
      FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('flats');

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? validateWing() {
    final wing = wingController.text
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '');

    if (wing.isEmpty) return null;

    if (!RegExp(r'^[A-Z0-9-]{1,15}$').hasMatch(wing)) {
      return null;
    }

    return wing;
  }

  String flatDocumentId(String wing, int number) =>
      '${wing}_$number';

  Future<void> addSingleFlat() async {
    final wing = validateWing();
    final number = int.tryParse(flatNumberController.text.trim());

    if (wing == null) {
      showMessage('Wing name भरा. उदा. A किंवा B.');
      return;
    }

    if (number == null || number < 1) {
      showMessage('Flat number योग्य भरा.');
      return;
    }

    setState(() => isSaving = true);

    try {
      final id = flatDocumentId(wing, number);
      final ref = flatsCollection.doc(id);
      final existing = await ref.get();

      if (existing.exists) {
        if (mounted) showMessage('हा फ्लॅट आधीच जोडलेला आहे.');
        return;
      }

      await ref.set({
        'societyId': widget.societyId,
        'wing': wing,
        'flatNumber': number,
        'flatLabel': '$wing-$number',
        'status': 'Unassigned',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      flatNumberController.clear();
      showMessage('Flat $wing-$number added successfully!');
    } on FirebaseException catch (e) {
      if (mounted) showMessage('Error: ${e.message}');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> addMultipleFlats() async {
    final wing = validateWing();
    final count = int.tryParse(countController.text.trim());
    final start = int.tryParse(startNumberController.text.trim());

    if (wing == null) {
      showMessage('Wing name योग्य भरा. उदा. A.');
      return;
    }

    if (count == null || count < 1 || count > 450) {
      showMessage('Flats ची संख्या 1 ते 450 दरम्यान असावी.');
      return;
    }

    if (start == null || start < 1 || start + count - 1 > 999999) {
      showMessage('Starting flat number योग्य भरा.');
      return;
    }

    setState(() => isSaving = true);

    try {
      final refs = List.generate(
        count,
            (i) => flatsCollection.doc(
          flatDocumentId(wing, start + i),
        ),
      );

      // Check for existing flats before writing.
      for (var i = 0; i < refs.length; i += 1) {
        final existing = await refs[i].get();

        if (existing.exists) {
          if (mounted) {
            showMessage(
              'Flat ${wing}-${start + i} आधीच आहे. '
                  'काहीही नवीन सेव्ह केलेले नाही.',
            );
          }
          return;
        }
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var i = 0; i < refs.length; i += 1) {
        final number = start + i;

        batch.set(refs[i], {
          'societyId': widget.societyId,
          'wing': wing,
          'flatNumber': number,
          'flatLabel': '$wing-$number',
          'status': 'Unassigned',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;

      showMessage('$count flats added to Wing $wing!');
    } on FirebaseException catch (e) {
      if (mounted) showMessage('Error: ${e.message}');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    wingController.dispose();
    flatNumberController.dispose();
    countController.dispose();
    startNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flat Management'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.societyName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text('Society ID: ${widget.societyId}'),
          const SizedBox(height: 24),

          const Text(
            '1. Add One Flat',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: wingController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Wing (e.g. A)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: flatNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Flat Number (e.g. 101)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          FilledButton(
            onPressed: isSaving ? null : addSingleFlat,
            child: const Text('Add Single Flat'),
          ),

          const Divider(height: 36),

          const Text(
            '2. Automatically Add Flats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: countController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of Flats (e.g. 20)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: startNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Starting Flat Number (e.g. 101)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: isSaving ? null : addMultipleFlats,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Flats'),
          ),

          if (isSaving) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],

          const Divider(height: 36),

          const Text(
            '3. Flat List',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: flatsCollection.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Could not load flats. Check Firestore Rules.',
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.toList();

              docs.sort((a, b) {
                final wingA = a.data()['wing'] as String? ?? '';
                final wingB = b.data()['wing'] as String? ?? '';
                final wingCompare = wingA.compareTo(wingB);

                if (wingCompare != 0) return wingCompare;

                final numberA =
                    a.data()['flatNumber'] as int? ?? 0;
                final numberB =
                    b.data()['flatNumber'] as int? ?? 0;

                return numberA.compareTo(numberB);
              });

              if (docs.isEmpty) {
                return const Text(
                  'अजून फ्लॅट्स जोडलेले नाहीत.',
                );
              }

              final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> groupedFlats = {};

              for (final doc in docs) {
                final data = doc.data();
                final wing = data['wing'] as String? ?? 'Other';

                groupedFlats.putIfAbsent(wing, () => []);
                groupedFlats[wing]!.add(doc);
              }

              final wings = groupedFlats.keys.toList()..sort();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: wings.map((wing) {
                  final wingFlats = groupedFlats[wing]!;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      leading: const Icon(
                        Icons.apartment,
                        color: Color(0xFF176B5B),
                      ),
                      title: Text(
                        'Wing $wing',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${wingFlats.length} Flats'),
                      children: wingFlats.map((flatDoc) {
                        final flatData = flatDoc.data();
                        final label =
                            flatData['flatLabel'] as String? ?? flatDoc.id;
                        final status =
                            flatData['status'] as String? ?? 'Unassigned';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.home_outlined,
                              color: Color(0xFF176B5B),
                            ),
                            title: Text(
                              'Flat $label',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text('Status: $status'),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}