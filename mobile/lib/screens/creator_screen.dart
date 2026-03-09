import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/wallet_provider.dart';
import '../services/api_service.dart';

class CreatorScreen extends ConsumerStatefulWidget {
  const CreatorScreen({super.key});
  @override ConsumerState<CreatorScreen> createState() => _CreatorState();
}

class _CreatorState extends ConsumerState<CreatorScreen> with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _image;
  int _supply = 100;
  double _radius = 50;
  String _duration = '24h';
  Position? _location;
  bool _loading = false, _success = false;

  @override void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _pick() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (p != null) setState(() => _image = File(p.path));
  }

  Future<void> _useLoc() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _snack('Please enable location services');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) {
      _snack('Location permission denied');
      return;
    }
    if (perm == LocationPermission.deniedForever) {
      _snack('Location permission permanently denied — enable in Settings');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _location = pos);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _snack('Could not get location: $e');
    }
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) { _snack('Enter a drop name'); return; }
    if (_location == null) { _snack('Tap "Use My Location" first'); return; }
    if (_image == null)    { _snack('Upload artwork first'); return; }
    final wallet = ref.read(walletProvider);
    if (wallet.address == null) { _snack('Connect wallet first'); return; }
    setState(() => _loading = true);
    try {
      final dMap = {'24h':1,'3d':3,'7d':7,'custom':1};
      final endsAt = DateTime.now().add(Duration(days: dMap[_duration]!)).toIso8601String();
      final res = await ApiService.createDrop(
        name: _nameCtrl.text.trim(), description: _descCtrl.text.trim(),
        creatorWallet: wallet.address!, lat: _location!.latitude, lng: _location!.longitude,
        radiusMeters: _radius.round(), supply: _supply, endsAt: endsAt, image: _image!);
      if (res['drop'] != null) {
        setState(() { _loading = false; _success = true; });
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 2400));
        if (mounted) setState(() { _success = false; _image = null; _location = null; _nameCtrl.clear(); _descCtrl.clear(); });
      } else throw Exception(res['error'] ?? 'Unknown error');
    } catch (e) {
      setState(() => _loading = false);
      _snack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
    backgroundColor: AppColors.danger.withValues(alpha: 0.9),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    margin: const EdgeInsets.all(16)));

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const AnimatedOrbs(colors: [AppColors.primary, AppColors.accent], maxSize: 250),
        SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16,8,16,0),
            child: Row(children: [
              const Row(children: [
                Icon(Icons.add_location_alt_rounded, color: AppColors.primary, size: 22),
                SizedBox(width: 10),
                Text('New Drop', style: TextStyle(fontFamily: 'Outfit', fontSize: 20,
                    fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ]),
              const Spacer(),
              if (wallet.address != null) WalletPill(address: wallet.address!),
            ])),
          Expanded(child: SingleChildScrollView(physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _uploadBox().animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),
              _lbl('Drop Name'), const SizedBox(height: 8),
              _inp(_nameCtrl, 'Enter drop name').animate().fadeIn(delay: 50.ms),
              const SizedBox(height: 20),
              _lbl('Description'), const SizedBox(height: 8),
              _area(_descCtrl, 'Tell us about your NFT drop...').animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 20),
              GlassCard(padding: const EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Supply', style: TextStyle(fontFamily: 'Outfit', fontSize: 16,
                        fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Max number of claims', style: TextStyle(fontFamily: 'Outfit',
                        fontSize: 12, color: AppColors.textDim)),
                  ]),
                  Row(children: [
                    _cBtn(Icons.remove, () => setState(() => _supply = (_supply-10).clamp(1,9999))),
                    const SizedBox(width: 16),
                    Text('$_supply', style: const TextStyle(fontFamily: 'Outfit', fontSize: 22,
                        fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    const SizedBox(width: 16),
                    _cBtn(Icons.add, () => setState(() => _supply += 10)),
                  ]),
                ])).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 16),
              GlassCard(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Drop Radius', style: TextStyle(fontFamily: 'Outfit', fontSize: 16,
                        fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                        color: AppColors.primary.withValues(alpha: 0.08),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
                      child: Text('${_radius.round()}m', style: const TextStyle(fontFamily: 'Outfit',
                          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryLight))),
                  ]),
                  SliderTheme(
                    data: SliderThemeData(trackHeight: 4, thumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary, inactiveTrackColor: const Color(0x14FFFFFF),
                        overlayColor: AppColors.primary.withValues(alpha: 0.12)),
                    child: Slider(value: _radius, min: 10, max: 500, divisions: 49,
                        onChanged: (v) => setState(() => _radius = v))),
                ])).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 20),
              _lbl('Duration'), const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10,
                children: [('24h','24 Hours'),('3d','3 Days'),('7d','7 Days')]
                  .map((d) => GestureDetector(
                    onTap: () { HapticFeedback.selectionClick(); setState(() => _duration = d.$1); },
                    child: AnimatedContainer(duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                        gradient: _duration == d.$1 ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]) : null,
                        color: _duration == d.$1 ? null : const Color(0x0AFFFFFF),
                        border: Border.all(color: _duration == d.$1 ? Colors.transparent : const Color(0x14FFFFFF)),
                        boxShadow: _duration == d.$1 ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: -4)] : null),
                      child: Text(d.$2, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600,
                          color: _duration == d.$1 ? Colors.white : AppColors.textSecondary))))).toList()),
              const SizedBox(height: 20),
              GestureDetector(onTap: _useLoc,
                child: AnimatedContainer(duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                    color: _location != null ? AppColors.teal.withValues(alpha: 0.08) : Colors.transparent,
                    border: Border.all(color: AppColors.teal.withValues(alpha: _location != null ? 0.3 : 0.2))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.my_location_rounded, color: AppColors.teal, size: 22),
                    const SizedBox(width: 10),
                    Text(_location != null
                        ? '✓  ${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}'
                        : 'Use My Current Location',
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 16,
                          fontWeight: FontWeight.w700, color: AppColors.teal)),
                  ]))),
              const SizedBox(height: 20),
              AnimatedSwitcher(duration: const Duration(milliseconds: 300),
                child: _success
                  ? Container(key: const ValueKey('ok'), height: 58,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                        color: AppColors.teal.withValues(alpha: 0.10),
                        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25))),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 24),
                        SizedBox(width: 10),
                        Text('Drop Created! 🎉', style: TextStyle(fontFamily: 'Outfit', fontSize: 18,
                            fontWeight: FontWeight.w800, color: AppColors.teal)),
                      ])).animate().scale(begin: Offset(0.8,0.8)).fadeIn()
                  : LiquidButton(key: const ValueKey('create'), label: 'CREATE DROP',
                      icon: Icons.auto_awesome_rounded, isLoading: _loading, height: 64, fontSize: 18,
                      onPressed: _loading ? null : _create)),
              const SizedBox(height: 80),
            ]),
          )),
        ])),
      ]),
    );
  }

  Widget _uploadBox() => GestureDetector(onTap: _pick,
    child: AnimatedContainer(duration: const Duration(milliseconds: 300),
      width: double.infinity, height: 180,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
        color: AppColors.primary.withValues(alpha: 0.03),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5)),
      child: _image != null
        ? ClipRRect(borderRadius: BorderRadius.circular(22),
            child: Image.file(_image!, fit: BoxFit.cover))
        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 56, height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.10)),
              child: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 26)),
            const SizedBox(height: 10),
            const Text('Tap to upload NFT artwork', style: TextStyle(fontFamily: 'Outfit', fontSize: 16,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('PNG, JPG, GIF up to 50MB',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.textSecondary)),
          ])));

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontFamily: 'Outfit', fontSize: 14,
      fontWeight: FontWeight.w700, color: AppColors.textPrimary));

  Widget _inp(TextEditingController c, String h) => Container(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
      color: const Color(0x0AFFFFFF), border: Border.all(color: const Color(0x0FFFFFFF))),
    child: TextField(controller: c,
      style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textPrimary),
      decoration: InputDecoration(hintText: h,
        hintStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textHint),
        border: InputBorder.none, contentPadding: const EdgeInsets.all(18))));

  Widget _area(TextEditingController c, String h) => Container(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
      color: const Color(0x0AFFFFFF), border: Border.all(color: const Color(0x0FFFFFFF))),
    child: TextField(controller: c, maxLines: 4,
      style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textPrimary),
      decoration: InputDecoration(hintText: h,
        hintStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textHint),
        border: InputBorder.none, contentPadding: const EdgeInsets.all(18))));

  Widget _cBtn(IconData icon, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle,
      color: AppColors.primary.withValues(alpha: 0.08), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
      child: Icon(icon, color: AppColors.primary, size: 18)));
}
