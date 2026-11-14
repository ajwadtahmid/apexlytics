import 'package:material_ui/material_ui.dart';
import '../models/server_status.dart';
import '../utils/theme.dart';
import 'summary_card.dart';
import 'status_dot.dart';

class ServerSummaryCard extends StatelessWidget {
  final ServerStatus status;
  final VoidCallback onTap;

  const ServerSummaryCard({
    super.key,
    required this.status,
    required this.onTap,
  });

  // ≥2 core services down = DOWN; any 1 down or slow = PARTIAL; else UP.
  String get _overallSeverity {
    final priority = status.services.entries
        .where((e) => ServiceStatus.priorityKeys.contains(e.key))
        .map((e) => e.value.overallStatus)
        .toList();
    if (priority.isEmpty) return 'UP';
    final downCount = priority.where((s) => s == 'DOWN').length;
    final slowCount = priority.where((s) => s == 'SLOW').length;
    if (downCount >= 2) return 'DOWN';
    if (downCount >= 1 || slowCount >= 1) return 'PARTIAL';
    return 'UP';
  }

  Color get _statusColor => switch (_overallSeverity) {
    'DOWN' => AppTheme.red,
    'PARTIAL' => AppTheme.orange,
    _ => AppTheme.green,
  };

  String get _subtitle => switch (_overallSeverity) {
    'DOWN' => 'Major outage',
    'PARTIAL' => 'Partial outage',
    _ => 'All systems operational',
  };

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      leading: StatusDot(color: _statusColor),
      title: 'Server Status',
      subtitle: _subtitle,
      onTap: onTap,
    );
  }
}
