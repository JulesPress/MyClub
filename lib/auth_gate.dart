import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'features/auth/consent_dialog.dart';
import 'features/auth/login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // The user exists in Auth but their Firestore document is gone.
              // We forget them completely by deleting their Auth account and signing out.
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final currUser = FirebaseAuth.instance.currentUser;
                if (currUser != null) {
                  try {
                    await currUser.delete();
                  } catch (_) {
                    await FirebaseAuth.instance.signOut();
                  }
                }
              });

              return const Scaffold(
                body: Center(
                  child: Text('Account deactivated. Returning to login...'),
                ),
              );
            }

            final data = userSnapshot.data!.data()!;
            final role = data['role'] ?? 'employee';
            final fullName = data['fullName'] ?? '';
            final consentAccepted = data['consentAccepted'] == true;

            if (!consentAccepted) {
              return _ConsentGate(
                role: role,
                fullName: fullName,
              );
            }

            return DashboardPage(
              role: role,
              fullName: fullName,
            );
          },
        );
      },
    );
  }
}

/// Intermediate widget that shows the consent dialog before allowing
/// the user to proceed to the dashboard.
class _ConsentGate extends StatefulWidget {
  final String role;
  final String fullName;

  const _ConsentGate({required this.role, required this.fullName});

  @override
  State<_ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<_ConsentGate> {
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    // Show consent dialog after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showConsent();
    });
  }

  Future<void> _showConsent() async {
    final accepted = await ConsentDialog.show(context);
    if (mounted && accepted) {
      setState(() => _accepted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) {
      return DashboardPage(
        role: widget.role,
        fullName: widget.fullName,
      );
    }

    // Show an empty dark scaffold while the dialog is showing
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}