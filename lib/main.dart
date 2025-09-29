import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:irs_notice_tracker/models/poa_record.dart';
import 'package:irs_notice_tracker/screens/poa_master_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/client.dart';
import 'models/notice.dart';
import 'models/call.dart';
import 'models/poa_record.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/notice_tracker_screen.dart';
import 'screens/billing_summary_screen.dart';
import 'screens/response_log_screen.dart';
import 'screens/debug_escalation_screen.dart';
import 'screens/print_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Test Firestore connection
  try {
    await FirebaseFirestore.instance.collection('test').doc('test').set({
      'test': 'hello world',
      'timestamp': FieldValue.serverTimestamp(),
    });
    print("✅ Firestore connection successful!");
  } catch (e) {
    print("❌ Firestore connection failed: $e");
  }
  await Hive.initFlutter();

  Hive.registerAdapter(ClientAdapter());
  Hive.registerAdapter(NoticeAdapter());
  Hive.registerAdapter(CallAdapter());
  Hive.registerAdapter(PoaRecordAdapter());

  await Hive.openBox<Client>('clients');
  await Hive.openBox<Notice>('notices');
  await Hive.openBox<Call>('calls');
  await Hive.openBox<PoaRecord>('poaRecords');

  runApp(const IRSNoticeTrackerApp());
}

class IRSNoticeTrackerApp extends StatelessWidget {
  const IRSNoticeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IRS Notice Tracker',
      theme: ThemeData(
          primarySwatch: Colors.blue,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.blue,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
          ),
      ),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    ClientsScreen(),
    NoticeTrackerScreen(),
    BillingSummaryScreen(),
    PoaMasterScreen(),
    ResponseLogScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("IRS Notice Tracker"),
        actions: [
          if (_selectedIndex == 0) // Only show on Dashboard tab
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: "Print Dashboard",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrintDashboardScreen(),
                  ),
                );
              },
            ),
          // IconButton(
          //   icon: const Icon(Icons.bug_report),
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //      MaterialPageRoute(builder: (_) => const DebugEscalationScreen()),
          //     );
          //   },
          // ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // ✅ ensures solid background color
        backgroundColor: Colors.blue,        // ✅ solid blue bar
        selectedItemColor: Colors.white,     // ✅ white for active
        unselectedItemColor: Colors.white70, // ✅ lighter white for inactive
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "Clients",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: "Notices",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: "Billing",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: "POA Master",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: "Response Log",
          ),
        ],
      ),
    );
  }
}
