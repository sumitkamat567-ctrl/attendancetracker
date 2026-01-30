import 'package:flutter/material.dart';
import '../home/home_page.dart';
import '../status/status_page.dart';
import '../timetable/timetable_page.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int index = 0;

  final pages = const [
    HomePage(),
    StatusPage(),
    TimetablePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: "Status"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Timetable"),
        ],
      ),
    );
  }
}
