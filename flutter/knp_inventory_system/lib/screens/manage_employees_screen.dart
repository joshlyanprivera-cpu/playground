import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/employee_record.dart';
import '../services/employee_service.dart';
import '../utils/admin_utils.dart';

class ManageEmployeesScreen extends StatefulWidget {
  const ManageEmployeesScreen({super.key});

  @override
  State<ManageEmployeesScreen> createState() => _ManageEmployeesScreenState();
}

class _ManageEmployeesScreenState extends State<ManageEmployeesScreen> {
  final EmployeeService _employeeService = EmployeeService();
  final Set<String> _updatingIds = {};

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeeRecord> _sorted(List<EmployeeRecord> employees) {
    final copy = List<EmployeeRecord>.from(employees);
    copy.sort((a, b) {
      if (a.isPending != b.isPending) {
        return a.isPending ? -1 : 1;
      }
      return a.email.toLowerCase().compareTo(b.email.toLowerCase());
    });
    return copy;
  }

  Future<void> _onActiveChanged(EmployeeRecord employee, bool value) async {
    setState(() => _updatingIds.add(employee.id));
    try {
      await _employeeService.setEmployeeActive(employee.id, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? '${employee.displayLabel} is now active.'
                  : '${employee.displayLabel} is now inactive.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update employee. Try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(employee.id));
      }
    }
  }

  Widget _buildEmployeeCard(EmployeeRecord employee, bool isDark) {
    final isUpdating = _updatingIds.contains(employee.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.displayLabel,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    employee.email,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: employee.active
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          employee.active ? 'Active' : 'Pending',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: employee.active
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          employee.id,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isUpdating)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Switch(
                value: employee.active,
                activeThumbColor: Colors.green.shade400,
                onChanged: (value) => _onActiveChanged(employee, value),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Employees',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<EmployeeRecord>>(
        stream: _employeeService.watchAllEmployees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load employees. Ensure you are signed in as '
                  '${AdminUtils.adminEmail} and Firestore rules are deployed.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.redAccent),
                ),
              ),
            );
          }

          final allEmployees = _sorted(snapshot.data ?? []);

          if (allEmployees.isEmpty) {
            return Center(
              child: Text(
                'No employees yet.\nNew users appear here after their first sign-in.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey, height: 1.4),
              ),
            );
          }

          // Filter logic
          final filteredEmployees = allEmployees.where((e) {
            final nameMatch = e.displayLabel.toLowerCase().contains(
              _searchQuery,
            );
            final emailMatch = e.email.toLowerCase().contains(_searchQuery);
            return nameMatch || emailMatch;
          }).toList();

          final pendingEmployees = filteredEmployees
              .where((e) => e.isPending)
              .toList();
          final activeEmployees = filteredEmployees
              .where((e) => e.active)
              .toList();

          if (filteredEmployees.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No matching employees found.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              if (pendingEmployees.isNotEmpty || _searchQuery.isEmpty)
                ExpansionTile(
                  initiallyExpanded: true,
                  leading: Icon(
                    Icons.pending_actions,
                    color: Colors.orange.shade700,
                  ),
                  title: Text(
                    'Pending Approval (${pendingEmployees.length})',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.only(bottom: 16),
                  children: pendingEmployees.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No pending accounts.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        ]
                      : pendingEmployees
                            .map((e) => _buildEmployeeCard(e, isDark))
                            .toList(),
                ),
              if (activeEmployees.isNotEmpty || _searchQuery.isEmpty)
                ExpansionTile(
                  initiallyExpanded: true,
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade600,
                  ),
                  title: Text(
                    'Active Employees (${activeEmployees.length})',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.only(bottom: 16),
                  children: activeEmployees.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No active accounts.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        ]
                      : activeEmployees
                            .map((e) => _buildEmployeeCard(e, isDark))
                            .toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}
