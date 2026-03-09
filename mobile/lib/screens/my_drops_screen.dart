import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/wallet_provider.dart';
import '../services/api_service.dart';

class MyDropsScreen extends ConsumerStatefulWidget {
  const MyDropsScreen({super.key});
  @override ConsumerState<MyDropsScreen> createState() => _State();
}

class _State extends ConsumerState<MyDropsScreen> {
  List<Map<String, dynamic>> _claims = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final wallet = ref.read(walletProvider);
    if (wallet.address == null) { setState(() => _loading = false); return; }
    try {
      final raw = await ApiService.getWalletClaims(wallet.address!);
      if (mounted) setState(() { _claims = raw.map((e) => Map<String,dynamic>.from(e as Map)).toList(); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const AnimatedOrbs(colors: [AppColors.primary, AppColors.teal], maxSize: 220),
        SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(24,16,24,0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('My Collection', style: TextStyle(fontFamily: 'Outfit', fontSize: 28,
                    fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.8)),
                if (!_loading) Text('${_claims.length} NFT${_claims.length != 1 ? "s" : ""} claimed',
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary)),
              ]),
              const Spacer(),
              Consumer(builder: (_, ref, __) {
                final w = ref.watch(walletProvider);
                return w.address != null ? WalletPill(address: w.address!) : const SizedBox();
              }),
            ])),
          const SizedBox(height: 20),
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
            : _claims.isEmpty ? _empty() : _grid()),
        ])),
      ]),
    );
  }

  Widget _empty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('🚶', style: TextStyle(fontSize: 64)).animate().fadeIn(duration: 500.ms).scale(begin: Offset(0.5,0.5)),
    const SizedBox(height: 16),
    const Text('No drops yet', style: TextStyle(fontFamily: 'Outfit', fontSize: 22,
        fontWeight: FontWeight.w800, color: AppColors.textPrimary)).animate().fadeIn(delay: 100.ms),
    const SizedBox(height: 8),
    const Text('Go explore and claim your first drop!',
        style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textDim)).animate().fadeIn(delay: 200.ms),
  ]));

  Widget _grid() => RefreshIndicator(
    color: AppColors.primary, backgroundColor: const Color(0xFF0E0E26), onRefresh: _load,
    child: GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16,0,16,100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.72),
      itemCount: _claims.length,
      itemBuilder: (_, i) {
        final c = _claims[i];
        final d = c['drops'] as Map?;
        return _NftCard(claim: c, drop: d, index: i)
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0);
      }),
  );
}

class _NftCard extends StatefulWidget {
  final Map<String,dynamic> claim;
  final Map? drop;
  final int index;
  const _NftCard({required this.claim, required this.drop, required this.index});
  @override State<_NftCard> createState() => _NftCardState();
}

class _NftCardState extends State<_NftCard> with SingleTickerProviderStateMixin {
  late final AnimationController _h = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  @override void dispose() { _h.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final name = widget.drop?['name']?.toString() ?? 'Drop #${widget.index+1}';
    final raw  = widget.claim['claimed_at'] as String?;
    final date = raw != null ? DateTime.tryParse(raw) : null;
    final ds   = date != null ? '${date.day}/${date.month}/${date.year}' : 'Unknown';
    return GestureDetector(
      onTapDown: (_) => _h.forward(), onTapUp: (_) => _h.reverse(), onTapCancel: () => _h.reverse(),
      child: AnimatedBuilder(animation: _h, builder: (_, child) => Transform.scale(scale: 1-_h.value*0.04, child: child),
        child: GlassCard(padding: EdgeInsets.zero, radius: 20, glowColor: AppColors.primary,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              child: Container(height: 150, width: double.infinity,
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppColors.primary.withValues(alpha: 0.25), AppColors.primaryDark.withValues(alpha: 0.15)])),
                child: Stack(children: [
                  const Center(child: Text('🎨', style: TextStyle(fontSize: 52))),
                  Positioned(top: 10, right: 10, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                        color: AppColors.primary.withValues(alpha: 0.8)),
                    child: Text('#${widget.index+1}', style: const TextStyle(fontFamily: 'Outfit',
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))),
                ]))),
            Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontFamily: 'Outfit', fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.location_on_rounded, color: AppColors.teal, size: 12),
                const SizedBox(width: 3),
                Text(ds, style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: AppColors.textDim)),
              ]),
              const SizedBox(height: 4),
              const Text('cNFT · Solana', style: TextStyle(fontFamily: 'Outfit', fontSize: 11,
                  fontWeight: FontWeight.w600, color: AppColors.accent)),
            ])),
          ])),
      ),
    );
  }
}
