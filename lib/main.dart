import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/client.dart';
import 'models/call.dart';
import 'models/notice.dart';
import 'screens/dashboard_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/notice_tracker_screen.dart';
import 'screens/billing_summary_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(ClientAdapter());
  Hive.registerAdapter(CallAdapter());
  Hive.registerAdapter(NoticeAdapter());

  try {
    await Hive.openBox<Client>('clients');
    await Hive.openBox<Call>('calls');
    await Hive.openBox<Notice>('notices');
  } catch (_) {
    await Hive.deleteBoxFromDisk('clients');
    await Hive.deleteBoxFromDisk('calls');
    await Hive.deleteBoxFromDisk('notices');

    await Hive.openBox<Client>('clients');
    await Hive.openBox<Call>('calls');
    await Hive.openBox<Notice>('notices');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  String? _noticeFilter;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleFilterSelect(String status) {
    setState(() {
      _noticeFilter = status;
      _selectedIndex = 2; // jump to Notices
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(onFilterSelect: _handleFilterSelect),
      const ClientsScreen(),
      NoticeTrackerScreen(filterStatus: _noticeFilter),
      const BillingSummaryScreen(),
    ];

    return MaterialApp(
      title: 'IRS Notice Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          return Scaffold(
            appBar: AppBar(
              title: const Text("IRS Notice Tracker"),
              centerTitle: true,
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            body: Row(
              children: [
                if (isWide)
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onItemTapped,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard),
                        label: Text("Dashboard"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.people),
                        label: Text("Clients"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.article),
                        label: Text("Notices"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.attach_money),
                        label: Text("Billing"),
                      ),
                    ],
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: screens[_selectedIndex],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: isWide
                ? null
                : BottomNavigationBar(
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
                  icon: Icon(Icons.article),
                  label: "Notices",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.attach_money),
                  label: "Billing",
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
