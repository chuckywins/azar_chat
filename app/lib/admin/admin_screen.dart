import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../theme.dart';
import 'admin_repo.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.instance;
    if (!auth.isAdmin && !auth.isModerator) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 12, height: 12, color: AzarPalette.danger),
                const SizedBox(height: 16),
                Text('Yetkin yok', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text('Bu sayfa sadece admin/moderator role\'lü kullanıcılar içindir.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim)),
                const SizedBox(height: 16),
                _BackBtn(),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AzarPalette.line))),
              child: TabBar(
                controller: _tabs,
                indicatorColor: AzarPalette.accent,
                indicatorWeight: 2,
                labelColor: AzarPalette.text,
                unselectedLabelColor: AzarPalette.textDim,
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2),
                tabs: const [
                  Tab(text: 'PANO'),
                  Tab(text: 'RAPORLAR'),
                  Tab(text: 'KULLANICILAR'),
                  Tab(text: 'YASAKLAR'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _DashboardTab(),
                  _ReportsTab(),
                  _UsersTab(),
                  _BansTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: AzarPalette.accent),
          const SizedBox(width: 10),
          Text('kerochat / admin', style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          _BackBtn(),
        ],
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: AzarPalette.line)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back, size: 16, color: AzarPalette.text),
            const SizedBox(width: 6),
            Text('Geri', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Dashboard tab
// ============================================================================

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  late Future<Map<String, int>> _future = AdminRepo.instance.counters();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = AdminRepo.instance.counters());
        await _future;
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FutureBuilder<Map<String, int>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _Loading();
              }
              if (snap.hasError) return _ErrorBox(message: '${snap.error}');
              final c = snap.data ?? {};
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _Stat(label: 'Toplam Kullanıcı', value: '${c['users'] ?? 0}'),
                  _Stat(label: 'Bekleyen Rapor', value: '${c['pending_reports'] ?? 0}', accent: (c['pending_reports'] ?? 0) > 0),
                  _Stat(label: 'Aktif Yasak', value: '${c['active_bans'] ?? 0}'),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text('Hızlı işlemler', style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text('Üst sekmelerden raporları, kullanıcıları ve yasakları yönetebilirsin.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.accent = false});
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AzarPalette.surface,
        border: Border.all(color: accent ? AzarPalette.accent : AzarPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 36,
                    color: accent ? AzarPalette.accent : AzarPalette.text,
                  )),
        ],
      ),
    );
  }
}

// ============================================================================
// Reports tab
// ============================================================================

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  late Future<List<Map<String, dynamic>>> _future = AdminRepo.instance.pendingReports();

  Future<void> _refresh() async {
    setState(() => _future = AdminRepo.instance.pendingReports());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthController.instance.userId ?? '';
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const _Loading();
          if (snap.hasError) return _ErrorBox(message: '${snap.error}');
          final reports = snap.data ?? const [];
          if (reports.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Text('Bekleyen rapor yok.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim))),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) => _ReportTile(
              report: reports[i],
              onDismiss: () async {
                await AdminRepo.instance.dismissReport(reports[i]['id'] as String, me);
                await _refresh();
              },
              onAction: () async {
                await AdminRepo.instance.actionReport(reports[i]['id'] as String, me);
                await _refresh();
              },
            ),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemCount: reports.length,
          );
        },
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.onDismiss, required this.onAction});
  final Map<String, dynamic> report;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final reportedId = (report['reported_id'] as String?) ?? '-';
    final reason = (report['reason'] as String?) ?? 'other';
    final note = report['note'] as String?;
    final createdAt = DateTime.tryParse((report['created_at'] as String?) ?? '');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AzarPalette.surface, border: Border.all(color: AzarPalette.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ReasonChip(reason: reason),
              const SizedBox(width: 8),
              Text(_short(reportedId),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
              const Spacer(),
              if (createdAt != null)
                Text(_relative(createdAt),
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniBtn(label: 'Reddet', onTap: onDismiss),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniBtn(label: 'Aksiyon', danger: true, onTap: onAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});
  final String reason;
  static const _labels = {
    'nsfw': 'NSFW',
    'harassment': 'TACİZ',
    'spam': 'SPAM',
    'minor': 'KÜÇÜK',
    'other': 'DİĞER',
  };
  static const _colors = {
    'nsfw': AzarPalette.danger,
    'harassment': AzarPalette.danger,
    'spam': AzarPalette.warning,
    'minor': AzarPalette.danger,
    'other': AzarPalette.textDim,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[reason] ?? AzarPalette.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(_labels[reason] ?? reason.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, letterSpacing: 1.0)),
    );
  }
}

// ============================================================================
// Users tab
// ============================================================================

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<List<Map<String, dynamic>>> _future = AdminRepo.instance.recentProfiles();
  final _search = TextEditingController();

  Future<void> _refresh() async {
    setState(() => _future = AdminRepo.instance.recentProfiles(search: _search.text.trim()));
    await _future;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _refresh(),
            style: Theme.of(context).textTheme.bodyLarge,
            cursorColor: AzarPalette.accent,
            decoration: const InputDecoration(
              hintText: 'Nickname ara, Enter',
              isDense: true,
              prefixIcon: Icon(Icons.search, color: AzarPalette.textDim, size: 18),
              border: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.line)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.line)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.accent, width: 2)),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const _Loading();
                if (snap.hasError) return _ErrorBox(message: '${snap.error}');
                final users = snap.data ?? const [];
                if (users.isEmpty) {
                  return ListView(children: [
                    const SizedBox(height: 80),
                    Center(child: Text('Kullanıcı yok.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim))),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemBuilder: (_, i) => _UserTile(profile: users[i], onChanged: _refresh),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemCount: users.length,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.profile, required this.onChanged});
  final Map<String, dynamic> profile;
  final Future<void> Function() onChanged;

  Future<void> _banDialog(BuildContext context) async {
    final me = AuthController.instance.userId ?? '';
    final reasonCtrl = TextEditingController(text: 'Manuel yasak');
    Duration duration = const Duration(hours: 24);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AzarPalette.surface,
        title: const Text('Yasakla', style: TextStyle(color: AzarPalette.text)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: reasonCtrl,
            style: const TextStyle(color: AzarPalette.text),
            decoration: const InputDecoration(labelText: 'Sebep'),
          ),
          const SizedBox(height: 12),
          StatefulBuilder(builder: (ctx, set) {
            return Wrap(
              spacing: 8,
              children: [
                _DurChip(label: '1 saat',   on: duration == const Duration(hours: 1),   tap: () => set(() => duration = const Duration(hours: 1))),
                _DurChip(label: '24 saat',  on: duration == const Duration(hours: 24),  tap: () => set(() => duration = const Duration(hours: 24))),
                _DurChip(label: '7 gün',    on: duration == const Duration(days: 7),    tap: () => set(() => duration = const Duration(days: 7))),
                _DurChip(label: '30 gün',   on: duration == const Duration(days: 30),   tap: () => set(() => duration = const Duration(days: 30))),
              ],
            );
          }),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () async {
              await AdminRepo.instance.banUser(
                userId: profile['id'] as String,
                reason: reasonCtrl.text,
                duration: duration,
                createdBy: me,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              await onChanged();
            },
            child: const Text('YASAKLA', style: TextStyle(color: AzarPalette.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = profile['id'] as String;
    final nick = (profile['nickname'] as String?) ?? '—';
    final role = (profile['role'] as String?) ?? 'user';
    final banned = (profile['is_banned'] as bool?) ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AzarPalette.surface,
        border: Border.all(color: banned ? AzarPalette.danger : AzarPalette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(nick, style: Theme.of(context).textTheme.bodyLarge),
                  if (role != 'user') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(border: Border.all(color: AzarPalette.accent)),
                      child: Text(role.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AzarPalette.accent)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(_short(id),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
              ],
            ),
          ),
          if (banned)
            _MiniBtn(label: 'Yasağı Kaldır', onTap: () async {
              await AdminRepo.instance.unbanUser(id);
              await onChanged();
            })
          else
            _MiniBtn(label: 'Yasakla', danger: true, onTap: () => _banDialog(context)),
        ],
      ),
    );
  }
}

class _DurChip extends StatelessWidget {
  const _DurChip({required this.label, required this.on, required this.tap});
  final String label;
  final bool on;
  final VoidCallback tap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? AzarPalette.accent : AzarPalette.surfaceUp,
            border: Border.all(color: on ? AzarPalette.accent : AzarPalette.line),
          ),
          child: Text(label,
              style: TextStyle(color: on ? AzarPalette.bg : AzarPalette.text, fontSize: 13)),
        ),
      );
}

// ============================================================================
// Bans tab
// ============================================================================

class _BansTab extends StatefulWidget {
  const _BansTab();

  @override
  State<_BansTab> createState() => _BansTabState();
}

class _BansTabState extends State<_BansTab> {
  late Future<List<Map<String, dynamic>>> _future = AdminRepo.instance.activeBans();

  Future<void> _refresh() async {
    setState(() => _future = AdminRepo.instance.activeBans());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const _Loading();
          if (snap.hasError) return _ErrorBox(message: '${snap.error}');
          final bans = snap.data ?? const [];
          if (bans.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Text('Aktif yasak yok.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim))),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) => _BanTile(ban: bans[i], onChanged: _refresh),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemCount: bans.length,
          );
        },
      ),
    );
  }
}

class _BanTile extends StatelessWidget {
  const _BanTile({required this.ban, required this.onChanged});
  final Map<String, dynamic> ban;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final userId = ban['user_id'] as String?;
    final reason = (ban['reason'] as String?) ?? '-';
    final until = ban['until'] == null ? null : DateTime.tryParse(ban['until'] as String);
    final source = (ban['source'] as String?) ?? 'manual';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AzarPalette.surface, border: Border.all(color: AzarPalette.danger)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  '${_short(userId ?? "-")} • ${source.toUpperCase()}'
                  '${until != null ? " • ${until.toLocal().toString().substring(0, 16)}" : " • kalıcı"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          _MiniBtn(label: 'Kaldır', onTap: () async {
            if (userId != null) {
              await AdminRepo.instance.unbanUser(userId);
              await onChanged();
            }
          }),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared bits
// ============================================================================

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.label, required this.onTap, this.danger = false});
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AzarPalette.danger : AzarPalette.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: color)),
        child: Text(label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, letterSpacing: 1.0)),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AzarPalette.accent, strokeWidth: 2)));
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: AzarPalette.danger)),
          child: Text(message, style: const TextStyle(color: AzarPalette.danger)),
        ),
      );
}

String _short(String id) => id.length > 12 ? '${id.substring(0, 8)}…${id.substring(id.length - 4)}' : id;

String _relative(DateTime dt) {
  final d = DateTime.now().toUtc().difference(dt.toUtc());
  if (d.inMinutes < 1) return 'az önce';
  if (d.inMinutes < 60) return '${d.inMinutes}dk';
  if (d.inHours   < 24) return '${d.inHours}sa';
  return '${d.inDays}g';
}
