import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/statuses.dart';
import '../../models/event_task.dart';
import '../../theme.dart';
import 'task_service.dart';

class EventTasksPage extends StatelessWidget {
  final String eventId;
  final String eventTitle;

  const EventTasksPage({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('tasks')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(eventTitle)),
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
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No tasks for this event',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final tasks = snapshot.data!.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] != TaskStatus.cancelled;
              })
              .map((doc) => EventTask.fromDoc(eventId, doc))
              .toList();

          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks available'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) =>
                _ClaimableTaskCard(task: tasks[index]),
          );
        },
      ),
    );
  }
}

/// Task card where ticking the checkbox = claiming the task.
/// Once claimed, only the claimer sees it checked. Others see "Claimed by X".
class _ClaimableTaskCard extends StatelessWidget {
  final EventTask task;
  const _ClaimableTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final taskService = TaskService();

    final String employeeName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email ?? 'Employee');

    // Determine the state for this user
    final bool isOpen = task.status == TaskStatus.open && task.claimedBy == null;
    final bool isClaimedByMe = task.claimedBy == user.uid;
    final bool isClaimedByOther =
        task.claimedBy != null && task.claimedBy != user.uid;
    final bool isDone = task.status == TaskStatus.done || task.completed;

    // Checkbox value: checked if claimed by me or done
    final bool isChecked = isClaimedByMe || isDone;

    // Can this user interact with the checkbox?
    final bool canTick = isOpen || isClaimedByMe;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox: tick to claim, untick to unclaim
              Checkbox(
                value: isChecked,
                onChanged: canTick
                    ? (value) async {
                        try {
                          if (value == true && isOpen) {
                            // Tick = claim
                            await taskService.claimTask(
                              eventId: task.eventId,
                              taskId: task.id,
                              employeeName: employeeName,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Task claimed! Check My Tasks.')),
                              );
                            }
                          }
                          // If already claimed by me, do nothing on untick
                          // (they manage completion from My Tasks)
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      }
                    : null,
                activeColor: AppTheme.softGreenDark,
              ),

              // Task info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? Colors.grey : null,
                      ),
                    ),
                    if (task.description.isNotEmpty)
                      Text(
                        task.description,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    const SizedBox(height: 4),

                    // Status label
                    if (isOpen)
                      Text('Available — tick to claim',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500)),
                    if (isClaimedByMe && !isDone)
                      Text('Claimed by you',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500)),
                    if (isClaimedByOther && !isDone)
                      Text(
                          'Claimed by ${task.claimedByName ?? 'another employee'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic)),
                    if (isDone)
                      Text(
                          'Completed${task.completedByName != null ? ' by ${task.completedByName}' : ''}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
