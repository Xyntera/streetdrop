import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/wallet_provider.dart';
import '../services/api_service.dart';
import 'claim_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override ConsumerState<MapScreen> createState() => _MapState();
}

class _MapState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  final _mapCtrl = MapController();
  Position? _pos;
  List<Map<String, dynamic>> _drops = [];
  Map<String, dynamic>? _activeCard;

  late final AnimationController _pinPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  late final AnimationController _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  late final Animation<double> _cardAnim   = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic);

  @override void initState() { super.initState(); _init(); }
  @override void dispose() { _pinPulse.dispose(); _cardCtrl.dispose(); super.dispose(); }

  Future<void> _init() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() => _pos = pos);
      _loadDrops(pos.latitude, pos.longitude);
      Geolocator.getPositionStream(locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10))
          .listen((p) { if (mounted) setState(() => _pos = p); });
    } catch (_) {}
  }

  Future<void> _loadDrops(double lat, double lng) async {
    try {
      final raw = await ApiService.getNearbyDrops(lat, lng, 5.0);
      if (!mounted) return;
      setState(() => _drops = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {}
  }

  double _dist(double lat, double lng) {
    if (_pos == null) return 9999;
    return Geolocator.distanceBetween(_pos!.latitude, _pos!.longitude, lat, lng);
  }

  void _showCard(Map<String, dynamic> d) { setState(() => _activeCard = d); _cardCtrl.forward(from: 0); }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final center = _pos != null ? LatLng(_pos!.latitude, _pos!.longitude) : const LatLng(10.85, 76.27);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(initialCenter: center, initialZoom: 15.5),
          children: [
            TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a','b','c','d'], userAgentPackageName: 'com.streetdrop.app'),
            MarkerLayer(markers: [
              ..._drops.map((d) {
                final lat = (d['lat'] as num).toDouble();
                final lng = (d['lng'] as num).toDouble();
                return Marker(point: LatLng(lat, lng), width: 100, height: 60,
                  child: GestureDetector(onTap: () => _showCard(d),
                    child: _DropPin(label: d['name']?.toString() ?? 'Drop')));
              }),
              if (_pos != null) Marker(point: LatLng(_pos!.latitude, _pos!.longitude), width: 48, height: 48,
                child: AnimatedBuilder(animation: _pinPulse, builder: (_, __) => Stack(alignment: Alignment.center, children: [
                  Container(width: 40 + 8*_pinPulse.value, height: 40 + 8*_pinPulse.value,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.15*(1-_pinPulse.value)))),
                  Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle,
                      color: AppColors.primary, border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 10)])),
                ]))),
            ]),
          ],
        ),
        Positioned(top: 0, left: 0, right: 0, height: 130,
          child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xDD050510), Colors.transparent])))),
        SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            GlassCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), radius: 14,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text('${_drops.length} drops nearby', style: const TextStyle(fontFamily: 'Outfit',
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ])),
            const Spacer(),
            if (wallet.address != null) WalletPill(address: wallet.address!,
                onTap: () => ref.read(walletProvider.notifier).disconnect()),
          ]))),
        Positioned(bottom: 0, left: 0, right: 0,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_activeCard != null) AnimatedBuilder(animation: _cardAnim,
              builder: (_, child) => Transform.translate(offset: Offset(0, 20*(1-_cardAnim.value)),
                child: Opacity(opacity: _cardAnim.value, child: child)),
              child: _DropCard(drop: _activeCard!, distance: _dist(
                (_activeCard!['lat'] as num).toDouble(), (_activeCard!['lng'] as num).toDouble()),
                onClaim: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                    ClaimScreen(drop: _activeCard!, userPosition: _pos))),
                onClose: () { _cardCtrl.reverse().then((_) { if (mounted) setState(() => _activeCard = null); }); })),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 90),
          ])),
        Positioned(right: 16, bottom: MediaQuery.of(context).padding.bottom + 100,
          child: GlassCard(padding: const EdgeInsets.all(14), radius: 16,
            onTap: () { if (_pos != null) _mapCtrl.move(LatLng(_pos!.latitude, _pos!.longitude), 15.5); },
            child: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 22))),
      ]),
    );
  }
}

class _DropPin extends StatelessWidget {
  final String label;
  const _DropPin({required this.label});
  @override Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 11,
          fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
    CustomPaint(size: const Size(12, 7), painter: _TailPainter()),
  ]);
}

class _TailPainter extends CustomPainter {
  @override void paint(Canvas c, Size s) {
    c.drawPath(Path()..moveTo(0,0)..lineTo(s.width,0)..lineTo(s.width/2,s.height)..close(),
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primaryDark]).createShader(Rect.fromLTWH(0,0,12,7)));
  }
  @override bool shouldRepaint(_) => false;
}

class _DropCard extends StatelessWidget {
  final Map<String, dynamic> drop;
  final double distance;
  final VoidCallback onClaim, onClose;
  const _DropCard({required this.drop, required this.distance, required this.onClaim, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final inRange = distance <= ((drop['radius_meters'] as num?)?.toDouble() ?? 100);
    final claimed = (drop['claimed_count'] as num?)?.toInt() ?? 0;
    final supply  = (drop['supply'] as num?)?.toInt() ?? 1;
    return Padding(padding: const EdgeInsets.fromLTRB(16,0,16,8),
      child: GlassCard(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2), color: const Color(0x26FFFFFF)))),
            GestureDetector(onTap: onClose, child: const Icon(Icons.close_rounded, color: AppColors.textDim, size: 20)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                    color: inRange ? AppColors.teal.withValues(alpha: 0.10) : AppColors.danger.withValues(alpha: 0.08),
                    border: Border.all(color: inRange ? AppColors.teal.withValues(alpha: 0.25) : AppColors.danger.withValues(alpha: 0.2))),
                  child: Text(inRange ? 'In Range' : '${distance.round()}m away',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.w700,
                        color: inRange ? AppColors.teal : AppColors.danger))),
                const SizedBox(width: 8),
                Text('${supply-claimed} left', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.textDim)),
              ]),
              const SizedBox(height: 10),
              Text(drop['name']?.toString() ?? 'Drop', style: const TextStyle(fontFamily: 'Outfit',
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(drop['description']?.toString() ?? '', style: const TextStyle(fontFamily: 'Outfit',
                  fontSize: 13, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 16),
            Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primaryDark.withValues(alpha: 0.12)]),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
              child: const Center(child: Text('🎨', style: TextStyle(fontSize: 36)))),
          ]),
          const SizedBox(height: 14),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: Stack(children: [
            Container(height: 6, color: const Color(0x14FFFFFF)),
            FractionallySizedBox(widthFactor: supply > 0 ? claimed/supply : 0.0,
              child: Container(height: 6, decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent])))),
          ])),
          const SizedBox(height: 14),
          GestureDetector(onTap: inRange ? onClaim : null,
            child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 50,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                gradient: inRange ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark]) : null,
                color: inRange ? null : const Color(0x14FFFFFF),
                boxShadow: inRange ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 4))] : null),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(inRange ? Icons.download_rounded : Icons.lock_rounded,
                    color: inRange ? Colors.white : AppColors.textDim, size: 18),
                const SizedBox(width: 8),
                Text(inRange ? 'Claim Drop' : 'Get Closer to Claim',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700,
                        color: inRange ? Colors.white : AppColors.textDim)),
              ]))),
        ])));
  }
}
