import 'package:flutter/material.dart';
import '../models/notice.dart';
import '../services/notice_service.dart';
import 'add_notice_screen.dart';
import 'notice_detail_screen.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'add_call_screen.dart';

class NoticeTrackerScreen extends StatefulWidget {
  const NoticeTrackerScreen({super.key});

  @override
  State<NoticeTrackerScreen> createState() => _NoticeTrackerScreenState();
}

class _NoticeTrackerScreenState extends State<NoticeTrackerScreen> {
  // Filter and Sort State
  String? _selectedStatus;
  String? _selectedPriority;
  String? _selectedClientId;
  String _sortBy = 'dueDate'; // dueDate, clientId, priority, status
  bool _sortAscending = true;
  String _searchQuery = '';
  bool _showFilters = false;

  // Filter Options
  final List<String> _statusOptions = [
    'All',
    'Open',
    'In Progress',
    'Waiting on Client',
    'Awaiting IRS Response',
    'Escalated',
    'Closed',
  ];

  final List<String> _priorityOptions = [
    'All',
    'Low',
    'Medium',
    'High',
    'Final/Levy/Lien',
  ];

  final List<String> _sortOptions = [
    'Due Date',
    'Client ID',
    'Priority',
    'Status',
    'Notice Date',
  ];

  // Helper method to get priority color
  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'final/levy/lien':
        return Colors.deepOrange;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Helper method to get priority icon
  IconData _getPriorityIcon(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'final/levy/lien':
        return Icons.warning;
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.flag;
      case 'low':
        return Icons.flag_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'escalated':
        return Colors.red;
      case 'waiting on client':
        return Colors.purple;
      case 'awaiting irs response':
        return Colors.indigo;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Get priority order for sorting
  int _getPriorityOrder(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'final/levy/lien':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  // Filter and sort notices
  List<Notice> _filterAndSortNotices(List<Notice> notices) {
    // Apply filters
    List<Notice> filtered = notices.where((notice) {
      // Status filter
      if (_selectedStatus != null && _selectedStatus != 'All') {
        if (notice.status != _selectedStatus) return false;
      }

      // Priority filter
      if (_selectedPriority != null && _selectedPriority != 'All') {
        if (notice.priority != _selectedPriority) return false;
      }

      // Client ID filter
      if (_selectedClientId != null && _selectedClientId!.isNotEmpty) {
        if (!notice.clientId.toLowerCase().contains(_selectedClientId!.toLowerCase())) {
          return false;
        }
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return (notice.autoId?.toLowerCase().contains(query) ?? false) ||
            notice.clientId.toLowerCase().contains(query) ||
            notice.noticeNumber.toLowerCase().contains(query) ||
            (notice.noticeIssue?.toLowerCase().contains(query) ?? false);
      }

      return true;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case 'dueDate':
          final aDue = a.dueDate;
          final bDue = b.dueDate;
          if (aDue == null && bDue == null) {
            comparison = 0;
          } else if (aDue == null) {
            comparison = 1; // null dates go to end
          } else if (bDue == null) {
            comparison = -1;
          } else {
            comparison = aDue.compareTo(bDue);
          }
          break;
        case 'clientId':
          comparison = a.clientId.compareTo(b.clientId);
          break;
        case 'priority':
          comparison = _getPriorityOrder(b.priority).compareTo(_getPriorityOrder(a.priority));
          break;
        case 'status':
          comparison = a.status.compareTo(b.status);
          break;
        case 'noticeDate':
          final aDate = a.dateReceived;
          final bDate = b.dateReceived;
          if (aDate == null && bDate == null) {
            comparison = 0;
          } else if (aDate == null) {
            comparison = 1;
          } else if (bDate == null) {
            comparison = -1;
          } else {
            comparison = aDate.compareTo(bDate);
          }
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedPriority = null;
      _selectedClientId = null;
      _searchQuery = '';
    });
  }

  Widget _buildFilterChips() {
    List<Widget> chips = [];

    if (_selectedStatus != null && _selectedStatus != 'All') {
      chips.add(
        Chip(
          label: Text('Status: $_selectedStatus'),
          onDeleted: () => setState(() => _selectedStatus = null),
          backgroundColor: Colors.blue.shade100,
        ),
      );
    }

    if (_selectedPriority != null && _selectedPriority != 'All') {
      chips.add(
        Chip(
          label: Text('Priority: $_selectedPriority'),
          onDeleted: () => setState(() => _selectedPriority = null),
          backgroundColor: _getPriorityColor(_selectedPriority).withOpacity(0.2),
        ),
      );
    }

    if (_selectedClientId != null && _selectedClientId!.isNotEmpty) {
      chips.add(
        Chip(
          label: Text('Client: $_selectedClientId'),
          onDeleted: () => setState(() => _selectedClientId = null),
          backgroundColor: Colors.green.shade100,
        ),
      );
    }

    if (_searchQuery.isNotEmpty) {
      chips.add(
        Chip(
          label: Text('Search: $_searchQuery'),
          onDeleted: () => setState(() => _searchQuery = ''),
          backgroundColor: Colors.orange.shade100,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Filters:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear All'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: chips,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notices"),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'Due Date':
                    _sortBy = 'dueDate';
                    break;
                  case 'Client ID':
                    _sortBy = 'clientId';
                    break;
                  case 'Priority':
                    _sortBy = 'priority';
                    break;
                  case 'Status':
                    _sortBy = 'status';
                    break;
                  case 'Notice Date':
                    _sortBy = 'noticeDate';
                    break;
                }
              });
            },
            itemBuilder: (context) => _sortOptions.map((option) {
              final isSelected = (_sortBy == 'dueDate' && option == 'Due Date') ||
                  (_sortBy == 'clientId' && option == 'Client ID') ||
                  (_sortBy == 'priority' && option == 'Priority') ||
                  (_sortBy == 'status' && option == 'Status') ||
                  (_sortBy == 'noticeDate' && option == 'Notice Date');

              return PopupMenuItem<String>(
                value: option,
                child: Row(
                  children: [
                    if (isSelected) const Icon(Icons.check, size: 16),
                    if (isSelected) const SizedBox(width: 8),
                    Text(option),
                    const Spacer(),
                    if (isSelected)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _sortAscending = !_sortAscending);
                        },
                        child: Icon(
                          _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search notices...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Filter Panel
          if (_showFilters)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filters:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: _statusOptions.map((status) {
                            return DropdownMenuItem(value: status == 'All' ? null : status, child: Text(status));
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedStatus = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPriority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: _priorityOptions.map((priority) {
                            return DropdownMenuItem(value: priority == 'All' ? null : priority, child: Text(priority));
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedPriority = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Filter by Client ID',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) => setState(() => _selectedClientId = value.isEmpty ? null : value),
                  ),
                ],
              ),
            ),

          // Active Filter Chips
          _buildFilterChips(),

          // Notice List
          Expanded(
            child: StreamBuilder<List<Notice>>(
              stream: NoticeService.getNoticesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final allNotices = snapshot.data ?? [];
                final filteredNotices = _filterAndSortNotices(allNotices);

                if (allNotices.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("No notices found. Tap + to add one."),
                      ],
                    ),
                  );
                }

                if (filteredNotices.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("No notices match your filters."),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Results count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            'Showing ${filteredNotices.length} of ${allNotices.length} notices',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Text(
                            'Sorted by: ${_sortOptions.firstWhere((option) =>
                            (_sortBy == 'dueDate' && option == 'Due Date') ||
                                (_sortBy == 'clientId' && option == 'Client ID') ||
                                (_sortBy == 'priority' && option == 'Priority') ||
                                (_sortBy == 'status' && option == 'Status') ||
                                (_sortBy == 'noticeDate' && option == 'Notice Date')
                            )} ${_sortAscending ? '↑' : '↓'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredNotices.length,
                        itemBuilder: (context, index) {
                          final notice = filteredNotices[index];
                          final dueDate = notice.dueDate;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(notice.status),
                                child: Text(
                                  notice.status[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(notice.autoId ?? "Unknown Notice")),
                                  if (notice.priority != null) ...[
                                    Icon(
                                      _getPriorityIcon(notice.priority),
                                      color: _getPriorityColor(notice.priority),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(notice.priority).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getPriorityColor(notice.priority),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        notice.priority!,
                                        style: TextStyle(
                                          color: _getPriorityColor(notice.priority),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Client: ${notice.clientId}"),
                                  if (notice.noticeIssue != null)
                                    Text(notice.noticeIssue!),
                                  Text(
                                    "Status: ${notice.status} | Due: ${dueDate != null ? dueDate.toLocal().toString().split(' ')[0] : 'N/A'}",
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NoticeDetailScreen(noticeId: notice.id),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Colors.teal,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.description),
            label: 'Add Notice',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddNoticeScreen(),
                ),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.add_call),
            label: 'Add Response',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddCallScreen(
                    noticeId: "",
                    clientId: "",
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}