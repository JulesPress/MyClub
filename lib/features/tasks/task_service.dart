import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/statuses.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> claimTask({
    required String eventId,
    required String taskId,
    required String employeeName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final taskRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('tasks')
        .doc(taskId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(taskRef);

      if (!snapshot.exists) {
        throw Exception('Task not found');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final claimedBy = data['claimedBy'];
      final taskType = data['taskType'];
      final status = data['status'];

      if (taskType != TaskType.general) {
        throw Exception('Only general tasks can be claimed');
      }

      if (claimedBy != null || status != TaskStatus.open) {
        throw Exception('Task already claimed or unavailable');
      }

      transaction.update(taskRef, {
        'claimedBy': user.uid,
        'claimedByName': employeeName,
        'claimedAt': FieldValue.serverTimestamp(),
        'status': TaskStatus.claimed,
      });
    });
  }

  Future<void> completeTask({
    required String eventId,
    required String taskId,
    required String employeeName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final taskRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('tasks')
        .doc(taskId);

    final snapshot = await taskRef.get();
    final data = snapshot.data();
    if (data == null) throw Exception('Task not found');

    final taskType = data['taskType'];
    final assignedTo = data['assignedTo'];
    final claimedBy = data['claimedBy'];
    final status = data['status'];

    final canComplete =
        (taskType == TaskType.personal &&
            assignedTo == user.uid &&
            status == TaskStatus.pending) ||
        (taskType == TaskType.general &&
            claimedBy == user.uid &&
            status == TaskStatus.claimed);

    if (!canComplete) {
      throw Exception('You cannot complete this task');
    }

    await taskRef.update({
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
      'completedBy': user.uid,
      'completedByName': employeeName,
      'status': TaskStatus.done,
    });

    // Check tasks status to count totalTasks and completedTasks
    final tasksSnapshot = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('tasks')
        .get();

    int totalCount = 0;
    int completedCount = 0;

    for (final doc in tasksSnapshot.docs) {
      final taskData = doc.data();
      final isCancelled = taskData['status'] == TaskStatus.cancelled;
      if (isCancelled) continue;

      totalCount++;

      final isDone = doc.id == taskId ||
          taskData['status'] == TaskStatus.done ||
          taskData['completed'] == true;
      if (isDone) {
        completedCount++;
      }
    }

    final allCompleted = totalCount > 0 && completedCount == totalCount;

    await _firestore.collection('events').doc(eventId).update({
      'totalTasks': totalCount,
      'completedTasks': completedCount,
      'status': allCompleted ? EventStatus.completed : EventStatus.scheduled,
    });
  }

  Future<void> uncompleteTask({
    required String eventId,
    required String taskId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final taskRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('tasks')
        .doc(taskId);

    final snapshot = await taskRef.get();
    final data = snapshot.data();
    if (data == null) throw Exception('Task not found');

    final taskType = data['taskType'];
    final assignedTo = data['assignedTo'];
    final claimedBy = data['claimedBy'];

    final canEdit =
        (taskType == TaskType.personal && assignedTo == user.uid) ||
        (taskType == TaskType.general && claimedBy == user.uid);

    if (!canEdit) {
      throw Exception('You cannot edit this task');
    }

    await taskRef.update({
      'completed': false,
      'completedAt': null,
      'completedBy': null,
      'completedByName': null,
      'status': taskType == TaskType.general
          ? TaskStatus.claimed
          : TaskStatus.pending,
    });

    // Recalculate tasks and update parent event counts
    final tasksSnapshot = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('tasks')
        .get();

    int totalCount = 0;
    int completedCount = 0;

    for (final doc in tasksSnapshot.docs) {
      final taskData = doc.data();
      final isCancelled = taskData['status'] == TaskStatus.cancelled;
      if (isCancelled) continue;

      totalCount++;

      // Current task taskId is being uncompleted, so do not count it
      if (doc.id == taskId) continue;

      final isDone = taskData['status'] == TaskStatus.done ||
          taskData['completed'] == true;
      if (isDone) {
        completedCount++;
      }
    }

    await _firestore.collection('events').doc(eventId).update({
      'totalTasks': totalCount,
      'completedTasks': completedCount,
      'status': EventStatus.scheduled,
    });
  }
}