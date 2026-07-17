import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/statuses.dart';
import '../../models/event_task.dart';
import 'task_service.dart';

class MyTasksPage extends StatelessWidget {
  const MyTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    // No orderBy to avoid requiring a Firestore composite index
    final stream = FirebaseFirestore.instance
        .collectionGroup('tasks')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyState();
          }

          // Only show tasks claimed by or assigned to THIS user
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'];

            if (status == TaskStatus.cancelled) return false;

            // Personal tasks assigned to me
            if (data['taskType'] == TaskType.personal &&
                data['assignedTo'] == user.uid) {
              return true;
            }

            // General tasks I have claimed
            if (data['taskType'] == TaskType.general &&
                data['claimedBy'] == user.uid) {
              return true;
            }

            return false;
          }).toList();

          if (docs.isEmpty) {
            return _emptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final parentEventRef = doc.reference.parent.parent;
              if (parentEventRef == null) return const SizedBox.shrink();

              final eventId = parentEventRef.id;
              final task = EventTask.fromDoc(eventId, doc);

              return _MyTaskCard(task: task);
            },
          );
        },
      ),
    );
  }

  static Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('No tasks assigned to you yet',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          SizedBox(height: 8),
          Text('Claim tasks from the Calendar',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─── Task card for My Tasks (shows completion toggle) ───────────────────────

class _MyTaskCard extends StatelessWidget {
  final EventTask task;
  const _MyTaskCard({required this.task});

  Color _statusColor(String status) {
    switch (status) {
      case TaskStatus.done:
        return Colors.green;
      case TaskStatus.claimed:
        return Colors.orange;
      case TaskStatus.pending:
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.claimed:
        return 'In progress';
      case TaskStatus.done:
        return 'Done';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final taskService = TaskService();

    final String employeeName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email ?? 'Employee');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(task.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(task.status),
                    style: TextStyle(
                      color: _statusColor(task.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(task.description,
                  style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 12),

            // Completion toggle
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                task.completed ? 'Completed' : 'Mark as completed',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              value: task.completed,
              onChanged: (value) async {
                try {
                  if (value == true) {
                    await taskService.completeTask(
                      eventId: task.eventId,
                      taskId: task.id,
                      employeeName: employeeName,
                    );
                  } else {
                    await taskService.uncompleteTask(
                      eventId: task.eventId,
                      taskId: task.id,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}