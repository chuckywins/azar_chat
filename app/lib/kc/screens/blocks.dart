import 'package:flutter/material.dart';

import '../../services/block_service.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../tokens.dart';

class KCBlocksScreen extends StatefulWidget {
  const KCBlocksScreen({super.key});
  @override
  State<KCBlocksScreen> createState() => _KCBlocksScreenState();
}

class _KCBlocksScreenState extends State<KCBlocksScreen> {
  late Future<List<BlockEntry>> _future = BlockService.instance.myBlocks();

  Future<void> _refresh() async {
    setState(() => _future = BlockService.instance.myBlocks());
    await _future;
  }

  Future<void> _unblock(BlockEntry e) async {
    await BlockService.instance.unblock(e.blockedId);
    await _refresh();
    if (!mounted) return;
    KCContext.instance.toast('Engel kaldırıldı');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KC.bg,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: SizedBox(width: 38, height: 38,
                child: const Icon(Icons.chevron_left_rounded, color: KC.text, size: 24)),
            ),
            const SizedBox(width: 4),
            Text('Engellenenler', style: kcSora(20, w: FontWeight.w700)),
          ]),
        ),
        Expanded(child: RefreshIndicator(
          color: KC.accent, onRefresh: _refresh,
          child: FutureBuilder<List<BlockEntry>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4));
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return ListView(children: [
                  const SizedBox(height: 80),
                  Center(child: Container(width: 64, height: 64,
                    decoration: BoxDecoration(color: KC.surface2, borderRadius: BorderRadius.circular(18)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.block_rounded, color: KC.muted, size: 26))),
                  const SizedBox(height: 14),
                  Center(child: Text('Engellediğin kimse yok', style: kcManrope(14, color: KC.muted))),
                  const SizedBox(height: 8),
                  Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Text('Görüşme sırasında karşı tarafı engelleyebilir, daha sonra burada yönetebilirsin.',
                      textAlign: TextAlign.center, style: kcManrope(13, color: KC.muted, height: 1.4)))),
                ]);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final e = list[i];
                  final nick = e.blockedNickname ?? 'Kullanıcı';
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: KC.surface,
                        borderRadius: BorderRadius.circular(14), border: Border.all(color: KC.border)),
                    child: Row(children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(gradient: KC.grad, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(nick.isEmpty ? '?' : nick.substring(0, 1).toUpperCase(),
                            style: kcSora(16, w: FontWeight.w700, color: Colors.white, height: 1))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nick, style: kcSora(14.5, w: FontWeight.w700)),
                        if (e.reason != null && e.reason!.isNotEmpty)
                          Text(e.reason!, style: kcManrope(12, color: KC.muted)),
                      ])),
                      GestureDetector(
                        onTap: () => _unblock(e),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(border: Border.all(color: KC.border),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('Kaldır', style: kcManrope(12.5, w: FontWeight.w700, color: KC.text)),
                        ),
                      ),
                    ]),
                  );
                },
              );
            },
          ),
        )),
      ])),
    );
  }
}
