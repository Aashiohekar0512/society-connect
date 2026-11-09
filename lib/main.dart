import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'visitor_notification_service.dart';
import 'subscription_pricing.dart';
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

// ==================== LOGIN AND REGISTER ====================

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
        await VisitorNotificationService.initializeAndRegister();
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final registerOwner =
        FirebaseFunctions.instance.httpsCallable('registerOwner');

        await registerOwner.call();
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
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return const RoleRouter();
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
                      style: const TextStyle(
                        color: Colors.black54,
                      ),
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
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
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
                          : Text(
                        isLogin ? 'Login' : 'Register',
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => setState(
                            () => isLogin = !isLogin,
                      ),
                      child: Text(
                        isLogin
                            ? "Don't have an account? Register"
                            : 'Already have an account? Login',
                      ),
                    ),

                    const SizedBox(height: 8),

                    OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const ResidentRegistrationScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.person_add_alt_1,
                      ),
                      label: const Text(
                        'Register as Resident',
                      ),
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const GuardRegistrationScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.security,
                      ),
                      label: const Text(
                        'Register as Security Guard',
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
// ==================== ROLE ROUTER ====================

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  String? role;
  String? error;

  @override
  void initState() {
    super.initState();
    checkUserRole();
  }

  Future<void> checkUserRole() async {
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('getMyRole');

      final result = await callable.call();
      debugPrint('ROLE RESULT: ${result.data}');
      final data = Map<String, dynamic>.from(result.data);

      if (!mounted) return;

      setState(() {
        role = data['role'] as String?;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (role == 'owner') {
      return const WelcomeScreen();
    }

    if (role == 'resident') {
      return const ResidentDashboard();
    }

    // Security Guard
    if (role == 'guard') {
      return const GuardDashboard();
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Society Connect'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Role check failed:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (role == 'unknown') {
      final user = FirebaseAuth.instance.currentUser;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Role Debug'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'User role not found.\n\n'
                      'Logged-in UID:\n'
                      '${user?.uid ?? 'No UID'}\n\n'
                      'Email:\n'
                      '${user?.email ?? 'No email'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
// ==================== RESIDENT DASHBOARD ====================

class ResidentDashboard extends StatelessWidget {
  const ResidentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resident Dashboard'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.home_work,
            size: 70,
            color: Color(0xFF176B5B),
          ),

          const SizedBox(height: 12),

          const Text(
            'Welcome Resident 👋',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            user?.email ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 30),

          // My Profile
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: const Text(
                'My Profile',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'View your resident profile',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResidentProfileScreen(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Maintenance
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.currency_rupee),
              ),
              title: const Text(
                'Maintenance',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'View maintenance details',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MaintenanceScreen(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Notices
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.notifications),
              ),
              title: const Text(
                'Notices',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Society announcements',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResidentNoticesScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.notifications_active),
              ),
              title: const Text(
                'Visitor Notifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Check visitor notification status',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const ResidentVisitorNotificationsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Complaints
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.support_agent),
              ),
              title: const Text(
                'Complaints / Helpdesk',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Report a problem to society management',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResidentComplaintsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
class ResidentVisitorNotificationsScreen extends StatelessWidget {
  const ResidentVisitorNotificationsScreen({super.key});


  Future<void> updateVisitorApproval(
      String visitorId,
      String approvalStatus,
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null || visitorId.isEmpty) {
        debugPrint('ERROR: User or visitor ID is missing');
        return;
      }

      final roleDoc = await FirebaseFirestore.instance
          .collection('user_roles')
          .doc(user.uid)
          .get();

      final roleData = roleDoc.data();
      final societyId = roleData?['societyid']?.toString();
      final flatId = roleData?['flatid']?.toString();

      if (societyId == null ||
          societyId.isEmpty ||
          flatId == null ||
          flatId.isEmpty) {
        debugPrint('ERROR: Society ID or Flat ID is missing');
        return;
      }

      debugPrint('Updating visitor: $visitorId');
      debugPrint('Society: $societyId, Flat: $flatId');

      await FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .collection('visitors')
          .doc(visitorId)
          .update({
        'approvalStatus': approvalStatus,
        'approvalUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('SUCCESS: Visitor $approvalStatus');
    } catch (e) {
      debugPrint('APPROVAL ERROR: $e');
      rethrow;
    }
  }
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login again.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Details'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('user_roles')
            .doc(user.uid)
            .get(),
        builder: (context, roleSnapshot) {
          if (roleSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final roleData = roleSnapshot.data?.data();
          debugPrint('Resident role data: $roleData');
          final societyId = roleData?['societyid']?.toString();

          if (societyId == null || societyId.isEmpty) {
            return const Center(
              child: Text('Society information was not found.'),
            );
          }

          return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('societies')
                .doc(societyId)
                .collection('flats')
                .get(),
            builder: (context, flatsSnapshot) {
              if (flatsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (flatsSnapshot.hasError) {
                return const Center(
                  child: Text('Could not load flat details.'),
                );
              }

              final flats = flatsSnapshot.data?.docs ?? [];

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadResidentVisitors(
                  societyId,
                  user.uid,
                  flats,
                ),
                builder: (context, visitorSnapshot) {
                  if (visitorSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (visitorSnapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load visitors. Please check Firestore rules.',
                      ),
                    );
                  }

                  final visitors = visitorSnapshot.data ?? [];

                  if (visitors.isEmpty) {
                    return const Center(
                      child: Text('No visitor records found.'),
                    );
                  }

                  visitors.sort((a, b) {
                    final aTime = a['checkInAt'];
                    final bTime = b['checkInAt'];

                    final aDate = aTime is Timestamp
                        ? aTime.toDate()
                        : DateTime(2000);
                    final bDate = bTime is Timestamp
                        ? bTime.toDate()
                        : DateTime(2000);

                    return bDate.compareTo(aDate);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: visitors.length,
                    itemBuilder: (context, index) {
                      final visitor = visitors[index];

                      final name =
                          visitor['visitorName']?.toString() ?? 'Visitor';
                      final phone =
                          visitor['phone']?.toString() ?? 'Not provided';
                      final flatLabel =
                          visitor['flatLabel']?.toString() ?? 'Flat';
                      final purpose =
                          visitor['purpose']?.toString() ?? 'Not provided';
                      final status =
                          visitor['status']?.toString() ?? 'Unknown';

                      final checkIn = visitor['checkInAt'];
                      final checkOut = visitor['checkOutAt'];
                      final visitorId = visitor['visitorId']?.toString() ?? '';
                      final approvalStatus =
                          visitor['approvalStatus']?.toString() ?? 'Pending';

                      String formatTime(dynamic value) {
                        if (value is Timestamp) {
                          return value.toDate().toLocal().toString().substring(
                            0,
                            16,
                          );
                        }
                        return 'Not available';
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Chip(label: Text(status)),
                                ],
                              ),
                              const Divider(height: 24),
                              Text('Flat: $flatLabel'),
                              const SizedBox(height: 6),
                              Text('Phone: $phone'),
                              const SizedBox(height: 6),
                              Text('Purpose: $purpose'),
                              const SizedBox(height: 6),
                              Text('Check-In: ${formatTime(checkIn)}'),
                              const SizedBox(height: 6),
                              Text('Check-Out: ${formatTime(checkOut)}'),
                              Text('Approval: $approvalStatus'),

                              if (approvalStatus == 'Pending') ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            await updateVisitorApproval(
                                              visitorId,
                                              'Approved',
                                            );

                                            if (!context.mounted) return;

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Visitor Approved successfully'),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!context.mounted) return;

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Approval failed: $e'),
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('Approve'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await updateVisitorApproval(
                                            visitorId,
                                            'Rejected',
                                          );
                                        },
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadResidentVisitors(
      String societyId,
      String uid,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> flats,
      ) async {
    final firestore = FirebaseFirestore.instance;
    final results = <Map<String, dynamic>>[];

    // Get resident's own flat ID.
    final roleDoc = await firestore
        .collection('user_roles')
        .doc(uid)
        .get();

    final roleData = roleDoc.data();
    final flatId = roleData?['flatid']?.toString();

    if (flatId == null || flatId.isEmpty) {
      return results;
    }

    // Guard stores visitor records in the society-level collection.
    final visitorSnapshot = await firestore
        .collection('societies')
        .doc(societyId)
        .collection('visitors')
        .where('flatId', isEqualTo: flatId)
        .get();

    for (final visitorDoc in visitorSnapshot.docs) {
      results.add({
        ...visitorDoc.data(),
        'visitorId': visitorDoc.id,
      });
    }

    return results;
  }
}

// ==================== RESIDENT PROFILE ====================

class ResidentProfileScreen extends StatefulWidget {
  const ResidentProfileScreen({super.key});

  @override
  State<ResidentProfileScreen> createState() =>
      _ResidentProfileScreenState();
}

class _ResidentProfileScreenState
    extends State<ResidentProfileScreen> {
  bool loading = true;
  String? error;

  String name = '';
  String email = '';
  String phone = '';
  String type = '';
  String flatNumber = '';
  String flatLabel = '';
  String societyName = '';

  @override
  void initState() {
    super.initState();
    loadResidentProfile();
  }

  Future<void> loadResidentProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          error = 'User is not logged in.';
          loading = false;
        });
        return;
      }

      final roleDoc = await FirebaseFirestore.instance
          .collection('user_roles')
          .doc(user.uid)
          .get();

      if (!roleDoc.exists) {
        setState(() {
          error = 'Resident role information not found.';
          loading = false;
        });
        return;
      }

      final roleData = roleDoc.data()!;
      print('ROLE DATA: $roleData');
      print('SOCIETY ID: ${roleData['societyId']}');
      print('FLAT ID: ${roleData['flatId']}');
      final societyId = roleData['societyid'];
      final flatId = roleData['flatid'];
      final residentId = roleData['residentid'];

      if (societyId == null ||
          flatId == null ||
          residentId == null) {
        setState(() {
          error = 'Resident information is incomplete.';
          loading = false;
        });
        return;
      }

      final societyDoc = await FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .get();

      final flatDoc = await FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .collection('flats')
          .doc(flatId)
          .get();

      final residentDoc = await FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .collection('flats')
          .doc(flatId)
          .collection('residents')
          .doc(residentId)
          .get();

      if (!residentDoc.exists) {
        setState(() {
          error = 'Resident profile not found.';
          loading = false;
        });
        return;
      }

      final residentData = residentDoc.data()!;
      final flatData = flatDoc.data() ?? {};
      final societyData = societyDoc.data() ?? {};

      setState(() {
        name = residentData['name']?.toString() ?? '';
        email = residentData['email']?.toString() ?? '';
        phone = residentData['phone']?.toString() ?? '';
        type = residentData['type']?.toString() ?? '';

        flatNumber =
            flatData['flatNumber']?.toString() ?? '';

        flatLabel =
            flatData['flatLabel']?.toString() ?? '';

        societyName =
            societyData['societyName']?.toString() ?? '';

        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Widget profileItem(
      IconData icon,
      String title,
      String value,
      ) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFF176B5B),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          value.isEmpty ? 'Not available' : value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            error!,
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 45,
            backgroundColor: Color(0xFF176B5B),
            child: Icon(
              Icons.person,
              size: 50,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            name.isEmpty
                ? 'Resident Profile'
                : name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          profileItem(
            Icons.person,
            'Name',
            name,
          ),

          profileItem(
            Icons.email,
            'Email',
            email,
          ),

          profileItem(
            Icons.phone,
            'Mobile Number',
            phone,
          ),

          profileItem(
            Icons.home,
            'Flat',
            flatLabel.isNotEmpty
                ? flatLabel
                : flatNumber,
          ),

          profileItem(
            Icons.apartment,
            'Society',
            societyName,
          ),

          profileItem(
            Icons.people,
            'Resident Type',
            type,
          ),
        ],
      ),
    );
  }
}
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() =>
      _MaintenanceScreenState();
}

class _MaintenanceScreenState
    extends State<MaintenanceScreen> {
  bool loading = true;
  String? error;

  String? societyId;
  String? flatId;

  @override
  void initState() {
    super.initState();
    loadResidentInfo();
  }

  Future<void> loadResidentInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          error = 'User is not logged in.';
          loading = false;
        });
        return;
      }

      final roleDoc = await FirebaseFirestore.instance
          .collection('user_roles')
          .doc(user.uid)
          .get();

      if (!roleDoc.exists) {
        setState(() {
          error =
          'User role not found.\n\n'
              'Logged-in UID:\n${user.uid}';
          loading = false;
        });
        return;
      }

      final roleData = roleDoc.data()!;

      final society = roleData['societyid'];
      final flat = roleData['flatid'];

      if (society == null || flat == null) {
        setState(() {
          error = 'Resident information is incomplete.';
          loading = false;
        });
        return;
      }

      setState(() {
        societyId = society.toString();
        flatId = flat.toString();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Maintenance'),
          backgroundColor: const Color(0xFF176B5B),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Maintenance'),
          backgroundColor: const Color(0xFF176B5B),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              error!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('societies')
            .doc(societyId)
            .collection('flats')
            .doc(flatId)
            .collection('maintenance')
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final bills = snapshot.data!.docs;

          if (bills.isEmpty) {
            return const Center(
              child: Text(
                'No maintenance bills found.',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(
                Icons.receipt_long,
                size: 70,
                color: Color(0xFF176B5B),
              ),

              const SizedBox(height: 15),

              const Text(
                'Maintenance Bills',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              ...bills.map((bill) {
                final data = bill.data();

                final month =
                    data['month']?.toString() ?? '';

                final amount =
                    data['amount']?.toString() ?? '0';

                final status =
                    data['status']?.toString() ?? '';

                final dueDate =
                    data['dueDate']?.toString() ?? '';

                final isPaid = status == 'Paid';

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 14,
                  ),

                  child: Padding(
                    padding: const EdgeInsets.all(16),

                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt,
                              color: Color(0xFF176B5B),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                month,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ),

                            Text(
                              isPaid
                                  ? 'PAID'
                                  : 'UNPAID',
                              style: TextStyle(
                                fontWeight:
                                FontWeight.bold,
                                color: isPaid
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),

                        const Divider(
                          height: 25,
                        ),

                        Text(
                          'Amount: ₹$amount',
                          style: const TextStyle(
                            fontSize: 17,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Due Date: $dueDate',
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Status: $status',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
// ==================== SOCIETY DASHBOARD ====================

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
    final pricing = getSubscriptionPricing(flats ?? 0);
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('CURRENT USER UID: ${user?.uid}');
    debugPrint('FIREBASE PROJECT: ${Firebase.app().options.projectId}');
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
        'subscriptionStatus': 'trial',
        'subscriptionPlanMaxFlats': pricing?.maxFlats,
        'monthlyPrice': pricing?.monthlyPrice,
        'yearlyPrice': pricing?.yearlyPrice,
        'trialStartAt': FieldValue.serverTimestamp(),
        'trialEndAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
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
      if (mounted) {
        setState(() => isSaving = false);
      }
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
          const SizedBox(height: 5),

          Text(
            'Owner UID: ${user.uid}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
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
                return Text(
                  'Society Error: ${snapshot.error}',
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
                  final trialEndAt = data['trialEndAt'] as Timestamp?;
                  final subscriptionStatus =
                      data['subscriptionStatus'] as String? ?? 'trial';

                  final remainingDays = trialEndAt == null
                      ? 7
                      : trialEndAt.toDate().difference(DateTime.now()).inDays
                      + (trialEndAt.toDate().difference(DateTime.now()).inSeconds > 0
                          ? 1
                          : 0);

                  final trialExpired =
                      subscriptionStatus == 'trial' && remainingDays <= 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.apartment),
                      ),
                      title: Text(societyName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['address'] as String? ?? ''),
                          const SizedBox(height: 6),
                          Text(
                            trialExpired
                                ? 'Free Trial संपला'
                                : subscriptionStatus == 'trial'
                                ? 'Free Trial: $remainingDays दिवस शिल्लक'
                                : 'Subscription: $subscriptionStatus',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: trialExpired
                                  ? Colors.red
                                  : subscriptionStatus == 'trial'
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ],
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

// ==================== FLAT MANAGEMENT MENU ====================

class FlatManagementScreen extends StatelessWidget {
  final String societyId;
  final String societyName;

  const FlatManagementScreen({
    super.key,
    required this.societyId,
    required this.societyName,
  });

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
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.workspace_premium,
                color: Color(0xFF176B5B),
                size: 32,
              ),
              title: const Text('Subscription Plans'),
              subtitle: const Text(
                'Monthly ₹499 | Yearly ₹4,999',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubscriptionPricingScreen(
                      societyId: societyId,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Icon(
            Icons.apartment,
            size: 60,
            color: Color(0xFF176B5B),
          ),

          const SizedBox(height: 12),

          Text(
            societyName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Manage your society',
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          // ================= ADD FLATS =================

          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE1F1EC),
                child: Icon(
                  Icons.add_home_work,
                  color: Color(0xFF176B5B),
                ),
              ),
              title: const Text(
                'Add Flats',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Add one flat or generate multiple flats',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddFlatsScreen(
                      societyId: societyId,
                      societyName: societyName,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ================= VIEW FLATS =================

          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE1F1EC),
                child: Icon(
                  Icons.grid_view,
                  color: Color(0xFF176B5B),
                ),
              ),
              title: const Text(
                'View Flats',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Search and view flats wing-wise',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ViewFlatsScreen(
                      societyId: societyId,
                      societyName: societyName,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ================= MAINTENANCE =================

          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE1F1EC),
                child: Icon(
                  Icons.currency_rupee,
                  color: Color(0xFF176B5B),
                ),
              ),
              title: const Text(
                'Maintenance Management',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Create and manage maintenance bills',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MaintenanceManagementScreen(
                      societyId: societyId,
                      societyName: societyName,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ================= NOTICES =================

          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE1F1EC),
                child: Icon(
                  Icons.notifications_active,
                  color: Color(0xFF176B5B),
                ),
              ),
              title: const Text(
                'Notices Management',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Create and manage society notices',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoticeManagementScreen(
                      societyId: societyId,
                      societyName: societyName,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ================= COMPLAINTS =================

          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE1F1EC),
                child: Icon(
                  Icons.support_agent,
                  color: Color(0xFF176B5B),
                ),
              ),
              title: const Text(
                'Complaints Management',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'View and manage resident complaints',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OwnerComplaintsScreen(
                      societyId: societyId,
                      societyName: societyName,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ================= SECURITY GUARD =================

          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE1F1EC),
                child: Icon(
                  Icons.security,
                  color: Color(0xFF176B5B),
                ),
              ),
              title: const Text(
                'Security Guard Management',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Manage society security guards',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GuardManagementScreen(
                      societyId: societyId,
                      societyName: societyName,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Choose an option to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ADD FLATS SCREEN ====================

class AddFlatsScreen extends StatefulWidget {
  final String societyId;
  final String societyName;

  const AddFlatsScreen({
    super.key,
    required this.societyId,
    required this.societyName,
  });

  @override
  State<AddFlatsScreen> createState() => _AddFlatsScreenState();
}

class _AddFlatsScreenState extends State<AddFlatsScreen> {
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? validateWing() {
    final wing = wingController.text
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '');

    if (!RegExp(r'^[A-Z0-9-]{1,15}$').hasMatch(wing)) {
      return null;
    }

    return wing;
  }

  String flatDocumentId(String wing, int number) =>
      '${wing}_$number';

  // Add a single flat.
  Future<void> addSingleFlat() async {
    final wing = validateWing();
    final number = int.tryParse(flatNumberController.text.trim());

    if (wing == null) {
      showMessage('Wing name योग्य भरा. उदा. A किंवा B.');
      return;
    }

    if (number == null || number < 1 || number > 999999) {
      showMessage('Flat number 1 ते 999999 दरम्यान भरा.');
      return;
    }

    setState(() => isSaving = true);

    try {
      final ref = flatsCollection.doc(flatDocumentId(wing, number));
      final existing = await ref.get();

      if (existing.exists) {
        showMessage('हा फ्लॅट आधीच जोडलेला आहे.');
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
      showMessage('Flat $wing-$number successfully added!');
    } on FirebaseException catch (e) {
      showMessage('Error: ${e.message}');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // Generate multiple flats.
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

    if (start == null ||
        start < 1 ||
        start + count - 1 > 999999) {
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

      // Check for duplicates before saving anything.
      for (var i = 0; i < refs.length; i++) {
        final existing = await refs[i].get();

        if (existing.exists) {
          showMessage(
            'Flat $wing-${start + i} आधीच आहे. '
                'नवीन flats सेव्ह केलेले नाहीत.',
          );
          return;
        }
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var i = 0; i < refs.length; i++) {
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

      showMessage('$count flats added to Wing $wing!');
    } on FirebaseException catch (e) {
      showMessage('Error: ${e.message}');
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
        title: const Text('Add Flats'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.societyName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Add One Flat',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
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

          FilledButton.icon(
            onPressed: isSaving ? null : addSingleFlat,
            icon: const Icon(Icons.add),
            label: const Text('Add Single Flat'),
          ),

          const Divider(height: 36),

          const Text(
            'Automatically Generate Flats',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],

          const SizedBox(height: 16),
          const Text(
            'टीप: Generate करताना Wing चे नावही वर भरा.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// ==================== VIEW FLATS SCREEN ====================

class ViewFlatsScreen extends StatefulWidget {
  final String societyId;
  final String societyName;

  const ViewFlatsScreen({
    super.key,
    required this.societyId,
    required this.societyName,
  });

  @override
  State<ViewFlatsScreen> createState() => _ViewFlatsScreenState();
}

class _ViewFlatsScreenState extends State<ViewFlatsScreen> {
  final searchController = TextEditingController();
  String searchQuery = '';

  CollectionReference<Map<String, dynamic>> get flatsCollection =>
      FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('flats');

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Flats'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.societyName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Search Flat or Wing',
                    hintText: 'e.g. A-101, 101 or B',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        setState(() => searchQuery = '');
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: flatsCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Flats load झाले नाहीत.'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data();
                  final wing =
                  (data['wing'] as String? ?? '').toLowerCase();
                  final label =
                  (data['flatLabel'] as String? ?? doc.id)
                      .toLowerCase();
                  final number =
                  '${data['flatNumber'] ?? ''}'.toLowerCase();

                  return wing.contains(searchQuery) ||
                      label.contains(searchQuery) ||
                      number.contains(searchQuery);
                }).toList();

                docs.sort((a, b) {
                  final wingA =
                      a.data()['wing'] as String? ?? '';
                  final wingB =
                      b.data()['wing'] as String? ?? '';

                  final compare = wingA.compareTo(wingB);
                  if (compare != 0) return compare;

                  return (a.data()['flatNumber'] as int? ?? 0)
                      .compareTo(
                    b.data()['flatNumber'] as int? ?? 0,
                  );
                });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('कोणताही फ्लॅट सापडला नाही.'),
                  );
                }

                final Map<String,
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>>
                grouped = {};

                for (final doc in docs) {
                  final wing =
                      doc.data()['wing'] as String? ?? 'Other';
                  grouped.putIfAbsent(wing, () => []);
                  grouped[wing]!.add(doc);
                }

                final wings = grouped.keys.toList()..sort();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('Total matching flats: ${docs.length}'),
                    ),
                    ...wings.map((wing) {
                      final wingFlats = grouped[wing]!;

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: const Icon(
                            Icons.apartment,
                            color: Color(0xFF176B5B),
                          ),
                          title: Text(
                            'Wing $wing',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text('${wingFlats.length} flats'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics:
                                const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 0.9,
                                ),
                                itemCount: wingFlats.length,
                                itemBuilder: (context, index) {
                                  final doc = wingFlats[index];
                                  final data = doc.data();
                                  final label =
                                      data['flatLabel'] as String? ??
                                          doc.id;
                                  final status =
                                      data['status'] as String? ??
                                          'Unassigned';

                                  return InkWell(
                                    borderRadius:
                                    BorderRadius.circular(12),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FlatDetailsScreen(
                                                societyId: widget.societyId,
                                                societyName: widget.societyName,
                                                flatId: doc.id,
                                                flatLabel: label,
                                                wing: wing,
                                                flatNumber:
                                                data['flatNumber']
                                                    ?.toString() ??
                                                    '',
                                                status: status,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F7F6),
                                        border: Border.all(
                                          color: const Color(0xFF176B5B)
                                              .withOpacity(0.4),
                                        ),
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.home_outlined,
                                            color: Color(0xFF176B5B),
                                            size: 26,
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            label,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            status,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== FLAT DETAILS & RESIDENT MANAGEMENT ====================
String generateInvitationCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();

  return List.generate(
    10,
        (_) => chars[random.nextInt(chars.length)],
  ).join();
}
class FlatDetailsScreen extends StatelessWidget {
  final String societyId;
  final String societyName;
  final String flatId;
  final String flatLabel;
  final String wing;
  final String flatNumber;
  final String status;

  const FlatDetailsScreen({
    super.key,
    required this.societyId,
    required this.societyName,
    required this.flatId,
    required this.flatLabel,
    required this.wing,
    required this.flatNumber,
    required this.status,
  });

  CollectionReference<Map<String, dynamic>> get residentsCollection =>
      FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .collection('flats')
          .doc(flatId)
          .collection('residents');

  Future<void> openResidentForm(
      BuildContext context, {
        String? residentId,
        Map<String, dynamic>? existing,
      }) async {
    final nameController = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final phoneController = TextEditingController(
      text: existing?['phone'] as String? ?? '',
    );
    final emailController = TextEditingController(
      text: existing?['email'] as String? ?? '',
    );

    String residentType =
        existing?['type'] as String? ?? 'Owner';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                residentId == null ? 'Add Resident' : 'Edit Resident',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: residentType,
                      decoration: const InputDecoration(
                        labelText: 'Resident Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Owner',
                          child: Text('Owner'),
                        ),
                        DropdownMenuItem(
                          value: 'Tenant',
                          child: Text('Tenant'),
                        ),
                        DropdownMenuItem(
                          value: 'Family Member',
                          child: Text('Family Member'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => residentType = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();
                    final email = emailController.text.trim();

                    if (name.isEmpty || phone.isEmpty || email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Name, Mobile Number आणि Email भरा.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('कृपया योग्य Email Address भरा.'),
                        ),
                      );
                      return;
                    }

                    setDialogState(() => saving = true);

                    try {
                      final data = <String, dynamic>{
                        'name': name,
                        'phone': phone,
                        'email': email,
                        'type': residentType,
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      if (residentId == null) {
                        final invitationCode = generateInvitationCode();
                        final residentRef = residentsCollection.doc();
                        data['createdAt'] = FieldValue.serverTimestamp();
                        data['invitationCode'] = invitationCode;
                        data['invitationUsed'] = false;
                        data['uid'] = null;




                        final invitationRef = FirebaseFirestore.instance
                            .collection('resident_invitations')
                            .doc(invitationCode);

                        final batch = FirebaseFirestore.instance.batch();

                        batch.set(residentRef, {
                          ...data,
                          'invitationCode': invitationCode,
                          'invitationUsed': false,
                          'uid': null,
                        });

                        batch.set(invitationRef, {
                          'invitationCode': invitationCode,
                          'societyId': societyId,
                          'flatId': flatId,
                          'residentId': residentRef.id,
                          'email': (data['email'] as String).trim().toLowerCase(),
                          'used': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        await batch.commit();
                        await FirebaseFirestore.instance
                            .collection('societies')
                            .doc(societyId)
                            .collection('flats')
                            .doc(flatId)
                            .update({
                          'status': 'Occupied',
                        });

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Resident added! Invitation Code: $invitationCode',
                              ),
                              duration: const Duration(seconds: 10),
                            ),
                          );
                        }
                      } else {
                        await residentsCollection
                            .doc(residentId)
                            .update(data);
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } on FirebaseException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Save failed: ${e.message}'),
                          ),
                        );
                      }
                    } finally {

                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> deleteResident(
      BuildContext context,
      String residentId,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Resident?'),
        content: const Text(
          'या रहिवाशाची नोंद कायमची हटवायची आहे का?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await residentsCollection.doc(residentId).delete();

      final remaining = await residentsCollection.limit(1).get();

      if (remaining.docs.isEmpty) {
        await FirebaseFirestore.instance
            .collection('societies')
            .doc(societyId)
            .collection('flats')
            .doc(flatId)
            .update({
          'status': 'Unassigned',
        });
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flat Details'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openResidentForm(context),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Resident'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.home_work,
                    size: 42,
                    color: Color(0xFF176B5B),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    flatLabel,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Society: $societyName'),
                  Text('Wing: $wing'),
                  Text('Flat Number: $flatNumber'),
                  Text('Status: $status'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Owner / Tenant Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: residentsCollection.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Residents load झाले नाहीत. Firestore Rules तपासा.',
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final residents = snapshot.data!.docs;

              if (residents.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'या फ्लॅटसाठी अजून Resident जोडलेला नाही.\n'
                          'Add Resident बटण वापरा.',
                    ),
                  ),
                );
              }

              return Column(
                children: residents.map((doc) {
                  final data = doc.data();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          data['type'] == 'Owner'
                              ? Icons.person
                              : Icons.people_alt,
                        ),
                      ),
                      title: Text(
                        data['name'] as String? ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Type: ${data['type'] ?? 'Owner'}\n'
                              'Mobile: ${data['phone'] ?? '-'}\n'
                              'Email: ${data['email'] ?? '-'}',
                        ),
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            openResidentForm(
                              context,
                              residentId: doc.id,
                              existing: data,
                            );
                          } else if (value == 'delete') {
                            deleteResident(context, doc.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}
class ResidentRegistrationScreen extends StatefulWidget {
  const ResidentRegistrationScreen({super.key});

  @override
  State<ResidentRegistrationScreen> createState() =>
      _ResidentRegistrationScreenState();
}

class _ResidentRegistrationScreenState
    extends State<ResidentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _invitationController = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _invitationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF14181F);
    const card = Color(0xFF1D2330);
    const gold = Color(0xFFC89B3C);

    return Scaffold(
      backgroundColor: dark,
      appBar: AppBar(
        title: const Text('Resident Registration'),
        backgroundColor: dark,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.apartment_rounded,
                    size: 64,
                    color: gold,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Join Your Society',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Register using the invitation code '
                        'provided by your society owner.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 28),

                  _field(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),

                  _field(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: gold,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _hidePassword = !_hidePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _field(
                    controller: _invitationController,
                    label: 'Invitation Code',
                    icon: Icons.confirmation_number_outlined,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: dark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text(
                      'Create Resident Account',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: const Color(0xFFC89B3C)),
        filled: true,
        fillColor: const Color(0xFF1D2330),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator ??
              (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This field is required';
            }
            return null;
          },
    );
  }

Future<void> _register() async {
if (!_formKey.currentState!.validate()) return;

setState(() => _loading = true);

UserCredential? credential;

try {
final email =
_emailController.text.trim().toLowerCase();

final password =
_passwordController.text;

final name =
_nameController.text.trim();

final invitationCode =
_invitationController.text.trim().toUpperCase();

if (invitationCode.isEmpty) {
throw Exception(
'Please enter your invitation code.',
);
}

// Create Firebase account
credential = await FirebaseAuth.instance
.createUserWithEmailAndPassword(
email: email,
password: password,
);

// Set user's name
await credential.user!.updateDisplayName(name);

// Send email verification
await credential.user!.sendEmailVerification();

// Redeem invitation through Cloud Function
final callable = FirebaseFunctions.instance
.httpsCallable('redeemResidentInvitation');

await callable.call({
'invitationCode': invitationCode,
'email': email,
});

// Sign out after registration
await FirebaseAuth.instance.signOut();

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Registration successful! '
'Verification email sent. '
'Please verify your email before logging in.',
),
duration: Duration(seconds: 6),
),
);

Navigator.pop(context);
} on FirebaseAuthException catch (e) {
String message;

switch (e.code) {
case 'email-already-in-use':
message =
'This email already has an account. Please log in.';
break;

case 'weak-password':
message =
'Please choose a stronger password.';
break;

case 'invalid-email':
message =
'Please enter a valid email address.';
break;

default:
message =
e.message ??
'Registration failed. Please try again.';
}

if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message)),
);
}
} on FirebaseFunctionsException catch (e) {
String message;

switch (e.code) {
case 'not-found':
message = 'Invalid invitation code.';
break;

case 'failed-precondition':
message =
'This invitation code has already been used or is incomplete.';
break;

case 'permission-denied':
message =
'This invitation belongs to a different email address.';
break;

case 'unauthenticated':
message =
'Please try registering again.';
break;

default:
message =
e.message ??
'Unable to verify invitation code.';
}

if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message)),
);
}
} catch (e) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
e.toString().replaceFirst(
'Exception: ',
'',
),
),
),
);
}
} finally {
if (mounted) {
setState(() => _loading = false);
}
}
}
}
class MaintenanceManagementScreen extends StatefulWidget {
  final String societyId;
  final String societyName;

  const MaintenanceManagementScreen({
    super.key,
    required this.societyId,
    required this.societyName,
  });

  @override
  State<MaintenanceManagementScreen> createState() =>
      _MaintenanceManagementScreenState();
}

class _MaintenanceManagementScreenState
    extends State<MaintenanceManagementScreen> {
  bool loading = true;
  String? error;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> flats = [];

  @override
  void initState() {
    super.initState();
    loadFlats();
  }

  Future<void> loadFlats() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('flats')
          .orderBy('flatNumber')
          .get();

      if (!mounted) return;

      setState(() {
        flats = snapshot.docs;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Management'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            error!,
            textAlign: TextAlign.center,
          ),
        ),
      )
          : flats.isEmpty
          ? const Center(
        child: Text(
          'No flats found.',
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: flats.length,
        itemBuilder: (context, index) {
          final flat = flats[index];
          final data = flat.data();

          final flatLabel =
              data['flatLabel']?.toString() ?? flat.id;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),

              leading: const CircleAvatar(
                child: Icon(Icons.home),
              ),

              title: Text(
                flatLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),

              subtitle: Text(
                'Status: ${data['status']?.toString() ?? 'Unknown'}',
              ),

              trailing: const Icon(
                Icons.chevron_right,
              ),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MaintenanceBillsScreen(
                          societyId: widget.societyId,
                          societyName: widget.societyName,
                          flatId: flat.id,
                          flatLabel: flatLabel,
                        ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
class MaintenanceBillsScreen extends StatelessWidget {
  final String societyId;
  final String societyName;
  final String flatId;
  final String flatLabel;

  const MaintenanceBillsScreen({
    super.key,
    required this.societyId,
    required this.societyName,
    required this.flatId,
    required this.flatLabel,
  });

  @override
  Widget build(BuildContext context) {
    final billsRef = FirebaseFirestore.instance
        .collection('societies')
        .doc(societyId)
        .collection('flats')
        .doc(flatId)
        .collection('maintenance');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Bills'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: billsRef.snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final bills = snapshot.data!.docs;

          if (bills.isEmpty) {
            return const Center(
              child: Text(
                'No maintenance bills found.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Icon(
                Icons.receipt_long,
                size: 65,
                color: Color(0xFF176B5B),
              ),

              const SizedBox(height: 10),

              Text(
                flatLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                societyName,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 25),

              ...bills.map((bill) {
                final data = bill.data();

                final month =
                    data['month']?.toString() ?? 'Unknown';

                final amount =
                    data['amount']?.toString() ?? '0';

                final dueDate =
                    data['dueDate']?.toString() ?? '-';

                final status =
                    data['status']?.toString() ?? 'Unpaid';

                final isPaid = status == 'Paid';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),

                  child: Padding(
                    padding: const EdgeInsets.all(16),

                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt,
                              color: Color(0xFF176B5B),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                month,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            Text(
                              isPaid ? 'PAID' : 'UNPAID',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isPaid
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 25),

                        Text(
                          'Amount: ₹$amount',
                          style: const TextStyle(
                            fontSize: 17,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Due Date: $dueDate',
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),

                        if (!isPaid) ...[
                          const SizedBox(height: 15),

                          SizedBox(
                            width: double.infinity,

                            child: FilledButton.icon(
                              onPressed: () async {
                                try {
                                  await bill.reference.update({
                                    'status': 'Paid',
                                    'paidAt':
                                    FieldValue.serverTimestamp(),
                                  });

                                  if (!context.mounted) {
                                    return;
                                  }

                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Maintenance marked as Paid!',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) {
                                    return;
                                  }

                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error: $e',
                                      ),
                                    ),
                                  );
                                }
                              },

                              icon: const Icon(
                                Icons.check_circle,
                              ),

                              label: const Text(
                                'Mark as Paid',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),

      // CREATE BILL BUTTON
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateMaintenanceScreen(
                societyId: societyId,
                societyName: societyName,
                flatId: flatId,
                flatLabel: flatLabel,
              ),
            ),
          );
        },

        icon: const Icon(Icons.add),

        label: const Text(
          'Create Bill',
        ),
      ),
    );
  }
}
class CreateMaintenanceScreen extends StatefulWidget {
  final String societyId;
  final String societyName;
  final String flatId;
  final String flatLabel;

  const CreateMaintenanceScreen({
    super.key,
    required this.societyId,
    required this.societyName,
    required this.flatId,
    required this.flatLabel,
  });

  @override
  State<CreateMaintenanceScreen> createState() =>
      _CreateMaintenanceScreenState();
}

class _CreateMaintenanceScreenState
    extends State<CreateMaintenanceScreen> {
  final monthController = TextEditingController();
  final amountController = TextEditingController();
  final dueDateController = TextEditingController();

  String status = 'Unpaid';
  bool saving = false;

  @override
  void dispose() {
    monthController.dispose();
    amountController.dispose();
    dueDateController.dispose();
    super.dispose();
  }

  Future<void> saveMaintenance() async {
    final month = monthController.text.trim();
    final amount = int.tryParse(
      amountController.text.trim(),
    );
    final dueDate = dueDateController.text.trim();

    if (month.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Month भरा.'),
        ),
      );
      return;
    }

    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('योग्य amount भरा.'),
        ),
      );
      return;
    }

    if (dueDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Due date भरा.'),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final documentId = month
          .replaceAll(' ', '-')
          .replaceAll('/', '-');

      await FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('flats')
          .doc(widget.flatId)
          .collection('maintenance')
          .doc(documentId)
          .set({
        'month': month,
        'amount': amount,
        'status': status,
        'dueDate': dueDate,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maintenance bill created successfully!',
          ),
        ),
      );

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Firebase Error: ${e.code}\n${e.message}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Maintenance'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.receipt_long,
            size: 65,
            color: Color(0xFF176B5B),
          ),

          const SizedBox(height: 12),

          Text(
            widget.flatLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            widget.societyName,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 25),

          TextField(
            controller: monthController,
            decoration: const InputDecoration(
              labelText: 'Month',
              hintText: 'November 2026',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Maintenance Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: dueDateController,
            decoration: const InputDecoration(
              labelText: 'Due Date',
              hintText: '2026-11-10',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Unpaid',
                child: Text('Unpaid'),
              ),
              DropdownMenuItem(
                value: 'Paid',
                child: Text('Paid'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  status = value;
                });
              }
            },
          ),

          const SizedBox(height: 25),

          FilledButton(
            onPressed: saving ? null : saveMaintenance,
            child: Text(
              saving
                  ? 'Saving...'
                  : 'Create Maintenance Bill',
            ),
          ),
        ],
      ),
    );
  }
}
// ==================== NOTICE MANAGEMENT ====================

class NoticeManagementScreen extends StatefulWidget {
  final String societyId;
  final String societyName;

  const NoticeManagementScreen({
    super.key,
    required this.societyId,
    required this.societyName,
  });

  @override
  State<NoticeManagementScreen> createState() =>
      _NoticeManagementScreenState();
}

class _NoticeManagementScreenState
    extends State<NoticeManagementScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  String priority = 'Normal';
  bool saving = false;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> createNotice() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter title and description'),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      await FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('notices')
          .add({
        'title': title,
        'description': description,
        'priority': priority,
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      titleController.clear();
      descriptionController.clear();

      setState(() {
        priority = 'Normal';
        saving = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notice published successfully'),
        ),
      );
    } catch (e) {
      setState(() {
        saving = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  Future<void> deleteNotice(String noticeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('notices')
          .doc(noticeId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notice deleted'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  void showCreateNoticeDialog() {
    titleController.clear();
    descriptionController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Create Notice',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Notice Title',
                        hintText: 'Society Meeting',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter notice details...',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(
                          value: 'Important',
                          child: Text('Important'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            priority = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                          Navigator.pop(context);
                          await createNotice();
                        },
                        icon: const Icon(Icons.publish),
                        label: Text(
                          saving ? 'Publishing...' : 'Publish Notice',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Society Notices'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('societies')
            .doc(widget.societyId)
            .collection('notices')
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final notices = snapshot.data?.docs ?? [];

          if (notices.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 70,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No notices yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notices.length,
            itemBuilder: (context, index) {
              final doc = notices[index];
              final data =
              doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? '';
              final description = data['description'] ?? '';
              final noticePriority =
                  data['priority'] ?? 'Normal';

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            noticePriority == 'Important'
                                ? Icons.priority_high
                                : Icons.notifications,
                            color:
                            noticePriority == 'Important'
                                ? Colors.red
                                : const Color(0xFF176B5B),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              deleteNotice(doc.id);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Priority: $noticePriority',
                        style: TextStyle(
                          color:
                          noticePriority == 'Important'
                              ? Colors.red
                              : Colors.grey[700],
                          fontWeight: FontWeight.w600,
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

      floatingActionButton: FloatingActionButton.extended(
        onPressed: showCreateNoticeDialog,
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Notice'),
      ),
    );
  }
}
class ResidentComplaintsScreen extends StatefulWidget {
  const ResidentComplaintsScreen({super.key});

  @override
  State<ResidentComplaintsScreen> createState() =>
      _ResidentComplaintsScreenState();
}

class _ResidentComplaintsScreenState
    extends State<ResidentComplaintsScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  String category = 'General';
  bool saving = false;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> submitComplaint() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter complaint title and description.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final roleDoc = await FirebaseFirestore.instance
          .collection('user_roles')
          .doc(user.uid)
          .get();

      if (!roleDoc.exists) {
        throw Exception('Resident role information not found.');
      }

      final roleData = roleDoc.data()!;

      final societyId = roleData['societyid'] as String?;

      if (societyId == null || societyId.isEmpty) {
        throw Exception('Society information not found.');
      }

      await FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .collection('complaints')
          .add({
        'title': title,
        'description': description,
        'category': category,
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      titleController.clear();
      descriptionController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complaint submitted successfully.'),
        ),
      );

      setState(() {
        category = 'General';
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit complaint: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints / Helpdesk'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.support_agent,
            size: 70,
            color: Color(0xFF176B5B),
          ),

          const SizedBox(height: 12),

          const Text(
            'Report a Problem',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Submit your complaint to society management.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 25),

          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Complaint Title',
              hintText: 'Example: Water leakage',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            items: const [
              DropdownMenuItem(
                value: 'General',
                child: Text('General'),
              ),
              DropdownMenuItem(
                value: 'Water',
                child: Text('Water'),
              ),
              DropdownMenuItem(
                value: 'Electricity',
                child: Text('Electricity'),
              ),
              DropdownMenuItem(
                value: 'Cleaning',
                child: Text('Cleaning'),
              ),
              DropdownMenuItem(
                value: 'Security',
                child: Text('Security'),
              ),
              DropdownMenuItem(
                value: 'Lift',
                child: Text('Lift'),
              ),
              DropdownMenuItem(
                value: 'Parking',
                child: Text('Parking'),
              ),
              DropdownMenuItem(
                value: 'Other',
                child: Text('Other'),
              ),
            ],
            onChanged: saving
                ? null
                : (value) {
              if (value == null) return;

              setState(() {
                category = value;
              });
            },
          ),

          const SizedBox(height: 16),

          TextField(
            controller: descriptionController,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Explain your problem...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.description),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: saving ? null : submitComplaint,
              icon: saving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.send),
              label: Text(
                saving ? 'Submitting...' : 'Submit Complaint',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class ResidentNoticesScreen extends StatelessWidget {
  const ResidentNoticesScreen({super.key});

  Future<String?> _getSocietyId() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final roleDoc = await FirebaseFirestore.instance
        .collection('user_roles')
        .doc(user.uid)
        .get();

    if (!roleDoc.exists) {
      return null;
    }

    final data = roleDoc.data();

    return data?['societyid'] as String?;
  }

  String formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Society Notices'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),

      body: FutureBuilder<String?>(
        future: _getSocietyId(),

        builder: (context, societySnapshot) {
          if (societySnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (societySnapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${societySnapshot.error}',
              ),
            );
          }

          final societyId = societySnapshot.data;

          if (societyId == null || societyId.isEmpty) {
            return const Center(
              child: Text(
                'Society information not found.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final noticesRef = FirebaseFirestore.instance
              .collection('societies')
              .doc(societyId)
              .collection('notices')
              .orderBy('createdAt', descending: true);

          return StreamBuilder<QuerySnapshot>(
            stream: noticesRef.snapshots(),

            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load notices.\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 70,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No notices available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Society notices will appear here.',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data =
                  docs[index].data() as Map<String, dynamic>;

                  final title =
                      data['title']?.toString() ?? '';

                  final description =
                      data['description']?.toString() ?? '';

                  final priority =
                      data['priority']?.toString() ?? 'Normal';

                  final createdAt =
                  formatDate(data['createdAt']);

                  IconData priorityIcon = Icons.info_outline;

                  if (priority == 'Important') {
                    priorityIcon = Icons.priority_high;
                  } else if (priority == 'Urgent') {
                    priorityIcon = Icons.warning_amber;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                const Color(0xFFE1F1EC),
                                child: Icon(
                                  priorityIcon,
                                  color:
                                  const Color(0xFF176B5B),
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              const Icon(
                                Icons.flag,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Priority: $priority',
                                style: const TextStyle(
                                  color: Colors.black54,
                                ),
                              ),

                              const Spacer(),

                              if (createdAt.isNotEmpty)
                                Text(
                                  createdAt,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
class OwnerComplaintsScreen extends StatelessWidget {
  final String societyId;
  final String societyName;

  const OwnerComplaintsScreen({
    super.key,
    required this.societyId,
    required this.societyName,
  });

  Future<void> updateComplaintStatus(
      BuildContext context,
      String complaintId,
      String status,
      ) async {
    try {
      await FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .collection('complaints')
          .doc(complaintId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complaint marked as $status'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update complaint: $e'),
        ),
      );
    }
  }

  Future<void> deleteComplaint(
      BuildContext context,
      String complaintId,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Complaint'),
          content: const Text(
            'Are you sure you want to delete this complaint?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .collection('complaints')
          .doc(complaintId)
          .delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complaint deleted.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete complaint: $e'),
        ),
      );
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaintsRef = FirebaseFirestore.instance
        .collection('societies')
        .doc(societyId)
        .collection('complaints')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text('Complaints - $societyName'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: complaintsRef.snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load complaints.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.support_agent,
                    size: 70,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No complaints',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Resident complaints will appear here.',
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];

              final data =
              doc.data() as Map<String, dynamic>;

              final title =
                  data['title']?.toString() ?? 'No title';

              final description =
                  data['description']?.toString() ?? '';

              final category =
                  data['category']?.toString() ?? 'General';

              final email =
                  data['createdByEmail']?.toString() ?? '';

              final status =
                  data['status']?.toString() ?? 'Pending';

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor:
                            Color(0xFFE1F1EC),
                            child: Icon(
                              Icons.report_problem,
                              color: Color(0xFF176B5B),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                deleteComplaint(
                                  context,
                                  doc.id,
                                );
                              }
                            },
                            itemBuilder: (context) {
                              return const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const Icon(
                            Icons.category,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category,
                            style: const TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      if (email.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.email,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                email,
                                style: const TextStyle(
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          const Text(
                            'Status:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor(status)
                                  .withValues(alpha: 0.12),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(
                          labelText: 'Change Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'In Progress',
                            child: Text('In Progress'),
                          ),
                          DropdownMenuItem(
                            value: 'Resolved',
                            child: Text('Resolved'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null ||
                              value == status) {
                            return;
                          }

                          updateComplaintStatus(
                            context,
                            doc.id,
                            value,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
class GuardManagementScreen extends StatefulWidget {
  final String societyId;
  final String societyName;

  const GuardManagementScreen({
    super.key,
    required this.societyId,
    required this.societyName,
  });

  @override
  State<GuardManagementScreen> createState() =>
      _GuardManagementScreenState();
}

class _GuardManagementScreenState
    extends State<GuardManagementScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  bool saving = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  // ============================================================
  // GENERATE INVITATION CODE
  // ============================================================

  String generateInvitationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

    final random = Random();

    return List.generate(
      10,
          (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // ============================================================
  // ADD GUARD
  // ============================================================

  Future<void> addGuard() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim().toLowerCase();

    if (name.isEmpty ||
        phone.isEmpty ||
        email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter guard name, phone number and email.',
          ),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final guardsCollection = FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('guards');

      final guardRef = guardsCollection.doc();

      final invitationCode = generateInvitationCode();

      final invitationRef = FirebaseFirestore.instance
          .collection('guard_invitations')
          .doc(invitationCode);

      // Create guard + invitation together
      final batch = FirebaseFirestore.instance.batch();

      batch.set(guardRef, {
        'name': name,
        'phone': phone,
        'email': email,
        'status': 'Active',
        'uid': null,
        'invitationCode': invitationCode,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(invitationRef, {
        'invitationCode': invitationCode,
        'societyId': widget.societyId,
        'guardId': guardRef.id,
        'email': email,
        'used': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      nameController.clear();
      phoneController.clear();
      emailController.clear();

      if (!mounted) return;

      Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Guard Added Successfully',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.security,
                  size: 60,
                  color: Color(0xFF176B5B),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Guard Invitation Code',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F1EC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    invitationCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF176B5B),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Give this code to the security guard. '
                      'The guard will use it during registration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),

            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Guard added successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add guard: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ============================================================
  // SHOW ADD GUARD DIALOG
  // ============================================================

  void showAddGuardDialog() {
    nameController.clear();
    phoneController.clear();
    emailController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Add Security Guard',
          ),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Guard Name',
                    hintText: 'Example: Rahul Patil',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: 'Example: 9876543210',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Example: guard@email.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                await addGuard();
              },
              icon: saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.add),
              label: Text(
                saving ? 'Saving...' : 'Add Guard',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // CHANGE STATUS
  // ============================================================

  Future<void> changeGuardStatus(
      String guardId,
      String status,
      ) async {
    try {
      await FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('guards')
          .doc(guardId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Guard status changed to $status.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to change status: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE GUARD
  // ============================================================

  Future<void> deleteGuard(
      String guardId,
      String guardName,
      String? invitationCode,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Guard',
          ),
          content: Text(
            'Are you sure you want to delete $guardName?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final guardRef = FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('guards')
          .doc(guardId);

      batch.delete(guardRef);

      if (invitationCode != null &&
          invitationCode.isNotEmpty) {
        final invitationRef = FirebaseFirestore.instance
            .collection('guard_invitations')
            .doc(invitationCode);

        batch.delete(invitationRef);
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Guard deleted successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete guard: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final guardsRef = FirebaseFirestore.instance
        .collection('societies')
        .doc(widget.societyId)
        .collection('guards')
        .orderBy(
      'createdAt',
      descending: true,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Security Guard Management',
        ),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: showAddGuardDialog,
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Guard'),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: guardsRef.snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load guards.\n\n'
                      '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.security,
                      size: 80,
                      color: Colors.grey,
                    ),

                    SizedBox(height: 16),

                    Text(
                      'No Security Guards',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Add your society security guard '
                          'using the button below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ),

            itemCount: docs.length,

            itemBuilder: (context, index) {
              final doc = docs[index];

              final data =
              doc.data() as Map<String, dynamic>;

              final name =
                  data['name']?.toString() ??
                      'Unknown Guard';

              final phone =
                  data['phone']?.toString() ?? '';

              final email =
                  data['email']?.toString() ?? '';

              final status =
                  data['status']?.toString() ??
                      'Active';

              final invitationCode =
              data['invitationCode']?.toString();

              final isActive =
                  status == 'Active';

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 14,
                ),

                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                            const Color(0xFFE1F1EC),

                            child: const Icon(
                              Icons.security,
                              color: Color(0xFF176B5B),
                              size: 30,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 5),

                                Text(
                                  isActive
                                      ? 'Active Guard'
                                      : 'Inactive Guard',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                deleteGuard(
                                  doc.id,
                                  name,
                                  invitationCode,
                                );
                              }
                            },

                            itemBuilder: (context) {
                              return const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (phone.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 19,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(phone),
                            ),
                          ],
                        ),

                      if (phone.isNotEmpty)
                        const SizedBox(height: 8),

                      if (email.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.email,
                              size: 19,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(email),
                            ),
                          ],
                        ),

                      if (invitationCode != null &&
                          invitationCode.isNotEmpty)
                        const SizedBox(height: 12),

                      if (invitationCode != null &&
                          invitationCode.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                            const Color(0xFFE1F1EC),
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.vpn_key,
                                color:
                                Color(0xFF176B5B),
                              ),

                              const SizedBox(width: 8),

                              const Text(
                                'Invitation: ',
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),

                              Expanded(
                                child: SelectableText(
                                  invitationCode,
                                  style: const TextStyle(
                                    fontWeight:
                                    FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: status,

                        decoration:
                        const InputDecoration(
                          labelText: 'Guard Status',
                          border: OutlineInputBorder(),
                          prefixIcon:
                          Icon(Icons.toggle_on),
                        ),

                        items: const [
                          DropdownMenuItem(
                            value: 'Active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'Inactive',
                            child: Text('Inactive'),
                          ),
                        ],

                        onChanged: (value) {
                          if (value == null ||
                              value == status) {
                            return;
                          }

                          changeGuardStatus(
                            doc.id,
                            value,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
class GuardRegistrationScreen extends StatefulWidget {
  const GuardRegistrationScreen({super.key});

  @override
  State<GuardRegistrationScreen> createState() =>
      _GuardRegistrationScreenState();
}

class _GuardRegistrationScreenState
    extends State<GuardRegistrationScreen> {
  final invitationController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    invitationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> registerGuard() async {
    final invitationCode =
    invitationController.text.trim().toUpperCase();

    final email =
    emailController.text.trim().toLowerCase();

    final password =
    passwordController.text.trim();

    if (invitationCode.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter invitation code, email and password.',
          ),
        ),
      );
      return;
    }

    if (!RegExp(r'^[A-Z0-9]{10}$').hasMatch(invitationCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invitation code must contain 10 characters.',
          ),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password must be at least 6 characters.',
          ),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // Create Firebase account
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception(
          'Unable to create account.',
        );
      }

      // Send email verification
      await user.sendEmailVerification();

      // Redeem guard invitation
      final callable = FirebaseFunctions.instance
          .httpsCallable('redeemGuardInvitation');

      await callable.call({
        'invitationCode': invitationCode,
        'email': email,
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Registration Successful',
            ),
            content: const Text(
              'Your guard account has been created successfully.\n\n'
                  'A verification email has been sent to your email address.\n\n'
                  'Please verify your email and then login.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed.';

      if (e.code == 'email-already-in-use') {
        message =
        'This email is already registered.';
      } else if (e.code == 'invalid-email') {
        message =
        'Please enter a valid email address.';
      } else if (e.code == 'weak-password') {
        message =
        'Password is too weak.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to verify invitation.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registration failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Guard Registration',
        ),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),

        children: [
          const SizedBox(height: 20),

          const Icon(
            Icons.security,
            size: 80,
            color: Color(0xFF176B5B),
          ),

          const SizedBox(height: 16),

          const Text(
            'Create Guard Account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Enter the invitation code given by your society owner.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 30),

          TextField(
            controller: invitationController,
            textCapitalization:
            TextCapitalization.characters,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Invitation Code',
              hintText: 'Example: A1B2C3D4E5',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.vpn_key),
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: emailController,
            keyboardType:
            TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter the email given to owner',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Create your password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    obscurePassword =
                    !obscurePassword;
                  });
                },
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
              loading ? null : registerGuard,

              icon: loading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.person_add),

              label: Text(
                loading
                    ? 'Creating Account...'
                    : 'Create Guard Account',
              ),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'The invitation code and email must match '
                'the details entered by the society owner.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
class GuardDashboard extends StatelessWidget {
  const GuardDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guard Dashboard'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.security,
            size: 80,
            color: Color(0xFF176B5B),
          ),

          const SizedBox(height: 12),

          const Text(
            'Welcome Security Guard 👋',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            user?.email ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 30),

          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: const Text(
                'My Profile',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'View guard profile',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('कृपया पुन्हा Login करा.'),
                    ),
                  );
                  return;
                }

                FirebaseFirestore.instance
                    .collection('user_roles')
                    .doc(user.uid)
                    .get()
                    .then((roleDoc) {
                  if (!context.mounted) return;

                  final data = roleDoc.data();
                  final societyId = data?['societyid'] as String?;

                  if (!roleDoc.exists ||
                      data?['role'] != 'guard' ||
                      societyId == null ||
                      societyId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Guard माहिती मिळाली नाही.'),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuardProfileScreen(
                        societyId: societyId,
                        guardId: (data?['guardid'] ?? '').toString(),
                        email: user.email ?? '',
                      ),
                    ),
                  );
                }).catchError((error) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $error')),
                  );
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.people),
              ),
              title: const Text(
                'Visitor Management',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Manage society visitors',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('कृपया पुन्हा Login करा.'),
                    ),
                  );
                  return;
                }

                try {
                  final roleDoc = await FirebaseFirestore.instance
                      .collection('user_roles')
                      .doc(user.uid)
                      .get();

                  if (!context.mounted) return;

                  final data = roleDoc.data();
                  final societyId = data?['societyid'] as String?;

                  if (!roleDoc.exists ||
                      data?['role'] != 'guard' ||
                      societyId == null ||
                      societyId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Guard Society माहिती मिळाली नाही.'),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisitorCheckOutScreen(
                        societyId: societyId,
                      ),
                    ),
                  );

                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.login),
              ),
              title: const Text(
                'Visitor Check-In',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Record visitor entry',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('कृपया पुन्हा Login करा.'),
                    ),
                  );
                  return;
                }

                FirebaseFirestore.instance
                    .collection('user_roles')
                    .doc(user.uid)
                    .get()
                    .then((roleDoc) {
                  if (!context.mounted) return;

                  final data = roleDoc.data();
                  final societyId = data?['societyid'] as String?;

                  if (!roleDoc.exists ||
                      data?['role'] != 'guard' ||
                      societyId == null ||
                      societyId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Guard Society माहिती मिळाली नाही.'),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisitorCheckInScreen(
                        societyId: societyId,
                      ),
                    ),
                  );
                }).catchError((error) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                    ),
                  );
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.logout),
              ),
              title: const Text(
                'Visitor Check-Out',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Record visitor exit',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('कृपया पुन्हा Login करा.'),
                    ),
                  );
                  return;
                }

                FirebaseFirestore.instance
                    .collection('user_roles')
                    .doc(user.uid)
                    .get()
                    .then((roleDoc) {
                  if (!context.mounted) return;

                  final data = roleDoc.data();
                  final societyId = data?['societyid'] as String?;

                  if (!roleDoc.exists ||
                      data?['role'] != 'guard' ||
                      societyId == null ||
                      societyId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Guard Society माहिती मिळाली नाही.'),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisitorCheckOutScreen(
                        societyId: societyId,
                      ),
                    ),
                  );
                }).catchError((error) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                    ),
                  );
                });
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.history),
              ),
              title: const Text(
                'Visitor History',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'View visitor entry and exit records',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('कृपया पुन्हा Login करा.'),
                    ),
                  );
                  return;
                }

                FirebaseFirestore.instance
                    .collection('user_roles')
                    .doc(user.uid)
                    .get()
                    .then((roleDoc) {
                  if (!context.mounted) return;

                  final data = roleDoc.data();
                  final societyId = data?['societyid'] as String?;

                  if (!roleDoc.exists ||
                      data?['role'] != 'guard' ||
                      societyId == null ||
                      societyId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Guard Society माहिती मिळाली नाही.'),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisitorHistoryScreen(
                        societyId: societyId,
                      ),
                    ),
                  );
                }).catchError((error) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $error')),
                  );
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.emergency),
              ),
              title: const Text(
                'Emergency / Helpdesk',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Report an emergency or issue',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('कृपया पुन्हा Login करा.'),
                    ),
                  );
                  return;
                }

                try {
                  final roleDoc = await FirebaseFirestore.instance
                      .collection('user_roles')
                      .doc(user.uid)
                      .get();

                  if (!context.mounted) return;

                  final data = roleDoc.data();
                  final societyId = data?['societyid'] as String?;
                  final guardId = (data?['guardid'] ?? '').toString();

                  if (!roleDoc.exists ||
                      data?['role'] != 'guard' ||
                      societyId == null ||
                      societyId.isEmpty ||
                      guardId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Guard माहिती मिळाली नाही.'),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuardHelpdeskScreen(
                        societyId: societyId,
                        guardId: guardId,
                      ),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
class VisitorCheckInScreen extends StatefulWidget {
  final String societyId;

  const VisitorCheckInScreen({
    super.key,
    required this.societyId,
  });

  @override
  State<VisitorCheckInScreen> createState() =>
      _VisitorCheckInScreenState();
}

class _VisitorCheckInScreenState
    extends State<VisitorCheckInScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final flatController = TextEditingController();
  final purposeController = TextEditingController();

  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    flatController.dispose();
    purposeController.dispose();
    super.dispose();
  }

  Future<void> checkInVisitor() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final flat = flatController.text.trim();
    final purpose = purposeController.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        flat.isEmpty ||
        purpose.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('सर्व माहिती भरा.'),
        ),
      );
      return;
    }

    if (phone.length != 10 ||
        !RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('योग्य 10 अंकी Mobile Number भरा.'),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('कृपया पुन्हा Login करा.');
      }

      final roleSnapshot = await FirebaseFirestore.instance
          .collection('user_roles')
          .doc(user.uid)
          .get();

      final roleData = roleSnapshot.data();

      if (!roleSnapshot.exists ||
          roleData?['role'] != 'guard' ||
          roleData?['societyid'] != widget.societyId) {
        throw Exception(
          'या Society साठी Guard ची परवानगी नाही.',
        );
      }

      final flatSnapshot = await FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('flats')
          .where('flatLabel', isEqualTo: flat)
          .limit(1)
          .get();

      if (flatSnapshot.docs.isEmpty) {
        throw Exception(
          'हा Flat सापडला नाही. योग्य Flat Number भरा.',
        );
      }

      final visitorRef = FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('visitors')
          .doc();

      await visitorRef.set({
        'visitorId': visitorRef.id,
        'visitorName': name,
        'phone': phone,
        'flatId': flatSnapshot.docs.first.id,
        'flatLabel': flat,
        'purpose': purpose,
        'guardId': roleData?['guardid'],
        'checkInAt': FieldValue.serverTimestamp(),
        'checkOutAt': null,
        'status': 'Inside',
        'approvalStatus': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      nameController.clear();
      phoneController.clear();
      flatController.clear();
      purposeController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visitor Check-In यशस्वी!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Check-In'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.how_to_reg,
            size: 70,
            color: Color(0xFF176B5B),
          ),
          const SizedBox(height: 16),
          const Text(
            'Register New Visitor',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Visitor Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: flatController,
            decoration: const InputDecoration(
              labelText: 'Flat Number (e.g. A-101)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.apartment),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: purposeController,
            decoration: const InputDecoration(
              labelText: 'Purpose of Visit',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: isSaving ? null : checkInVisitor,
            icon: const Icon(Icons.login),
            label: Text(
              isSaving ? 'Saving...' : 'Save Visitor Check-In',
            ),
          ),
        ],
      ),
    );
  }
}
class VisitorCheckOutScreen extends StatefulWidget {
  final String societyId;

  const VisitorCheckOutScreen({
    super.key,
    required this.societyId,
  });

  @override
  State<VisitorCheckOutScreen> createState() =>
      _VisitorCheckOutScreenState();
}

class _VisitorCheckOutScreenState
    extends State<VisitorCheckOutScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  bool _loading = false;
  bool _searching = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _visitors = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchVisitors() async {
    final searchText = _searchController.text.trim();

    if (searchText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visitor name किंवा flat number टाका.'),
        ),
      );
      return;
    }

    setState(() {
      _searching = true;
      _visitors = [];
    });

    try {
      final roleSnapshot = await FirebaseFirestore.instance
          .collection('user_roles')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      final roleData = roleSnapshot.data();

      if (roleData == null ||
          roleData['role'] != 'guard' ||
          roleData['societyid'] != widget.societyId) {
        throw Exception('तुम्हाला या Society साठी परवानगी नाही.');
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('visitors')
          .where('status', isEqualTo: 'Inside')
          .get();

      final query = searchText.toLowerCase();

      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final name = (data['visitorName'] ?? '')
            .toString()
            .toLowerCase();
        final flat = (data['flatLabel'] ?? '')
            .toString()
            .toLowerCase();
        final phone = (data['phone'] ?? '').toString();

        return name.contains(query) ||
            flat.contains(query) ||
            phone.contains(searchText);
      }).toList();

      if (!mounted) return;

      setState(() {
        _visitors = results;
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('या नावाचा किंवा Flat चा Inside visitor सापडला नाही.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _checkOut(
      QueryDocumentSnapshot<Map<String, dynamic>> visitor,
      ) async {
    final data = visitor.data();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Check-Out'),
        content: Text(
          '${data['visitorName'] ?? 'Visitor'} '
              '(${data['flatLabel'] ?? ''}) यांचा Check-Out करायचा आहे का?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Check-Out'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final roleSnapshot = await FirebaseFirestore.instance
          .collection('user_roles')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      final roleData = roleSnapshot.data();

      if (roleData == null ||
          roleData['role'] != 'guard' ||
          roleData['societyid'] != widget.societyId ||
          roleData['guardid'] != data['guardId']) {
        throw Exception(
          'फक्त संबंधित Society चा Guard हा visitor Check-Out करू शकतो.',
        );
      }

      await visitor.reference.update({
        'status': 'Checked Out',
        'checkOutAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _visitors.removeWhere((item) => item.id == visitor.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visitor Check-Out यशस्वी झाला!'),
          backgroundColor: Colors.green,
        ),
      );

      _searchController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check-Out failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Check-Out'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchVisitors(),
              decoration: InputDecoration(
                labelText: 'Visitor Name / Flat / Phone',
                hintText: 'उदा. Rahul, A-101 किंवा फोन नंबर',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                _searching || _loading ? null : _searchVisitors,
                icon: const Icon(Icons.search),
                label: Text(
                  _searching ? 'Searching...' : 'Search Visitors',
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _visitors.isEmpty
                  ? const Center(
                child: Text(
                  'Inside visitors शोधण्यासाठी वर नाव किंवा Flat Number टाका.',
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: _visitors.length,
                itemBuilder: (context, index) {
                  final visitor = _visitors[index];
                  final data = visitor.data();
                  final checkInAt = data['checkInAt'];

                  String checkInText = 'Not available';
                  if (checkInAt is Timestamp) {
                    checkInText = checkInAt
                        .toDate()
                        .toLocal()
                        .toString()
                        .substring(0, 16);
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            (data['visitorName'] ?? 'Visitor')
                                .toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Flat: ${data['flatLabel'] ?? '-'}',
                          ),
                          Text(
                            'Phone: ${data['phone'] ?? '-'}',
                          ),
                          Text(
                            'Purpose: ${data['purpose'] ?? '-'}',
                          ),
                          Text('Check-In: $checkInText'),
                          const SizedBox(height: 6),
                          Text(
                            'Approval: ${(data['approvalStatus'] ?? 'Pending').toString()}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: (data['approvalStatus'] ?? 'Pending') == 'Approved'
                                  ? Colors.green
                                  : (data['approvalStatus'] ?? 'Pending') == 'Rejected'
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _checkOut(visitor),
                              icon: const Icon(
                                Icons.logout,
                              ),
                              label: const Text(
                                'Check-Out Visitor',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class VisitorApprovalStatus extends StatelessWidget {
  final String approvalStatus;

  const VisitorApprovalStatus({
    super.key,
    required this.approvalStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = approvalStatus.trim().isEmpty
        ? 'Pending'
        : approvalStatus;

    final Color statusColor = status == 'Approved'
        ? Colors.green
        : status == 'Rejected'
        ? Colors.red
        : Colors.orange;

    return Row(
      children: [
        const Text(
          'Approval: ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          status,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
class VisitorHistoryScreen extends StatefulWidget {
  final String societyId;

  const VisitorHistoryScreen({
    super.key,
    required this.societyId,
  });

  @override
  State<VisitorHistoryScreen> createState() =>
      _VisitorHistoryScreenState();
}

class _VisitorHistoryScreenState
    extends State<VisitorHistoryScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) {
      return 'Not available';
    }

    final date = value.toDate().toLocal();

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final visitorsRef = FirebaseFirestore.instance
        .collection('societies')
        .doc(widget.societyId)
        .collection('visitors');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor History'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchText = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                labelText: 'Search Visitor / Flat / Phone',
                hintText: 'नाव, Flat Number किंवा फोन नंबर',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchText = '';
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: visitorsRef
                  .orderBy(
                'checkInAt',
                descending: true,
              )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Visitor History लोड होत नाही.\n'
                            '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final allVisitors =
                    snapshot.data?.docs ?? [];

                final filteredVisitors =
                allVisitors.where((visitor) {
                  final data = visitor.data();

                  final name =
                  (data['visitorName'] ?? '')
                      .toString()
                      .toLowerCase();

                  final flat =
                  (data['flatLabel'] ?? '')
                      .toString()
                      .toLowerCase();

                  final phone =
                  (data['phone'] ?? '')
                      .toString()
                      .toLowerCase();

                  return name.contains(_searchText) ||
                      flat.contains(_searchText) ||
                      phone.contains(_searchText);
                }).toList();

                if (filteredVisitors.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history,
                            size: 60,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchText.isEmpty
                                ? 'अजून Visitor History उपलब्ध नाही.'
                                : 'Visitor सापडला नाही.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16, 0, 16, 16,
                  ),
                  itemCount: filteredVisitors.length,
                  itemBuilder: (context, index) {
                    final visitor =
                    filteredVisitors[index];

                    final data = visitor.data();

                    final status =
                    (data['status'] ?? 'Unknown')
                        .toString();

                    final isInside = status == 'Inside';

                    return Card(
                      margin: const EdgeInsets.only(
                        bottom: 12,
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  backgroundColor:
                                  Color(0xFF176B5B),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (data['visitorName'] ??
                                            'Unknown Visitor')
                                            .toString(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Flat: ${data['flatLabel'] ?? '-'}',
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isInside
                                        ? Colors.orange.shade100
                                        : Colors.green.shade100,
                                    borderRadius:
                                    BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                      FontWeight.bold,
                                      color: isInside
                                          ? Colors.deepOrange
                                          : Colors.green.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _historyRow(
                              Icons.phone,
                              'Phone',
                              (data['phone'] ?? '-').toString(),
                            ),
                            _historyRow(
                              Icons.info_outline,
                              'Purpose',
                              (data['purpose'] ?? '-').toString(),
                            ),
                            _historyRow(
                              Icons.login,
                              'Check-In',
                              _formatTimestamp(
                                data['checkInAt'],
                              ),
                            ),
                            _historyRow(
                              Icons.logout,
                              'Check-Out',
                              data['checkOutAt'] == null
                                  ? 'Not checked out yet'
                                  : _formatTimestamp(
                                data['checkOutAt'],
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

  Widget _historyRow(
      IconData icon,
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: const Color(0xFF176B5B),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 85,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
class GuardProfileScreen extends StatefulWidget {
  final String societyId;
  final String guardId;
  final String email;

  const GuardProfileScreen({
    super.key,
    required this.societyId,
    required this.guardId,
    required this.email,
  });

  @override
  State<GuardProfileScreen> createState() =>
      _GuardProfileScreenState();
}

class _GuardProfileScreenState extends State<GuardProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _guardData = {};
  Map<String, dynamic> _societyData = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      final societyRef =
      db.collection('societies').doc(widget.societyId);

      final results = await Future.wait([
        societyRef.get(),
        if (widget.guardId.isNotEmpty)
          societyRef.collection('guards').doc(widget.guardId).get(),
      ]);

      final societySnapshot =
      results[0] as DocumentSnapshot<Map<String, dynamic>>;

      Map<String, dynamic> guardData = {};

      if (widget.guardId.isNotEmpty && results.length > 1) {
        final guardSnapshot =
        results[1] as DocumentSnapshot<Map<String, dynamic>>;

        if (guardSnapshot.exists) {
          guardData = guardSnapshot.data() ?? {};
        }
      }

      if (!mounted) return;

      setState(() {
        _societyData = societySnapshot.data() ?? {};
        _guardData = guardData;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';

    if (value is Timestamp) {
      final date = value.toDate().toLocal();

      String twoDigits(int n) => n.toString().padLeft(2, '0');

      return '${twoDigits(date.day)}/'
          '${twoDigits(date.month)}/'
          '${date.year} '
          '${twoDigits(date.hour)}:'
          '${twoDigits(date.minute)}';
    }

    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    if (value is Map || value is List) {
      return value.toString();
    }

    return value.toString();
  }

  String _label(String key) {
    final labels = <String, String>{
      'name': 'Name',
      'fullName': 'Full Name',
      'guardName': 'Guard Name',
      'email': 'Email',
      'phone': 'Phone Number',
      'mobile': 'Mobile Number',
      'address': 'Address',
      'guardId': 'Guard ID',
      'guardid': 'Guard ID',
      'societyId': 'Society ID',
      'societyid': 'Society ID',
      'role': 'Role',
      'status': 'Account Status',
      'createdAt': 'Registered On',
      'joiningDate': 'Joining Date',
      'emergencyContact': 'Emergency Contact',
      'societyName': 'Society Name',
      'flatCount': 'Total Flats',
    };

    if (labels.containsKey(key)) return labels[key]!;

    return key
        .replaceAllMapped(
      RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
    )
        .replaceFirstMapped(
      RegExp(r'^[a-z]'),
          (match) => match.group(0)!.toUpperCase(),
    );
  }

  bool _isSensitiveField(String key) {
    final lower = key.toLowerCase();

    return lower.contains('password') ||
        lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('invitationcode') ||
        lower.contains('otp');
  }

  Widget _infoRow(
      IconData icon,
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF176B5B),
            size: 22,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 18,
        bottom: 8,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        _guardData['name'] ??
            _guardData['fullName'] ??
            _guardData['guardName'] ??
            'Security Guard';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh Profile',
            onPressed: _loading ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 52,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Profile लोड होऊ शकले नाही.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor:
                      Color(0xFF176B5B),
                      child: Icon(
                        Icons.security,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Security Guard',
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _sectionTitle('Personal Information'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _infoRow(
                      Icons.email_outlined,
                      'Email',
                      widget.email,
                    ),
                    _infoRow(
                      Icons.badge_outlined,
                      'Guard ID',
                      widget.guardId.isEmpty
                          ? '-'
                          : widget.guardId,
                    ),
                    ..._guardData.entries
                        .where((entry) =>
                    !_isSensitiveField(entry.key) &&
                        ![
                          'name',
                          'fullName',
                          'guardName',
                          'email',
                          'guardId',
                          'guardid',
                          'societyId',
                          'societyid',
                          'password',
                        ].contains(entry.key))
                        .map(
                          (entry) => _infoRow(
                        Icons.info_outline,
                        _label(entry.key),
                        _formatValue(entry.value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _sectionTitle('Society Information'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _infoRow(
                      Icons.apartment,
                      'Society ID',
                      widget.societyId,
                    ),
                    _infoRow(
                      Icons.business,
                      'Society Name',
                      _formatValue(
                        _societyData['societyName'] ??
                            _societyData['name'],
                      ),
                    ),
                    _infoRow(
                      Icons.location_on_outlined,
                      'Address',
                      _formatValue(
                        _societyData['address'],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
class GuardHelpdeskScreen extends StatefulWidget {
  final String societyId;
  final String guardId;

  const GuardHelpdeskScreen({
    super.key,
    required this.societyId,
    required this.guardId,
  });

  @override
  State<GuardHelpdeskScreen> createState() =>
      _GuardHelpdeskScreenState();
}

class _GuardHelpdeskScreenState
    extends State<GuardHelpdeskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();

  String _reportType = 'Helpdesk';
  String _category = 'Security';
  bool _saving = false;

  final List<String> _categories = [
    'Security',
    'Fire',
    'Medical',
    'Maintenance',
    'Electrical',
    'Other',
  ];

  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('helpdesk_reports');

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया पुन्हा Login करा.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Recheck the signed-in guard's role and society.
      final roleDoc = await FirebaseFirestore.instance
          .collection('user_roles')
          .doc(user.uid)
          .get();

      final roleData = roleDoc.data();

      if (!roleDoc.exists ||
          roleData?['role'] != 'guard' ||
          roleData?['societyid'] != widget.societyId ||
          roleData?['guardid'] != widget.guardId) {
        throw Exception(
          'तुम्हाला हा रिपोर्ट नोंदवण्याची परवानगी नाही.',
        );
      }

      await _reportsRef.add({
        'guardId': widget.guardId,
        'reportType': _reportType,
        'category': _category,
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'status': 'Open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _locationController.clear();
      _descriptionController.clear();
      _contactController.clear();

      setState(() {
        _reportType = 'Helpdesk';
        _category = 'Security';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('रिपोर्ट यशस्वीपणे सेव्ह झाला!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('रिपोर्ट सेव्ह झाला नाही: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return 'वेळ उपलब्ध नाही';

    final date = value.toDate().toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      default:
        return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmergency = _reportType == 'Emergency';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency / Helpdesk'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'नवीन रिपोर्ट नोंदवा',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Report Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: _reportType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Helpdesk',
                          child: Text('Helpdesk / सामान्य समस्या'),
                        ),
                        DropdownMenuItem(
                          value: 'Emergency',
                          child: Text('Emergency / आपत्कालीन घटना'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                        if (value != null) {
                          setState(() {
                            _reportType = value;
                          });
                        }
                      },
                    ),

                    if (isEmergency) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'तातडीचा धोका असल्यास अॅपमधील रिपोर्टवरच अवलंबून राहू नका. आवश्यक आपत्कालीन सेवांशी थेट संपर्क साधा.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'घटनेचे ठिकाण',
                        hintText: 'उदा. Gate, Lift, Flat A-101',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'ठिकाण लिहा.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'घटनेचे वर्णन',
                        hintText: 'काय घडले ते लिहा...',
                        prefixIcon: Icon(Icons.description_outlined),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'घटनेचे वर्णन लिहा.';
                        }
                        if (value.trim().length < 5) {
                          return 'कृपया थोडे अधिक वर्णन लिहा.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'संपर्क क्रमांक (पर्यायी)',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _submitReport,
                        icon: _saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.send),
                        label: Text(
                          _saving ? 'Saving...' : 'Submit Report',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          backgroundColor: isEmergency
                              ? Colors.red
                              : const Color(0xFF176B5B),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'माझे मागील रिपोर्ट',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _reportsRef
                .where('guardId', isEqualTo: widget.guardId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'रिपोर्ट लोड झाले नाहीत.\n${snapshot.error}',
                    ),
                  ),
                );
              }

              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final reports = [
                ...?snapshot.data?.docs,
              ];

              reports.sort((a, b) {
                final aTime = a.data()['createdAt'];
                final bTime = b.data()['createdAt'];

                final aDate = aTime is Timestamp
                    ? aTime.toDate()
                    : DateTime(2000);
                final bDate = bTime is Timestamp
                    ? bTime.toDate()
                    : DateTime(2000);

                return bDate.compareTo(aDate);
              });

              if (reports.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'अजून कोणताही रिपोर्ट नोंदवलेला नाही.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Column(
                children: reports.map((report) {
                  final data = report.data();
                  final status =
                  (data['status'] ?? 'Open').toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                        data['reportType'] == 'Emergency'
                            ? Colors.red.shade100
                            : Colors.blue.shade100,
                        child: Icon(
                          data['reportType'] == 'Emergency'
                              ? Icons.warning_amber
                              : Icons.support_agent,
                          color: data['reportType'] == 'Emergency'
                              ? Colors.red
                              : Colors.blue,
                        ),
                      ),
                      title: Text(
                        '${data['category'] ?? 'Other'} • '
                            '${data['reportType'] ?? 'Helpdesk'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ठिकाण: ${data['location'] ?? '-'}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (data['description'] ?? '').toString(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'नोंदवले: ${_formatTime(data['createdAt'])}',
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Status: $status',
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      isThreeLine: true,
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