import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'map_screen.dart';
import 'my_drops_screen.dart';
import 'creator_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});
  @override ConsumerState<ShellScreen> createState() => _ShellState();
}

class _ShellState extends ConsumerState<ShellScreen> {
  int _idx = 0;

  void _tab(int i) {
    if (i == _idx) return;
    HapticFeedback.selectionClick();
    setState(() => _idx = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: switch (_idx) {
          0 => const MapScreen(key: ValueKey(0)),
          1 => const MyDropsScreen(key: ValueKey(1)),
          _ => const CreatorScreen(key: ValueKey(2)),
        },
      ),
      bottomNavigationBar: _nav(context),
    );
  }

  Widget _nav(BuildContext context) {
    final mq      = MediaQuery.of(context);
    final navW    = mq.size.width - 40;
    final itemW   = navW / 3;
    final labels  = ['Discover', 'My Drops', ''];
    final icons   = [Icons.explore_rounded, Icons.style_rounded, Icons.add_rounded];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, mq.padding.bottom + 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF0E0E1A).withValues(alpha: 0.85),
              border: Border.all(color: const Color(0x14FFFFFF))),
            child: Row(children: List.generate(3, (i) {
              final active = _idx == i;
              final isFab  = i == 2;
              return GestureDetector(
                onTap: () => _tab(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(width: itemW, height: 68,
                  child: isFab
                    ? Center(child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [AppColors.primary, AppColors.primaryDark]),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: active ? 0.5 : 0.3),
                              blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 4))]),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26)))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        AnimatedContainer(duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: active ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent),
                          child: Icon(icons[i], size: 22,
                              color: active ? AppColors.primary : AppColors.textDim)),
                        const SizedBox(height: 2),
                        Text(labels[i], style: TextStyle(fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? AppColors.primary : AppColors.textDim)),
                      ]),
                ),
              );
            })),
          ),
        ),
      ),
    );
  }
}
