import 'package:flutter/material.dart';

import '../services/audit_service.dart';
import '../theme.dart';

class AuditTab extends StatefulWidget {
  const AuditTab({super.key});
  @override
  State<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<AuditTab> {
  String? _filter;
  late Future<List<AuditEntry>> _future = AuditService.instance.list();

  Future<void> _reload([String? filter]) async {
    _filter = filter;
    setState(() => _future = AuditService.instance.list(actionFilter: _filter));
    await _future;
  }

  static final _actions = <String, ({IconData icon, Color color})>{
    'grant_coins':       (icon: Icons.diamond_rounded,             color: AzarPalette.accent),
    'grant_vip':         (icon: Icons.workspace_premium_rounded,   color: AzarPalette.secondary),
    'ban_user':          (icon: Icons.block_rounded,               color: AzarPalette.danger),
    'unban_user':        (icon: Icons.lock_open_rounded,           color: AzarPalette.success),
    'set_role':          (icon: Icons.admin_panel_settings_rounded, color: AzarPalette.accent),
    'send_announcement': (icon: Icons.campaign_rounded,            color: AzarPalette.secondary),
    'update_pack':       (icon: Icons.inventory_2_rounded,         color: AzarPalette.textDim),
    'delete_pack':       (icon: Icons.delete_outline_rounded,      color: AzarPalette.danger),
  };

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AzarPalette.accent, onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(children: [
            Text('AUDIT LOG', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            DropdownButton<String?>(
              value: _filter,
              hint: const Text('Tümü', style: TextStyle(color: AzarPalette.textDim, fontSize: 13)),
              dropdownColor: AzarPalette.surfaceHigh,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.filter_list_rounded, color: AzarPalette.textDim, size: 18),
              style: const TextStyle(color: AzarPalette.text, fontSize: 13),
              onChanged: (v) => _reload(v),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tüm aksiyonlar')),
                for (final k in _actions.keys)
                  DropdownMenuItem(value: k, child: Text(k)),
              ],
            ),
          ]),
          const SizedBox(height: 8),
          FutureBuilder<List<AuditEntry>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 220, child: Center(
                  child: CircularProgressIndicator(color: AzarPalette.accent, strokeWidth: 2.4)));
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: AzarPalette.surface,
                    borderRadius: BorderRadius.circular(14), border: Border.all(color: AzarPalette.line)),
                  child: Column(children: [
                    const Icon(Icons.history_rounded, color: AzarPalette.textDim, size: 32),
                    const SizedBox(height: 10),
                    Text('Henüz kayıt yok',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim)),
                  ]),
                );
              }
              return Column(children: [
                for (final r in rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AzarPalette.surface,
                      borderRadius: BorderRadius.circular(13), border: Border.all(color: AzarPalette.line)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: (_actions[r.action]?.color ?? AzarPalette.textDim).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Icon(_actions[r.action]?.icon ?? Icons.bolt_rounded,
                          color: _actions[r.action]?.color ?? AzarPalette.textDim, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(r.action, style: const TextStyle(
                            color: AzarPalette.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(_rel(r.createdAt),
                            style: const TextStyle(color: AzarPalette.textDim, fontSize: 11)),
                        ]),
                        const SizedBox(height: 4),
                        Text(_describe(r),
                          style: const TextStyle(color: AzarPalette.textDim, fontSize: 12, height: 1.4)),
                      ])),
                    ]),
                  ),
              ]);
            },
          ),
        ],
      ),
    );
  }

  String _describe(AuditEntry r) {
    final actor = r.actorNickname ?? (r.actorId == null ? 'sistem' : r.actorId!.substring(0, 8));
    final target = r.targetNickname ?? r.targetId?.substring(0, 8);
    final d = r.details;
    final detail = (d == null || d.isEmpty) ? '' : ' • ${_compactJson(d)}';
    if (target != null) return '$actor → $target$detail';
    return '$actor$detail';
  }

  String _compactJson(Map<String, dynamic> m) {
    return m.entries.map((e) => '${e.key}=${e.value}').join(', ');
  }

  String _rel(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'şimdi';
    if (d.inMinutes < 60) return '${d.inMinutes}dk';
    if (d.inHours < 24) return '${d.inHours}sa';
    if (d.inDays < 7) return '${d.inDays}g';
    return '${dt.day}/${dt.month}';
  }
}
