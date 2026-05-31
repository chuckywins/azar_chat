import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.instance;
    if (!auth.isAdmin && !auth.isModerator) {
      return Scaffold(
        body: AzarBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: AzarPalette.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.lock_outline_rounded, color: AzarPalette.danger, size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text('Yetkin yok', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Bu sayfa sadece moderator/admin role\'lü kullanıcılar içindir.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim),
                  ),
                  const SizedBox(height: 24),
                  GhostButton(label: 'GERİ DÖN', icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AzarBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AzarPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AzarPalette.line),
                ),
                child: TabBar(
                  controller: _tabs,
                  isScrollable: false,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    gradient: AzarPalette.brandGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(3),
                  labelColor: Colors.white,
                  unselectedLabelColor: AzarPalette.textDim,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                  tabs: const [
                    Tab(text: 'PANO'),
                    Tab(text: 'RAPORLAR'),
                    Tab(text: 'KULLANICILAR'),
                    Tab(text: 'YASAKLAR'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AzarPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AzarPalette.line),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back_rounded, color: AzarPalette.text, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: AzarPalette.brandGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text('Admin Panel', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: -0.3)),
        ],
      ),
    );
  }
}

// ============================================================================
// Dashboard
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
      color: AzarPalette.primary,
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
              if (snap.connectionState == ConnectionState.waiting) return const _Loading();
              if (snap.hasError) return _ErrorBox(message: '${snap.error}');
              final c = snap.data ?? {};
              return Column(
                children: [
                  _StatCard(
                    icon: Icons.people_alt_rounded,
                    color: AzarPalette.secondary,
                    label: 'Toplam Kullanıcı',
                    value: '${c['users'] ?? 0}',
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1),
                  const SizedBox(height: 12),
                  _StatCard(
                    icon: Icons.flag_rounded,
                    color: AzarPalette.primary,
                    label: 'Bekleyen Rapor',
                    value: '${c['pending_reports'] ?? 0}',
                    accent: (c['pending_reports'] ?? 0) > 0,
                  ).animate().fadeIn(duration: 350.ms, delay: 80.ms).slideY(begin: 0.1),
                  const SizedBox(height: 12),
                  _StatCard(
                    icon: Icons.gavel_rounded,
                    color: AzarPalette.danger,
                    label: 'Aktif Yasak',
                    value: '${c['active_bans'] ?? 0}',
                  ).animate().fadeIn(duration: 350.ms, delay: 160.ms).slideY(begin: 0.1),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text('HIZLI İŞLEMLER',
              style: const TextStyle(color: AzarPalette.textFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(
            'Üst sekmelerden raporları, kullanıcıları ve yasakları yönet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.accent = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AzarPalette.surfaceGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent ? color : AzarPalette.line, width: accent ? 1.4 : 1),
        boxShadow: accent
            ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 24, spreadRadius: -4)]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(color: AzarPalette.textDim, fontSize: 12.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: AzarPalette.text, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Reports
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
      color: AzarPalette.primary,
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const _Loading();
          if (snap.hasError) return _ErrorBox(message: '${snap.error}');
          final reports = snap.data ?? const [];
          if (reports.isEmpty) return _Empty(icon: Icons.flag_outlined, text: 'Bekleyen rapor yok');
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
            ).animate().fadeIn(duration: 300.ms, delay: (i * 40).ms).slideY(begin: 0.05),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
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
      decoration: BoxDecoration(
        gradient: AzarPalette.surfaceGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AzarPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ReasonChip(reason: reason),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _short(reportedId),
                  style: const TextStyle(color: AzarPalette.textDim, fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              if (createdAt != null)
                Text(_relative(createdAt), style: const TextStyle(color: AzarPalette.textFaint, fontSize: 11.5)),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AzarPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(note, style: const TextStyle(color: AzarPalette.text, fontSize: 13.5, height: 1.4)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: GhostButton(label: 'Reddet', onTap: onDismiss, height: 42)),
              const SizedBox(width: 8),
              Expanded(
                child: GradientButton(
                  label: 'Aksiyon',
                  onTap: onAction,
                  height: 42,
                  gradient: const LinearGradient(colors: [AzarPalette.danger, Color(0xFFFF7A8A)]),
                ),
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
  static const _labels = {'nsfw':'NSFW','harassment':'TACİZ','spam':'SPAM','minor':'KÜÇÜK','other':'DİĞER'};
  static const _colors = {
    'nsfw': AzarPalette.danger,
    'harassment': AzarPalette.danger,
    'spam': AzarPalette.warning,
    'minor': AzarPalette.danger,
    'other': AzarPalette.textDim,
  };
  @override
  Widget build(BuildContext context) {
    final c = _colors[reason] ?? AzarPalette.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(_labels[reason] ?? reason.toUpperCase(),
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }
}

// ============================================================================
// Users
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
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _refresh(),
            style: const TextStyle(color: AzarPalette.text, fontSize: 14),
            cursorColor: AzarPalette.primary,
            decoration: InputDecoration(
              hintText: 'Nickname ara, Enter',
              hintStyle: const TextStyle(color: AzarPalette.textFaint),
              prefixIcon: const Icon(Icons.search_rounded, color: AzarPalette.textDim, size: 18),
              filled: true,
              fillColor: AzarPalette.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AzarPalette.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AzarPalette.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AzarPalette.primary, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AzarPalette.primary,
            onRefresh: _refresh,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const _Loading();
                if (snap.hasError) return _ErrorBox(message: '${snap.error}');
                final users = snap.data ?? const [];
                if (users.isEmpty) return _Empty(icon: Icons.person_outline_rounded, text: 'Kullanıcı yok');
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemBuilder: (_, i) => _UserTile(profile: users[i], onChanged: _refresh)
                      .animate().fadeIn(duration: 300.ms, delay: (i * 30).ms),
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AzarPalette.surfaceGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AzarPalette.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Yasakla', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: AzarPalette.text),
                cursorColor: AzarPalette.primary,
                decoration: InputDecoration(
                  labelText: 'Sebep',
                  labelStyle: const TextStyle(color: AzarPalette.textDim),
                  filled: true,
                  fillColor: AzarPalette.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AzarPalette.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AzarPalette.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AzarPalette.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              StatefulBuilder(builder: (ctx, set) {
                return Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _DurChip(label: '1 saat',  on: duration == const Duration(hours: 1),  tap: () => set(() => duration = const Duration(hours: 1))),
                    _DurChip(label: '24 saat', on: duration == const Duration(hours: 24), tap: () => set(() => duration = const Duration(hours: 24))),
                    _DurChip(label: '7 gün',   on: duration == const Duration(days: 7),   tap: () => set(() => duration = const Duration(days: 7))),
                    _DurChip(label: '30 gün',  on: duration == const Duration(days: 30),  tap: () => set(() => duration = const Duration(days: 30))),
                  ],
                );
              }),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: GhostButton(label: 'Vazgeç', onTap: () => Navigator.pop(ctx), height: 44)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientButton(
                      label: 'YASAKLA',
                      onTap: () async {
                        await AdminRepo.instance.banUser(
                          userId: profile['id'] as String,
                          reason: reasonCtrl.text,
                          duration: duration,
                          createdBy: me,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await onChanged();
                      },
                      gradient: const LinearGradient(colors: [AzarPalette.danger, Color(0xFFFF7A8A)]),
                      height: 44,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        gradient: AzarPalette.surfaceGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: banned ? AzarPalette.danger.withValues(alpha: 0.6) : AzarPalette.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: banned
                  ? const LinearGradient(colors: [AzarPalette.danger, Color(0xFFFF7A8A)])
                  : AzarPalette.brandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              nick.isNotEmpty ? nick.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(nick, style: const TextStyle(color: AzarPalette.text, fontSize: 14.5, fontWeight: FontWeight.w600))),
                    if (role != 'user') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AzarPalette.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(role.toUpperCase(),
                            style: const TextStyle(color: AzarPalette.secondary, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(_short(id), style: const TextStyle(color: AzarPalette.textFaint, fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          banned
              ? GhostButton(label: 'Yasağı Kaldır', onTap: () async {
                  await AdminRepo.instance.unbanUser(id);
                  await onChanged();
                }, height: 36)
              : GestureDetector(
                  onTap: () => _banDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AzarPalette.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AzarPalette.danger.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Yasakla',
                        style: TextStyle(color: AzarPalette.danger, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                  ),
                ),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: on ? AzarPalette.brandGradient : null,
            color: on ? null : AzarPalette.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? Colors.transparent : AzarPalette.line),
          ),
          child: Text(label, style: TextStyle(color: on ? Colors.white : AzarPalette.text, fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
        ),
      );
}

// ============================================================================
// Bans
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
      color: AzarPalette.primary,
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const _Loading();
          if (snap.hasError) return _ErrorBox(message: '${snap.error}');
          final bans = snap.data ?? const [];
          if (bans.isEmpty) return _Empty(icon: Icons.gavel_outlined, text: 'Aktif yasak yok');
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemBuilder: (_, i) => _BanTile(ban: bans[i], onChanged: _refresh)
                .animate().fadeIn(duration: 300.ms, delay: (i * 30).ms),
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
      decoration: BoxDecoration(
        gradient: AzarPalette.surfaceGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AzarPalette.danger.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AzarPalette.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.gavel_rounded, color: AzarPalette.danger, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason, style: const TextStyle(color: AzarPalette.text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${_short(userId ?? "-")} • ${source.toUpperCase()}'
                  '${until != null ? " • ${until.toLocal().toString().substring(0, 16)}" : " • kalıcı"}',
                  style: const TextStyle(color: AzarPalette.textFaint, fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GhostButton(
            label: 'Kaldır',
            height: 36,
            onTap: () async {
              if (userId != null) {
                await AdminRepo.instance.unbanUser(userId);
                await onChanged();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared
// ============================================================================

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AzarPalette.primary, strokeWidth: 2.4)));
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AzarPalette.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AzarPalette.danger.withValues(alpha: 0.4)),
          ),
          child: Text(message, style: const TextStyle(color: AzarPalette.danger, fontSize: 13)),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AzarPalette.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AzarPalette.textDim, size: 24),
          ),
        ),
        const SizedBox(height: 14),
        Center(child: Text(text, style: const TextStyle(color: AzarPalette.textDim, fontSize: 14))),
      ],
    );
  }
}

String _short(String id) => id.length > 12 ? '${id.substring(0, 8)}…${id.substring(id.length - 4)}' : id;

String _relative(DateTime dt) {
  final d = DateTime.now().toUtc().difference(dt.toUtc());
  if (d.inMinutes < 1) return 'az önce';
  if (d.inMinutes < 60) return '${d.inMinutes}dk';
  if (d.inHours < 24)   return '${d.inHours}sa';
  return '${d.inDays}g';
}
