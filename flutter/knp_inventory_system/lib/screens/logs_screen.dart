import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/log_entry.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Ingredients', 'Categories', 'Adds', 'Updates', 'Deletions'
  String _selectedDateFilter = 'All Time';
  DateTime? _specificDate;
  final Set<String> _expandedLogIds = {};
  late Stream<QuerySnapshot> _logsStream;

  @override
  void initState() {
    super.initState();
    _updateLogsStream();
  }

  void _updateLogsStream() {
    Query query = _firestore.collection('logs');
    
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    switch (_selectedDateFilter) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case 'This Week':
        final daysToSubtract = now.weekday % 7;
        startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
        endDate = now;
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = now;
        break;
      case 'This Quarter':
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        startDate = DateTime(now.year, quarterMonth, 1);
        endDate = now;
        break;
      case 'This Year':
        startDate = DateTime(now.year, 1, 1);
        endDate = now;
        break;
      case 'Specific Date':
        if (_specificDate != null) {
          startDate = DateTime(_specificDate!.year, _specificDate!.month, _specificDate!.day, 0, 0, 0);
          endDate = DateTime(_specificDate!.year, _specificDate!.month, _specificDate!.day, 23, 59, 59, 999);
        }
        break;
      default:
        // 'All Time'
        break;
    }

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    query = query.orderBy('timestamp', descending: true).limit(200);
    if (mounted) {
      setState(() {
        _logsStream = query.snapshots();
      });
    } else {
      _logsStream = query.snapshots();
    }
  }
  
  _LogDetails _getLogDetails(LogEntry log) {
    final action = log.action;
    final isCategory = log.targetType == 'category';
    final item = log.itemName;
    
    if (action == 'batch') {
      final updatesCount = log.bulkUpdates?.length ?? 0;
      final deletionsCount = log.bulkDeletions?.length ?? 0;
      
      String summary = 'Batch edit';
      if (updatesCount > 0 && deletionsCount > 0) {
        summary = 'Batch edit: $updatesCount updated, $deletionsCount deleted';
      } else if (updatesCount > 0) {
        summary = 'Batch edit: $updatesCount updated';
      } else if (deletionsCount > 0) {
        summary = 'Batch edit: $deletionsCount deleted';
      }
      
      final List<String> details = [];
      
      // Deletions first
      if (log.bulkDeletions != null) {
        for (final del in log.bulkDeletions!) {
          final name = del['itemName'] ?? '';
          final cat = del['categoryName'] != null && del['categoryName'].toString().isNotEmpty
              ? ' (Category: ${del['categoryName']})'
              : '';
          details.add('Deleted "$name"$cat');
        }
      }
      
      // Updates second
      if (log.bulkUpdates != null) {
        for (final upd in log.bulkUpdates!) {
          final name = upd['itemName'] ?? '';
          final List<String> changes = [];
          
          if (upd['quantityChange'] != null) {
            final change = (upd['quantityChange'] as num).toDouble();
            final absChange = change.abs();
            final changeStr = absChange % 1 == 0 ? absChange.toInt().toString() : absChange.toString();
            final unit = upd['quantityUnit'] ?? '';
            if (change > 0) {
              changes.add('added $changeStr $unit');
            } else {
              changes.add('reduced by $changeStr $unit');
            }
          }
          
          if (upd['previousCategory'] != null && upd['newCategory'] != null) {
            changes.add('moved from "${upd['previousCategory']}" to "${upd['newCategory']}"');
          }
          
          if (upd['previousQuantityUnit'] != null && upd['newQuantityUnit'] != null) {
            changes.add('changed unit from "${upd['previousQuantityUnit']}" to "${upd['newQuantityUnit']}"');
          }
          
          if (changes.isEmpty) {
            details.add('Updated "$name"');
          } else {
            details.add('Updated "$name": ${changes.join(", ")}');
          }
        }
      }
      
      return _LogDetails(summary: summary, details: details);
    }

    if (action == 'add') {
      if (isCategory) {
        return _LogDetails(summary: 'Created category "$item"', details: []);
      } else {
        final unit = log.quantityUnit ?? '';
        final qty = log.quantityChange ?? 0.0;
        final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
        final cat = log.categoryName != null && log.categoryName!.isNotEmpty
            ? ' in category "${log.categoryName}"'
            : '';
        return _LogDetails(summary: 'Added $qtyStr $unit of "$item"$cat', details: []);
      }
    } else if (action == 'delete') {
      if (isCategory) {
        return _LogDetails(summary: 'Deleted category "$item"', details: []);
      } else {
        final cat = log.categoryName != null && log.categoryName!.isNotEmpty
            ? ' (Category: ${log.categoryName})'
            : '';
        return _LogDetails(summary: 'Deleted ingredient "$item"$cat', details: []);
      }
    } else if (action == 'update') {
      if (isCategory) {
        if (log.previousCategory != null && log.newCategory != null) {
          return _LogDetails(summary: 'Renamed category "${log.previousCategory}" to "${log.newCategory}"', details: []);
        }
        return _LogDetails(summary: 'Updated category "$item"', details: []);
      } else {
        final List<String> changes = [];
        
        if (log.quantityChange != null) {
          final change = log.quantityChange!;
          final absChange = change.abs();
          final changeStr = absChange % 1 == 0 ? absChange.toInt().toString() : absChange.toString();
          final unit = log.quantityUnit ?? '';
          
          if (change > 0) {
            changes.add('Added $changeStr $unit');
          } else {
            changes.add('Reduced by $changeStr $unit');
          }
        }
        
        if (log.previousCategory != null && log.newCategory != null) {
          changes.add('Moved from "${log.previousCategory}" to "${log.newCategory}"');
        }
        
        if (log.previousQuantityUnit != null && log.newQuantityUnit != null) {
          changes.add('Changed unit from "${log.previousQuantityUnit}" to "${log.newQuantityUnit}"');
        }
        
        if (changes.isEmpty) {
          return _LogDetails(summary: 'Updated ingredient "$item"', details: []);
        }
        
        if (changes.length == 1) {
          return _LogDetails(summary: 'Updated "$item": ${changes.first.toLowerCase()}', details: []);
        }
        
        return _LogDetails(
          summary: 'Updated "$item" (${changes.length} changes)',
          details: changes,
        );
      }
    }
    return _LogDetails(summary: 'Performed $action on $item', details: []);
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return 'Today at $hour:$min $ampm';
    } else if (diff.inDays < 7) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekday = days[dt.weekday - 1];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$weekday at $hour:$min $ampm';
    } else {
      final monthStr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} $monthStr ${dt.year} at $hour:$min $ampm';
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'add':
        return Colors.green.shade600;
      case 'update':
        return Colors.blue.shade600;
      case 'delete':
        return Colors.red.shade600;
      case 'batch':
        return Colors.deepPurple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getActionIcon(String action, String targetType) {
    if (action == 'batch') {
      return Icons.checklist_rounded;
    }
    if (targetType == 'category') {
      switch (action) {
        case 'add':
          return Icons.create_new_folder_outlined;
        case 'delete':
          return Icons.folder_delete_outlined;
        default:
          return Icons.folder_open_outlined;
      }
    } else {
      switch (action) {
        case 'add':
          return Icons.add_circle_outline_rounded;
        case 'delete':
          return Icons.remove_circle_outline_rounded;
        default:
          return Icons.edit_note_rounded;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Header ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audit Logs',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.history,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ),

                // ─── Search & Filters ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search logs by item or user email...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'All',
                            'Ingredients',
                            'Categories',
                            'Adds',
                            'Updates',
                            'Deletions',
                          ].map((filter) {
                            final isSelected = _selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(filter),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedFilter = filter;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'All Time',
                            'Today',
                            'This Week',
                            'This Month',
                            'This Quarter',
                            'This Year',
                            'Specific Date',
                          ].map((dateFilter) {
                            final isSelected = _selectedDateFilter == dateFilter;
                            String label = dateFilter;
                            if (dateFilter == 'Specific Date' && _specificDate != null) {
                              final dayStr = _specificDate!.day.toString().padLeft(2, '0');
                              final monthStr = _specificDate!.month.toString().padLeft(2, '0');
                              label = 'Date: $dayStr/$monthStr/${_specificDate!.year}';
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (selected) async {
                                  if (dateFilter == 'Specific Date') {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _specificDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      _selectedDateFilter = 'Specific Date';
                                      _specificDate = picked;
                                      _updateLogsStream();
                                    }
                                  } else {
                                    if (selected) {
                                      _selectedDateFilter = dateFilter;
                                      _specificDate = null;
                                      _updateLogsStream();
                                    }
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Logs Stream ───
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _logsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error loading logs: ${snapshot.error}'),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      List<LogEntry> logs = docs
                          .map((doc) => LogEntry.fromFirestore(doc))
                          .toList();

                      // Apply filters locally
                      if (_selectedFilter != 'All') {
                        logs = logs.where((log) {
                          switch (_selectedFilter) {
                            case 'Ingredients':
                              return log.targetType == 'ingredient';
                            case 'Categories':
                              return log.targetType == 'category';
                            case 'Adds':
                              return log.action == 'add';
                            case 'Updates':
                              return log.action == 'update' ||
                                  (log.action == 'batch' &&
                                      log.bulkUpdates != null &&
                                      log.bulkUpdates!.isNotEmpty);
                            case 'Deletions':
                              return log.action == 'delete' ||
                                  (log.action == 'batch' &&
                                      log.bulkDeletions != null &&
                                      log.bulkDeletions!.isNotEmpty);
                            default:
                              return true;
                          }
                        }).toList();
                      }

                      // Apply search query locally
                      if (_searchQuery.isNotEmpty) {
                        logs = logs.where((log) {
                          final logDetails = _getLogDetails(log);
                          final user = log.userIdentifier.toLowerCase();
                          final summaryMatch = logDetails.summary.toLowerCase().contains(_searchQuery);
                          final detailsMatch = logDetails.details.any((d) => d.toLowerCase().contains(_searchQuery));
                          return summaryMatch || detailsMatch || user.contains(_searchQuery);
                        }).toList();
                      }

                      if (logs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_toggle_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No matching log entries found',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final actionColor = _getActionColor(log.action);
                          final actionIcon = _getActionIcon(log.action, log.targetType);
                          final logDetails = _getLogDetails(log);
                          final details = logDetails.details;
                          final hasDetails = details.isNotEmpty;
                          final isExpanded = _expandedLogIds.contains(log.id);
                          final timeStr = _formatTimestamp(log.timestamp);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: hasDetails
                                  ? () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedLogIds.remove(log.id);
                                        } else {
                                          _expandedLogIds.add(log.id);
                                        }
                                      });
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: actionColor.withAlpha(25),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            actionIcon,
                                            color: actionColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                logDetails.summary,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'by ${log.userIdentifier}',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade500,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    timeStr,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade500,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasDetails) ...[
                                      AnimatedCrossFade(
                                        firstChild: const SizedBox.shrink(),
                                        secondChild: Padding(
                                          padding: const EdgeInsets.only(top: 12, left: 42),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: details.map((detail) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.arrow_right_rounded,
                                                      size: 16,
                                                      color: actionColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        detail,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 13,
                                                          color: isDark
                                                              ? Colors.grey.shade300
                                                              : Colors.grey.shade700,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        crossFadeState: isExpanded
                                            ? CrossFadeState.showSecond
                                            : CrossFadeState.showFirst,
                                        duration: const Duration(milliseconds: 200),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 42, top: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isExpanded ? 'Show less' : 'Show more',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: actionColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Icon(
                                              isExpanded
                                                  ? Icons.keyboard_arrow_up
                                                  : Icons.keyboard_arrow_down,
                                              size: 16,
                                              color: actionColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
          ),
        ),
      ),
    );
  }
}

class _LogDetails {
  final String summary;
  final List<String> details;
  _LogDetails({required this.summary, required this.details});
}
