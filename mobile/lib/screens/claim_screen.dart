import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/wallet_provider.dart';
import '../services/api_service.dart';

class ClaimScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> drop;
  final Position? userPosition;
  const ClaimScreen({super.key, required this.drop, this.userPosition});
  @override ConsumerState<ClaimScreen> createState() => _ClaimState();
}

class _ClaimState extends ConsumerState<ClaimScreen> with TickerProviderStateMixin {
  Position? _pos;
  double? _distance;
  String _phase = 'idle';
  Map<String, dynamic>? _mintResult;
  String _errMsg = '';
  StreamSubscription<Position>? _locSub;

  late final AnimationController _glowCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  late final AnimationController _solanaCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  late final AnimationController _successCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void initState() {
    super.initState();
    _pos = widget.userPosition;
    if (_pos != null) _calcDist();
    _locSub = Geolocator.getPositionStream(locationSettings:
        const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2))
        .listen((p) { if (mounted) { setState(() => _pos = p); _calcDist(); } });
  }
  @override void dispose() { _glowCtrl.dispose(); _solanaCtrl.dispose(); _successCtrl.dispose(); _locSub?.cancel(); super.dispose(); }

  void _calcDist() {
    if (_pos == null) return;
    final lat = (widget.drop['lat'] as num).toDouble();
    final lng = (widget.drop['lng'] as num).toDouble();
    setState(() => _distance = Geolocator.distanceBetween(_pos!.latitude, _pos!.longitude, lat, lng));
  }

  bool get _inRange => _distance != null && _distance! <= ((widget.drop['radius_meters'] as num?)?.toDouble() ?? 100);

  Future<void> _claim() async {
    final wallet = ref.read(walletProvider);
    if (!_inRange || wallet.address == null) return;
    setState(() => _phase = 'minting');
    try {
      final v = await ApiService.verifyLocation(dropId: widget.drop['id'] as String,
          lat: _pos!.latitude, lng: _pos!.longitude, wallet: wallet.address!);
      if (v['claimToken'] == null) throw Exception(v['error'] ?? 'Verification failed');
      final m = await ApiService.mintNFT(v['claimToken'] as String);
      if (m['success'] != true) throw Exception(m['error'] ?? 'Mint failed');
      setState(() { _mintResult = m; _phase = 'success'; });
      _successCtrl.forward();
    } catch (e) {
      setState(() { _phase = 'error'; _errMsg = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: switch (_phase) {
        'minting' => _mintingView(),
        'success' => _successView(),
        _ => _mainView(),
      },
    );
  }

  Widget _mainView() {
    final supply  = (widget.drop['supply'] as num?)?.toInt() ?? 1;
    final claimed = (widget.drop['claimed_count'] as num?)?.toInt() ?? 0;
    final wallet  = ref.watch(walletProvider);
    return Stack(children: [
      const AnimatedOrbs(colors: [AppColors.primary, AppColors.teal], maxSize: 280),
      SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16,8,16,0),
          child: Row(children: [
            GlassCard(padding: const EdgeInsets.all(10), radius: 14,
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18)),
            const Spacer(),
            if (wallet.address != null) WalletPill(address: wallet.address!),
          ])),
        Expanded(child: SingleChildScrollView(physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Container(width: double.infinity, height: 200, margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primaryDark.withValues(alpha: 0.12)]),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
              child: const Center(child: Text('🎨', style: TextStyle(fontSize: 80)))).animate()
                  .fadeIn(duration: 400.ms).scale(begin: Offset(0.9,0.9), end: Offset(1,1)),
            Text(widget.drop['name']?.toString() ?? 'Drop', textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary, letterSpacing: -0.8)).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 6),
            Text(widget.drop['description']?.toString() ?? '', textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              maxLines: 3, overflow: TextOverflow.ellipsis).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 32),
            ProximityRing(distance: _distance, radius: (widget.drop['radius_meters'] as num?)?.toDouble() ?? 100)
                .animate().fadeIn(delay: 200.ms).scale(begin: Offset(0.8,0.8)),
            const SizedBox(height: 28),
            GlassCard(padding: const EdgeInsets.all(16), child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Claimed', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.textDim)),
                Text('$claimed / $supply', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: Stack(children: [
                Container(height: 6, color: const Color(0x14FFFFFF)),
                AnimatedFractionallySizedBox(widthFactor: supply > 0 ? claimed/supply : 0,
                  duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic,
                  child: Container(height: 6, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent])))),
              ])),
            ])).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: 16),
            if (_phase == 'error') Container(width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                color: AppColors.danger.withValues(alpha: 0.08), border: Border.all(color: AppColors.danger.withValues(alpha: 0.25))),
              child: Text(_errMsg, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.danger)))
                  .animate().fadeIn().shakeX(hz: 3, amount: 4),
            const SizedBox(height: 8),
            LiquidButton(
              label: _inRange ? 'CLAIM DROP' : '${_distance?.round() ?? "..."}m — Get Closer',
              icon: _inRange ? Icons.download_done_rounded : Icons.lock_rounded,
              color: _inRange ? AppColors.primary : AppColors.textHint,
              textColor: _inRange ? Colors.white : AppColors.textDim,
              height: 64, fontSize: 17,
              onPressed: _inRange ? _claim : null,
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 60),
          ]),
        )),
      ])),
    ]);
  }

  Widget _mintingView() => Stack(children: [
    const AnimatedOrbs(colors: [AppColors.primary, AppColors.accent], maxSize: 300),
    Center(child: Padding(padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedBuilder(animation: _solanaCtrl, builder: (_, __) => Transform.rotate(
          angle: _solanaCtrl.value * 2 * math.pi,
          child: Container(width: 96, height: 96,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0.08)]),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 2)),
            child: const Center(child: Text('◎', style: TextStyle(fontSize: 40, color: AppColors.primary)))))).animate().fadeIn().scale(begin: Offset(0.5,0.5)),
        const SizedBox(height: 32),
        const Text('Minting your NFT...', style: TextStyle(fontFamily: 'Outfit', fontSize: 22,
            fontWeight: FontWeight.w800, color: AppColors.textPrimary)).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 12),
        const Text('Signing transaction on Solana', style: TextStyle(fontFamily: 'Outfit',
            fontSize: 14, color: AppColors.textSecondary)).animate().fadeIn(delay: 300.ms),
      ]))),
  ]);

  Widget _successView() {
    final res = _mintResult!;
    return Stack(children: [
      const AnimatedOrbs(colors: [AppColors.accent, AppColors.teal, AppColors.primary], maxSize: 320),
      SafeArea(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(animation: _successCtrl,
          builder: (_, child) => FadeTransition(opacity: _successCtrl,
            child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                .animate(CurvedAnimation(parent: _successCtrl, curve: Curves.easeOutCubic)), child: child!)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const SizedBox(height: 20),
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text('YOU GOT IT!', style: TextStyle(fontFamily: 'Outfit', fontSize: 42,
                fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -1.5)),
            const SizedBox(height: 6),
            Text('Claim #${res['claimNumber']} of ${res['totalSupply']}',
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.teal)),
            const SizedBox(height: 32),
            GlassCard(glowColor: AppColors.primary, child: Column(children: [
              Container(height: 280, width: double.infinity,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primaryDark.withValues(alpha: 0.10)])),
                child: Stack(alignment: Alignment.center, children: [
                  const Text('🎨', style: TextStyle(fontSize: 90)),
                  Positioned(top: 12, right: 12, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: Colors.black54),
                    child: Text('#${res['claimNumber']}', style: const TextStyle(fontFamily: 'Outfit',
                        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)))),
                ])),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.drop['name']?.toString() ?? 'NFT Drop',
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 18,
                        fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Row(children: [
                    Icon(Icons.location_on_rounded, color: AppColors.teal, size: 14),
                    SizedBox(width: 4),
                    Text('Just now', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.textDim)),
                  ]),
                ]),
                const Text('cNFT', style: TextStyle(fontFamily: 'Outfit', fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.accent)),
              ]),
            ])),
            const SizedBox(height: 20),
            LiquidButton(label: 'Find More Drops 📍', height: 58, fontSize: 16,
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst)),
            const SizedBox(height: 40),
          ]),
        ))),
    ]);
  }
}
