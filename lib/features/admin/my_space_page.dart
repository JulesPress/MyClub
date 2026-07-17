import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/statuses.dart';
import '../../theme.dart';
import '../home/event_detail_page.dart';

class MySpacePage extends StatelessWidget {
  const MySpacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('events')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('My Space')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEventPage()),
          );
        },
        backgroundColor: AppTheme.softGreenDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_note, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No events yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Tap + to create your first event',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // Sort by date client-side
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = (aData['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final bDate = (bData['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return aDate.compareTo(bDate);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Untitled';
              final description = data['description'] ?? '';
              final status = data['status'] ?? 'scheduled';
              final timestamp = data['date'] as Timestamp?;
              final date = timestamp?.toDate();

              final dateStr = date != null
                  ? '${date.day}/${date.month}/${date.year}'
                  : 'No date';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EventDetailPage(
                          eventId: doc.id,
                          role: 'manager',
                        ),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: status == EventStatus.cancelled
                        ? Colors.red.shade100
                        : AppTheme.softYellow,
                    child: Icon(
                      status == EventStatus.cancelled
                          ? Icons.cancel
                          : Icons.event,
                      color: status == EventStatus.cancelled
                          ? Colors.red
                          : AppTheme.textDark,
                    ),
                  ),
                  title: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateStr),
                      if (description.isNotEmpty)
                        Text(description,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete event?'),
                            content: const Text(
                                'This will permanently remove this event and all its tasks.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete',
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _deleteEventWithTasks(doc.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Event deleted')),
                            );
                          }
                        }
                      } else if (value == 'add_task') {
                        if (context.mounted) {
                          _showAddTaskDialog(context, doc.id);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'add_task',
                        child: ListTile(
                          leading: Icon(Icons.add_task),
                          title: Text('Add Task'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title:
                              Text('Delete', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
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
    );
  }

  /// Deletes the event document AND all tasks in its subcollection.
  Future<void> _deleteEventWithTasks(String eventId) async {
    final firestore = FirebaseFirestore.instance;
    final eventRef = firestore.collection('events').doc(eventId);

    // Delete all tasks in the subcollection first
    final tasksSnapshot = await eventRef.collection('tasks').get();
    final batch = firestore.batch();
    for (final taskDoc in tasksSnapshot.docs) {
      batch.delete(taskDoc.reference);
    }
    // Delete the event document itself
    batch.delete(eventRef);
    await batch.commit();
  }

  /// Shows a dialog to create a task with title, description,
  /// and an employee dropdown to assign it.
  void _showAddTaskDialog(BuildContext context, String eventId) {
    showDialog(
      context: context,
      builder: (ctx) => _AddTaskDialog(eventId: eventId),
    );
  }
}

// ─── Add Task Dialog (with employee dropdown) ───────────────────────────────

class _AddTaskDialog extends StatefulWidget {
  final String eventId;
  const _AddTaskDialog({required this.eventId});

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedEmployeeUid;
  String? _selectedEmployeeName;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final taskRef = FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('tasks')
          .doc();
      final eventRef = FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId);

      batch.set(taskRef, {
        'title': title,
        'description': _descController.text.trim(),
        'taskType': _selectedEmployeeUid != null ? 'personal' : 'general',
        'assignedTo': _selectedEmployeeUid,
        'assignedToName': _selectedEmployeeName,
        'claimedBy': null,
        'claimedByName': null,
        'completed': false,
        'completedBy': null,
        'completedByName': null,
        'status': _selectedEmployeeUid != null ? 'pending' : 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'dueAt': null,
      });

      // Update event status to scheduled (red color) and increment totalTasks
      batch.update(eventRef, {
        'status': EventStatus.scheduled,
        'totalTasks': FieldValue.increment(1),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedEmployeeName != null
                ? 'Task assigned to $_selectedEmployeeName'
                : 'Task created'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Employee dropdown
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                final employees = snapshot.data!.docs
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['active'] != false;
                    })
                    .toList();

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Assign to employee',
                    hintText: 'Select an employee',
                  ),
                  initialValue: _selectedEmployeeUid,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Unassigned (claimable)',
                          style: TextStyle(fontStyle: FontStyle.italic)),
                    ),
                    ...employees.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['fullName'] ?? data['email'] ?? doc.id;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(name),
                      );
                    }),
                  ],
                  onChanged: (uid) {
                    setState(() {
                      _selectedEmployeeUid = uid;
                      if (uid != null) {
                        final doc = employees.firstWhere((d) => d.id == uid);
                        final data = doc.data() as Map<String, dynamic>;
                        _selectedEmployeeName =
                            data['fullName'] ?? data['email'] ?? uid;
                      } else {
                        _selectedEmployeeName = null;
                      }
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.softGreenDark,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

// ─── Add Event Page ─────────────────────────────────────────────────────────

enum RepeatMode { none, weekly, monthly }

class AddEventPage extends StatefulWidget {
  const AddEventPage({super.key});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _canvaController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  RepeatMode _repeatMode = RepeatMode.none;
  int _repeatCount = 4; // number of occurrences
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _canvaController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  List<DateTime> _buildDates() {
    final dates = <DateTime>[_selectedDate];

    if (_repeatMode == RepeatMode.weekly) {
      for (int i = 1; i < _repeatCount; i++) {
        dates.add(_selectedDate.add(Duration(days: 7 * i)));
      }
    } else if (_repeatMode == RepeatMode.monthly) {
      for (int i = 1; i < _repeatCount; i++) {
        dates.add(DateTime(
          _selectedDate.year,
          _selectedDate.month + i,
          _selectedDate.day,
        ));
      }
    }

    return dates;
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final dates = _buildDates();
      final batch = FirebaseFirestore.instance.batch();

      for (final date in dates) {
        final ref = FirebaseFirestore.instance.collection('events').doc();
         batch.set(ref, {
          'title': title,
          'description': _descController.text.trim(),
          'canvaLink': _canvaController.text.trim(),
          'date': Timestamp.fromDate(date),
          'status': EventStatus.completed,
          'totalTasks': 0,
          'completedTasks': 0,
          'createdBy': user?.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dates.length == 1
                ? 'Event created'
                : '${dates.length} events created'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    final dates = _buildDates();

    return Scaffold(
      appBar: AppBar(title: const Text('New Event')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Title
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Event title',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Canva Template Link
          TextField(
            controller: _canvaController,
            decoration: InputDecoration(
              labelText: 'Canva Template Link',
              hintText: 'https://canva.com/...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),

          // Date picker
          const Text('Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 12),
                  Text(dateStr, style: const TextStyle(fontSize: 16)),
                  const Spacer(),
                  Text('Tap to change',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Repetition
          const Text('Repetition',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<RepeatMode>(
            segments: const [
              ButtonSegment(value: RepeatMode.none, label: Text('None')),
              ButtonSegment(value: RepeatMode.weekly, label: Text('Weekly')),
              ButtonSegment(value: RepeatMode.monthly, label: Text('Monthly')),
            ],
            selected: {_repeatMode},
            onSelectionChanged: (val) {
              setState(() => _repeatMode = val.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.softGreenDark;
                }
                return null;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return null;
              }),
            ),
          ),

          if (_repeatMode != RepeatMode.none) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  _repeatMode == RepeatMode.weekly
                      ? 'Repeat for'
                      : 'Repeat for',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 70,
                  child: DropdownButtonFormField<int>(
                    initialValue: _repeatCount,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: List.generate(12, (i) => i + 2)
                        .map((n) => DropdownMenuItem(
                            value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _repeatCount = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _repeatMode == RepeatMode.weekly ? 'weeks' : 'months',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This will create ${dates.length} event${dates.length > 1 ? 's' : ''}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],

          const SizedBox(height: 32),

          // Submit
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.softGreenDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      dates.length == 1
                          ? 'Create Event'
                          : 'Create ${dates.length} Events',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
