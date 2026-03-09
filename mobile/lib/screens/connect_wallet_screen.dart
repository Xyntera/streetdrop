import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/wallet_provider.dart';

class ConnectWalletScreen extends ConsumerStatefulWidget {
  const ConnectWalletScreen({super.key});
  @override ConsumerState<ConnectWalletScreen> createState() => _CWState();
}

class _CWState extends ConsumerState<ConnectWalletScreen> with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

  @override void dispose() { _float.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final size   = MediaQuery.of(context).size;
    final pad    = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        // Subtle ambient gradient — no orbs
        Positioned(top: -120, left: -80,
          child: Container(width: 360, height: 360,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.primary.withValues(alpha: 0.10),
                AppColors.primary.withValues(alpha: 0.02),
                Colors.transparent,
              ])))),
        Positioned(bottom: -100, right: -60,
          child: Container(width: 320, height: 320,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.accent.withValues(alpha: 0.06),
                Colors.transparent,
              ])))),
        SafeArea(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            SizedBox(height: size.height * 0.08),
            _hero(),
            SizedBox(height: size.height * 0.04),
            _card().animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(begin: 0.08, end: 0),
            const SizedBox(height: 20),
            if (wallet.error == 'no_wallet') _noWallet().animate().fadeIn(duration: 400.ms),
            if (wallet.error != null && wallet.error != 'no_wallet') _errBox(wallet.error!).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            LiquidButton(
              label: wallet.status == WalletStatus.connecting ? 'Connecting...' : 'Connect Wallet',
              isLoading: wallet.status == WalletStatus.connecting,
              height: 58, fontSize: 17, radius: 16,
              onPressed: wallet.status == WalletStatus.connecting ? null : () => ref.read(walletProvider.notifier).connect(),
            ).animate().fadeIn(delay: 450.ms),
            const SizedBox(height: 16),
            Text('Your private keys never leave your wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.textDim.withValues(alpha: 0.6))).animate().fadeIn(delay: 550.ms),
            SizedBox(height: pad.bottom + 32),
          ]),
        )),
      ]),
    );
  }

  Widget _hero() {
    return Column(children: [
      AnimatedBuilder(
        animation: _float,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, -6 * math.sin(_float.value * math.pi)),
          child: Container(width: 88, height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark]),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: -8, offset: const Offset(0, 16))]),
            child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 40)),
        ),
      ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), curve: Curves.easeOutBack),
      const SizedBox(height: 28),
      const Text('StreetDrop', style: TextStyle(fontFamily: 'Outfit', fontSize: 40,
          fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -1.5))
          .animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(begin: 0.15, end: 0),
      const SizedBox(height: 8),
      const Text('Presence is the price of admission', style: TextStyle(fontFamily: 'Outfit',
          fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textSecondary))
          .animate().fadeIn(delay: 200.ms, duration: 500.ms),
    ]);
  }

  Widget _card() => GlassCard(padding: const EdgeInsets.all(24), radius: 20,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Connect Your Wallet', style: TextStyle(fontFamily: 'Outfit', fontSize: 20,
          fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('NFTs mint directly to your Solana wallet when you claim a drop in person.',
          style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary, height: 1.55)),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
          color: AppColors.primary.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.primary.withValues(alpha: 0.15)),
            child: const Center(child: Text('⚡', style: TextStyle(fontSize: 22)))),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Solana Saga / Seeker', style: TextStyle(fontFamily: 'Outfit', fontSize: 14,
                fontWeight: FontWeight.w700, color: AppColors.primaryLight)),
            SizedBox(height: 2),
            Text('Built-in Seed Vault hardware wallet',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          ])),
        ])),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: Container(height: 1, color: const Color(0x0FFFFFFF))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('or on any Android', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.textDim))),
        Expanded(child: Container(height: 1, color: const Color(0x0FFFFFFF))),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        _wBtn('👻', 'Phantom', 'https://play.google.com/store/apps/details?id=app.phantom'),
        const SizedBox(width: 12),
        _wBtn('🔥', 'Solflare', 'https://play.google.com/store/apps/details?id=com.solflare.mobile'),
      ]),
    ]));

  Widget _wBtn(String emoji, String name, String url) => Expanded(child: GestureDetector(
    onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
        color: const Color(0x0AFFFFFF), border: Border.all(color: const Color(0x0FFFFFFF))),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        const Text('Install', style: TextStyle(fontFamily: 'Outfit', fontSize: 11,
            color: AppColors.primary, fontWeight: FontWeight.w500)),
      ]))));

  Widget _errBox(String msg) => Container(width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
      color: AppColors.danger.withValues(alpha: 0.08), border: Border.all(color: AppColors.danger.withValues(alpha: 0.25))),
    child: Text(msg, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.danger)));

  Widget _noWallet() => Container(width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
      color: AppColors.warning.withValues(alpha: 0.08), border: Border.all(color: AppColors.warning.withValues(alpha: 0.2))),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('No wallet app found', style: TextStyle(fontFamily: 'Outfit', fontSize: 14,
          fontWeight: FontWeight.w700, color: AppColors.warning)),
      SizedBox(height: 4),
      Text('Install Phantom or Solflare from the Play Store above.',
          style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.textSecondary)),
    ]));
}
