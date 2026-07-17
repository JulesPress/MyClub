import 'dart:async';

import 'package:calendar_view/calendar_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'core/constants/statuses.dart';
import 'features/admin/my_space_page.dart';
import 'features/admin/add_news_page.dart';
import 'features/home/event_detail_page.dart';
import 'features/tasks/my_tasks_page.dart';
import 'features/tasks/task_service.dart';
import 'models/event_task.dart';
import 'theme.dart';

class DashboardPage extends StatefulWidget {
  final String role;
  final String fullName;

  const DashboardPage({
    super.key,
    required this.role,
    required this.fullName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class DashboardTabItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const DashboardTabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
}

class _DashboardPageState extends State<DashboardPage> {
  int currentIndex = 0;

  List<DashboardTabItem> get pages {
    final bool isAdmin =
        widget.role == 'manager' || widget.role == 'admin';

    return [
      DashboardTabItem(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        page: HomeTab(fullName: widget.fullName, role: widget.role),
      ),
      DashboardTabItem(
        label: 'Calendar',
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        page: CalendarTab(role: widget.role),
      ),
      if (isAdmin)
        const DashboardTabItem(
          label: 'My Space',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          page: MySpacePage(),
        )
      else
        const DashboardTabItem(
          label: 'My Tasks',
          icon: Icons.task_alt_outlined,
          selectedIcon: Icons.task_alt,
          page: MyTasksPage(),
        ),
      DashboardTabItem(
        label: 'News',
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign,
        page: AnnouncementsTab(role: widget.role),
      ),
      DashboardTabItem(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: ProfileTab(fullName: widget.fullName, role: widget.role),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = pages;

    if (currentIndex >= items.length) {
      currentIndex = 0;
    }

    return Scaffold(
      body: items[currentIndex].page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.softYellow,
        onDestinationSelected: (index) {
          setState(() => currentIndex = index);
        },
        destinations: items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Home Tab (dynamic from Firestore) ──────────────────────────────────────

class HomeTab extends StatelessWidget {
  final String fullName;
  final String role;

  const HomeTab({
    super.key,
    required this.fullName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName =
        fullName.trim().isEmpty ? 'User' : fullName.split(' ').first;
    final roleLabel =
        role == 'manager' || role == 'admin' ? 'manager' : 'employee';

    // Today's date boundaries for filtering
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .snapshots(),
        builder: (context, eventsSnapshot) {
          // Count today's events and get upcoming events
          int todayEventCount = 0;
          final List<Map<String, dynamic>> upcomingEvents = [];

          if (eventsSnapshot.hasData) {
            for (final doc in eventsSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['status'] == EventStatus.cancelled) continue;

              final timestamp = data['date'];
              if (timestamp == null) continue;
              final date = (timestamp as Timestamp).toDate();

              // Count today's events
              if (!date.isBefore(todayStart) && date.isBefore(todayEnd)) {
                todayEventCount++;
              }

              // Collect upcoming events (today and future)
              if (!date.isBefore(todayStart)) {
                upcomingEvents.add({
                  'title': data['title'] ?? 'Untitled',
                  'date': date,
                  'id': doc.id,
                });
              }
            }

            // Sort upcoming by date
            upcomingEvents.sort((a, b) =>
                (a['date'] as DateTime).compareTo(b['date'] as DateTime));
          }

          // Limit to 5 upcoming events
          final displayEvents = upcomingEvents.take(5).toList();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('tasks')
                .snapshots(),
            builder: (context, tasksSnapshot) {
              int myTaskCount = 0;

              if (tasksSnapshot.hasData && user != null) {
                for (final doc in tasksSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'];
                  if (status == TaskStatus.cancelled ||
                      status == TaskStatus.done) {
                    continue;
                  }

                  final isMyPersonal =
                      data['taskType'] == TaskType.personal &&
                          data['assignedTo'] == user.uid;
                  final isMyClaimed =
                      data['taskType'] == TaskType.general &&
                          data['claimedBy'] == user.uid;

                  if (isMyPersonal || isMyClaimed) myTaskCount++;
                }
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Welcome back, $firstName',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Here is your $roleLabel overview for today.',
                    style: TextStyle(
                        color: Colors.grey.shade700, fontSize: 15),
                  ),
                  const SizedBox(height: 20),

                  // Highlight card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.softGreen,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today agenda',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                          '$todayEventCount event${todayEventCount == 1 ? '' : 's'} today and $myTaskCount active task${myTaskCount == 1 ? '' : 's'}.',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _QuickStatCard(
                          title: 'My tasks',
                          value: '$myTaskCount',
                          icon: Icons.task_alt,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickStatCard(
                          title: 'Today events',
                          value: '$todayEventCount',
                          icon: Icons.event,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Upcoming events
                  const Text('Upcoming events',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  if (displayEvents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text('No upcoming events',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ),
                    ),

                  ...displayEvents.map((event) {
                    final date = event['date'] as DateTime;
                    final dayLabel = _dayLabel(date, now);
                    return _EventTile(
                      title: event['title'] as String,
                      subtitle: dayLabel,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EventDetailPage(
                              eventId: event['id'] as String,
                              role: role,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _dayLabel(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final diff = eventDay.difference(today).inDays;

    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];

    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return 'Today • $timeStr';
    if (diff == 1) return 'Tomorrow • $timeStr';
    if (diff < 7) return '${weekdays[date.weekday - 1]} • $timeStr';
    return '${date.day}/${date.month}/${date.year} • $timeStr';
  }
}

// ─── Calendar Tab (Firestore-powered) ───────────────────────────────────────

class CalendarTab extends StatefulWidget {
  final String role;

  const CalendarTab({
    super.key,
    required this.role,
  });

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  final EventController _controller = EventController();
  StreamSubscription<QuerySnapshot>? _subscription;
  final List<CalendarEventData> _currentEvents = [];
  
  // Track selected event to show its tasks below the calendar
  CalendarEventData? _selectedEvent;

  @override
  void initState() {
    super.initState();
    _listenToEvents();
  }

  void _listenToEvents() {
    _subscription = FirebaseFirestore.instance
        .collection('events')
        .snapshots()
        .listen((snapshot) {
      // Remove old events from controller
      for (final e in _currentEvents) {
        _controller.remove(e);
      }
      _currentEvents.clear();

      // Add events from Firestore
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'scheduled';
        if (status == EventStatus.cancelled) continue;

        final timestamp = data['date'];
        if (timestamp == null) continue;

        final date = (timestamp as Timestamp).toDate();

        final int totalTasks = data['totalTasks'] ?? 0;
        final int completedTasks = data['completedTasks'] ?? 0;

        Color eventColor;
        if (status == EventStatus.completed) {
          eventColor = Colors.green.shade600;
        } else if (totalTasks == 0) {
          eventColor = Colors.green.shade600;
        } else if (completedTasks == totalTasks) {
          eventColor = Colors.green.shade600;
        } else if (completedTasks >= (totalTasks / 2.0)) {
          eventColor = Colors.amber.shade600; // Yellow/Amber when half completed
        } else {
          eventColor = Colors.red.shade600; // Red otherwise
        }

        final calEvent = CalendarEventData(
          date: date,
          title: data['title'] ?? 'Untitled',
          description: data['description'] ?? '',
          event: doc.id, // Store Firestore event ID
          color: eventColor,
        );

        _currentEvents.add(calEvent);
        _controller.add(calEvent);
      }

      // If the selected event was deleted/updated, refresh it
      if (_selectedEvent != null) {
        final exists = _currentEvents.any((e) => e.event == _selectedEvent!.event);
        if (!exists) {
          setState(() => _selectedEvent = null);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showEventSelection(List<CalendarEventData> events) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select an event',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...events.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.softYellow,
                      child:
                          const Icon(Icons.event, color: AppTheme.textDark),
                    ),
                    title: Text(e.title),
                    subtitle:
                        e.description != null && e.description!.isNotEmpty
                            ? Text(e.description!)
                            : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedEvent = e);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CalendarControllerProvider(
      controller: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calendar'),
          actions: [
            if (_selectedEvent != null)
              IconButton(
                icon: const Icon(Icons.clear_all),
                tooltip: 'Deselect Event',
                onPressed: () => setState(() => _selectedEvent = null),
              ),
          ],
        ),
        body: Column(
          children: [
            // Calendar month view (constrained height to allow tasks below)
            SizedBox(
              height: 420,
              child: MonthView(
                cellAspectRatio: 0.9,
                showWeekTileBorder: false,
                hideDaysNotInMonth: true,
                onCellTap: (events, date) {
                  if (events.isEmpty) {
                    setState(() => _selectedEvent = null);
                    return;
                  }

                  if (events.length == 1) {
                    setState(() => _selectedEvent = events.first);
                  } else {
                    _showEventSelection(events);
                  }
                },
                onEventTap: (event, date) {
                  setState(() => _selectedEvent = event);
                },
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Tasks section
            Expanded(
              child: _selectedEvent == null
                  ? _buildNoSelectionPlaceholder()
                  : _buildTasksListSection(_selectedEvent!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSelectionPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Tap an event day to view tasks',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksListSection(CalendarEventData event) {
    final eventId = event.event as String;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const SizedBox.shrink();

    final tasksStream = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('tasks')
        .snapshots();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: AppTheme.softGreenDark),
                tooltip: 'View Event Details',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailPage(
                        eventId: eventId,
                        role: widget.role,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.description!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: tasksStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No tasks assigned to this event.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                final tasks = snapshot.data!.docs
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'];
                      final completed = data['completed'] == true;
                      return status != TaskStatus.cancelled &&
                          status != TaskStatus.done &&
                          !completed;
                    })
                    .map((doc) => EventTask.fromDoc(eventId, doc))
                    .toList();

                if (tasks.isEmpty) {
                  return Center(
                    child: Text(
                      'No tasks available.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final taskService = TaskService();

                    final String employeeName = user.displayName?.trim().isNotEmpty == true
                        ? user.displayName!.trim()
                        : (user.email ?? 'Employee');

                    final bool isOpen = task.status == TaskStatus.open && task.claimedBy == null;
                    final bool isClaimedByMe = task.claimedBy == user.uid;
                    final bool isClaimedByOther =
                        task.claimedBy != null && task.claimedBy != user.uid;
                    final bool isDone = task.status == TaskStatus.done || task.completed;

                    final bool isChecked = isClaimedByMe || isDone;

                    Future<void> handleClaim() async {
                      if (!isOpen) return;
                      try {
                        await taskService.claimTask(
                          eventId: task.eventId,
                          taskId: task.id,
                          employeeName: employeeName,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Task claimed! Check My Tasks.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: isOpen ? handleClaim : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                onChanged: isOpen
                                    ? (value) => handleClaim()
                                    : null,
                                activeColor: AppTheme.softGreenDark,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                        color: isDone ? Colors.grey : null,
                                      ),
                                    ),
                                    if (task.description.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          task.description,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    if (isOpen)
                                      Text('Available — tap to claim',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w500))
                                    else if (isClaimedByMe && !isDone)
                                      Text('Claimed by you',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w500))
                                    else if (isClaimedByOther && !isDone)
                                      Text(
                                          'Claimed by ${task.claimedByName ?? 'another employee'}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic))
                                    else if (isDone)
                                      Text(
                                          'Completed${task.completedByName != null ? ' by ${task.completedByName}' : ''}',
                                          style: TextStyle(
                                              fontSize: 11,
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Announcements Tab ──────────────────────────────────────────────────────

class AnnouncementsTab extends StatelessWidget {
  final String role;

  const AnnouncementsTab({
    super.key,
    required this.role,
  });

  String _formatSectionDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'Today';
    } else if (itemDate == yesterday) {
      return 'Yesterday';
    } else {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isManager = role == 'manager' || role == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddNewsPage()),
                );
              },
              backgroundColor: AppTheme.softGreenDark,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New News'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('news')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No announcements yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // Group by date
          final Map<DateTime, List<QueryDocumentSnapshot>> groupedNews = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['date'] as Timestamp?;
            if (timestamp == null) continue;
            final fullDate = timestamp.toDate();
            final dateOnly = DateTime(fullDate.year, fullDate.month, fullDate.day);
            if (!groupedNews.containsKey(dateOnly)) {
              groupedNews[dateOnly] = [];
            }
            groupedNews[dateOnly]!.add(doc);
          }

          // Sort unique dates descending
          final sortedDates = groupedNews.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          final List<Widget> listItems = [];
          for (final date in sortedDates) {
            listItems.add(
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  _formatSectionDate(date),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            );

            for (final doc in groupedNews[date]!) {
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Untitled';
              final text = data['text'] ?? '';

              listItems.add(
                _AnnouncementCard(
                  title: title,
                  text: text,
                  trailing: isManager
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete news?'),
                                  content: const Text(
                                      'This will permanently remove this news item.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete',
                                            style: TextStyle(
                                                color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await FirebaseFirestore.instance
                                    .collection('news')
                                    .doc(doc.id)
                                    .delete();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Announcement deleted')),
                                  );
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: listItems,
          );
        },
      ),
    );
  }
}

// ─── Profile Tab ────────────────────────────────────────────────────────────

class ProfileTab extends StatefulWidget {
  final String fullName;
  final String role;

  const ProfileTab({
    super.key,
    required this.fullName,
    required this.role,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _showEditProfileBottomSheet(BuildContext context, String currentName) {
    final nameController = TextEditingController(text: currentName);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Profile Info',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final newName = nameController.text.trim();
                              if (newName.isEmpty) return;

                              setModalState(() => saving = true);

                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  // Update Firebase Auth display name
                                  await user.updateDisplayName(newName);

                                  // Update Firestore user document
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .update({'fullName': newName});
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile updated successfully'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              } finally {
                                setModalState(() => saving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.softGreenDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Save Changes', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? {};
          final name = data['fullName'] ?? widget.fullName;
          final role = data['role'] ?? widget.role;
          final email = data['email'] ?? user.email ?? 'No email';
          final roleLabel =
              role == 'manager' || role == 'admin' ? 'Manager' : 'Employee';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty ? 'No name available' : name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  roleLabel,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showEditProfileBottomSheet(context, name),
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: Colors.red.shade100),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Shared Widgets ─────────────────────────────────────────────────────────

class _QuickStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _QuickStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.softGreenDark),
            const SizedBox(height: 12),
            Text(
              value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _EventTile({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.softYellow,
          child: const Icon(Icons.event, color: AppTheme.textDark),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String title;
  final String text;
  final Widget? trailing;

  const _AnnouncementCard({
    required this.title,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}