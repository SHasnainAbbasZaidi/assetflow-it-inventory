import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';

class LogsView extends StatelessWidget {
  const LogsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final logs = provider.logs;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Logs',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 4),
            Text(
              'Audit trail of all asset modifications and system events.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No activity logs recorded yet.',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.white.withOpacity(0.05),
                            ),
                            child: DataTable(
                              columnSpacing: 40.0,
                              columns: const [
                                DataColumn(label: Text('DATE / TIME')),
                                DataColumn(label: Text('ACTION')),
                                DataColumn(label: Text('ASSET ID')),
                                DataColumn(label: Text('USER')),
                                DataColumn(label: Text('DETAILS')),
                              ],
                              rows: logs.take(100).map((log) {
                                DateTime? parsedDate = DateTime.tryParse(log.timestamp);
                                String formattedTime = parsedDate != null 
                                    ? DateFormat.yMd().add_jms().format(parsedDate.toLocal())
                                    : log.timestamp;

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        formattedTime,
                                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        log.action,
                                        style: const TextStyle(
                                          color: Color(0xFF818CF8),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        log.assetId,
                                        style: const TextStyle(fontFamily: 'monospace'),
                                      ),
                                    ),
                                    DataCell(Text(log.user)),
                                    DataCell(Text(log.details)),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
