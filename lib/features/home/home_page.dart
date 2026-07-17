import 'package:flutter/material.dart';
import '../auth/auth_service.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _authService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = _profile?['fullName'] ?? 'User';
    final role = _profile?['role'] ?? 'employee';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PadelSquare Staff'),
        actions: [
          IconButton(
            onPressed: () async => _authService.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $name',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Role: $role'),
            const SizedBox(height: 24),
            if (role == 'admin') const Text('Admin dashboard tools here'),
            if (role == 'manager') const Text('Manager tools here'),
            if (role == 'employee') const Text('Employee timetable/events here'),
          ],
        ),
      ),
    );
  }
}