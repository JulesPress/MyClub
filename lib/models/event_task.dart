import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/statuses.dart';

class EventTask {
  final String id;
  final String eventId;
  final String title;
  final String description;
  final String taskType;
  final String? assignedTo;
  final String? assignedToName;
  final String? claimedBy;
  final String? claimedByName;
  final bool completed;
  final String? completedBy;
  final String? completedByName;
  final String status;
  final Timestamp? dueAt;

  EventTask({
    required this.id,
    required this.eventId,
    required this.title,
    required this.description,
    required this.taskType,
    required this.assignedTo,
    required this.assignedToName,
    required this.claimedBy,
    required this.claimedByName,
    required this.completed,
    required this.completedBy,
    required this.completedByName,
    required this.status,
    required this.dueAt,
  });

  factory EventTask.fromDoc(String eventId, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return EventTask(
      id: doc.id,
      eventId: eventId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      taskType: data['taskType'] ?? TaskType.general,
      assignedTo: data['assignedTo'],
      assignedToName: data['assignedToName'],
      claimedBy: data['claimedBy'],
      claimedByName: data['claimedByName'],
      completed: data['completed'] ?? false,
      completedBy: data['completedBy'],
      completedByName: data['completedByName'],
      status: data['status'] ?? TaskStatus.open,
      dueAt: data['dueAt'],
    );
  }

  bool isPersonalFor(String uid) {
    return taskType == TaskType.personal && assignedTo == uid;
  }

  bool isClaimable() {
    return taskType == TaskType.general && claimedBy == null && status == TaskStatus.open;
  }

  bool isClaimedBy(String uid) {
    return taskType == TaskType.general && claimedBy == uid;
  }

  bool get isDone => status == TaskStatus.done || completed;
}