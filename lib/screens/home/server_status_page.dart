import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/api_constants.dart';
import '../../models/server_status.dart';
import '../../providers/proxy_health_provider.dart';
import '../../services/proxy_health.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import '../../utils/navigation_utils.dart';
import '../../utils/formatting/format.dart' show kNoReading;

// ── Latency color helper ──────────────────────────────────────────────────────

/// Green under 300 ms, orange under 1000 ms, red from there. One scale for
/// the Apex regions and for our own servers.
Color latencyColor(int ms) {
  if (ms < 300) return AppTheme.green;
  if (ms < 1000) return AppTheme.orange;
  return AppTheme.red;
}

class ServerStatusPage extends ConsumerWidget {
  final ServerStatus status;

  /// Set when [status] is a saved copy rather than a fresh reading.
  final DateTime? staleAt;
  const ServerStatusPage({super.key, required this.status, this.staleAt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = status.services.values.toList();
    final proxies = ref.watch(proxyHealthProvider).asData?.value;
    // Neither of our servers answers, so the Apex readings below may be as old
    // as the last time this device could reach them.
    final cannotReach =
        proxies != null &&
        proxies.primary.state == ProxyState.down &&
        proxies.backup.state != ProxyState.online &&
        proxies.backup.state != ProxyState.slow;
    return Scaffold(
      appBar: AppBar(title: const Text('Server Status')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.md),
              itemCount: services.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (staleAt != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppTheme.sm),
                          child: StaleBanner(
                            staleAt: staleAt!,
                            label: 'Last checked',
                          ),
                        ),
                      if (cannotReach)
                        const Padding(
                          padding: EdgeInsets.only(bottom: AppTheme.sm),
                          child: _CannotReachNote(),
                        ),
                      const _ProxyStatusCard(),
                    ],
                  );
                }
                final svc = services[i - 1];
                final color = AppTheme.statusColor(svc.overallStatus);
                return SurfaceCard(
                  margin: const EdgeInsets.only(bottom: AppTheme.sm),
                  padding: const EdgeInsets.all(AppTheme.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusDot(color: color),
                          const SizedBox(width: AppTheme.sm),
                          Expanded(
                            child: Text(
                              svc.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              svc.overallStatus,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (svc.regions.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.sm),
                        Wrap(
                          spacing: AppTheme.sm,
                          runSpacing: 4,
                          children: svc.regions.entries.map((e) {
                            final region = e.value;
                            // Latency says how healthy a region that is up is;
                            // a region that isn't takes its status colour.
                            final rc = region.status == 'UP'
                                ? latencyColor(region.responseTime)
                                : AppTheme.statusColor(region.status);
                            final latency = region.responseTime > 0
                                ? '${region.responseTime}ms'
                                : kNoReading;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusDot(color: rc, size: 6),
                                const SizedBox(width: AppTheme.xs),
                                Text(
                                  '${e.key} | $latency',
                                  style: AppTheme.captionSmall,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Semantics(
            link: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openExternalLink(
                context,
                Uri.parse(ApiConstants.apexStatusUrl),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: const Center(
                  child: Text(
                    'Data from apexlegendsstatus.com',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.blue,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the app's own servers are up: the primary, and the backup it falls
/// back to when the primary is down. Laid out like the service cards above.
/// Says why the Apex readings below may not be current.
class _CannotReachNote extends StatelessWidget {
  const _CannotReachNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.md,
        vertical: AppTheme.sm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.orange.withAlpha(25),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.wifi_off, size: 14, color: AppTheme.orange),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              "Can't reach the Apexlytics servers, so the readings below are "
              'the last ones this device received and may be out of date.',
              style: TextStyle(color: AppTheme.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProxyStatusCard extends ConsumerWidget {
  const _ProxyStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(proxyHealthProvider).asData?.value;
    final (overall, color) = _overall(data);
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(color: color),
              const SizedBox(width: AppTheme.sm),
              const Expanded(
                child: Text(
                  'Apexlytics Servers',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  overall,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Wrap(
            spacing: AppTheme.sm,
            runSpacing: 4,
            children: [
              _ProxyItem(label: 'Primary', health: data?.primary),
              _ProxyItem(label: 'Backup', health: data?.backup),
            ],
          ),
        ],
      ),
    );
  }

  /// One word and colour for both servers together. A backup that isn't set up
  /// doesn't count against the rest.
  static (String, Color) _overall(ProxyHealthReport? r) {
    if (r == null) return ('CHECKING', AppTheme.muted);
    final primary = r.primary.state;
    final backup = r.backup.state;
    if (primary == ProxyState.down) {
      return backup == ProxyState.online || backup == ProxyState.slow
          ? ('PARTIAL', AppTheme.orange)
          : ('DOWN', AppTheme.red);
    }
    if (primary == ProxyState.slow || backup == ProxyState.down) {
      return primary == ProxyState.slow
          ? ('SLOW', AppTheme.orange)
          : ('PARTIAL', AppTheme.orange);
    }
    return ('UP', AppTheme.green);
  }
}

class _ProxyItem extends StatelessWidget {
  final String label;

  /// Null while the check is running.
  final ProxyHealth? health;
  const _ProxyItem({required this.label, required this.health});

  @override
  Widget build(BuildContext context) {
    final h = health;
    final ms = h?.latency?.inMilliseconds;
    final (color, text) = switch (h?.state) {
      null => (AppTheme.muted, '…'),
      ProxyState.online ||
      ProxyState.slow => (latencyColor(ms ?? 0), '${ms}ms'),
      ProxyState.down => (AppTheme.red, 'DOWN'),
      ProxyState.notConfigured => (AppTheme.muted, kNoReading),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusDot(color: color, size: 6),
        const SizedBox(width: AppTheme.xs),
        Text('$label | $text', style: AppTheme.captionSmall),
      ],
    );
  }
}
