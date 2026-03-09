import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// ── GlassCard ─────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width, height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius, blur;
  final Color? borderColor, glowColor;
  final VoidCallback? onTap;

  const GlassCard({super.key, required this.child,
    this.width, this.height,
    this.padding = const EdgeInsets.all(20),
    this.margin, this.radius = 24, this.blur = 24,
    this.borderColor, this.glowColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width, height: height, margin: margin,
        decoration: glowColor != null ? BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [BoxShadow(color: glowColor!.withValues(alpha: 0.12), blurRadius: 32, spreadRadius: -4)],
        ) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0x14FFFFFF), Color(0x06FFFFFF)],
                ),
                border: Border.all(color: borderColor ?? const Color(0x14FFFFFF)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ── LiquidButton ──────────────────────────────────────────────────────────────
class LiquidButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading, isOutlined;
  final Color? color, textColor;
  final IconData? icon;
  final double height, fontSize;
  final double? width;
  final double radius;

  const LiquidButton({super.key, required this.label,
    this.onPressed, this.isLoading = false, this.isOutlined = false,
    this.color, this.textColor, this.icon,
    this.height = 60, this.width, this.radius = 20, this.fontSize = 17});

  @override State<LiquidButton> createState() => _LiquidButtonState();
}

class _LiquidButtonState extends State<LiquidButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final c = widget.color ?? AppColors.primary;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: GestureDetector(
          onTapDown: enabled ? (_) { HapticFeedback.lightImpact(); _ctrl.forward(); } : null,
          onTapUp:   enabled ? (_) { _ctrl.reverse(); widget.onPressed!(); } : null,
          onTapCancel: () => _ctrl.reverse(),
          child: AnimatedOpacity(
            opacity: enabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: widget.width ?? double.infinity, height: widget.height,
              decoration: widget.isOutlined
                ? BoxDecoration(borderRadius: BorderRadius.circular(widget.radius),
                    border: Border.all(color: c, width: 1.5), color: c.withValues(alpha: 0.06))
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [c, Color.lerp(c, Colors.black, 0.25)!]),
                    boxShadow: [
                      BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: -6, offset: const Offset(0, 8)),
                    ]),
              child: widget.isLoading
                ? Center(child: SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(widget.textColor ?? Colors.white))))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: widget.textColor ?? Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(widget.label, style: TextStyle(fontFamily: 'Outfit',
                        fontSize: widget.fontSize, fontWeight: FontWeight.w700,
                        color: widget.textColor ?? Colors.white, letterSpacing: -0.2)),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── AnimatedOrbs ──────────────────────────────────────────────────────────────
class AnimatedOrbs extends StatefulWidget {
  final List<Color>? colors;
  final double maxSize;
  const AnimatedOrbs({super.key, this.colors, this.maxSize = 350});
  @override State<AnimatedOrbs> createState() => _OrbsState();
}

class _OrbsState extends State<AnimatedOrbs> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final colors = widget.colors ?? [AppColors.primary, AppColors.accent, AppColors.teal];
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Stack(children: List.generate(colors.length.clamp(1, 3), (i) {
          final ph = i / 3.0;
          final r  = widget.maxSize * (0.7 + 0.3 * math.sin((t + ph) * 2 * math.pi));
          final x  = size.width  * (0.2 + 0.5 * math.sin((t * 0.4 + ph) * 2 * math.pi));
          final y  = size.height * (0.15 + 0.5 * math.cos((t * 0.3 + ph) * 2 * math.pi));
          final color = colors[i % colors.length];
          return Positioned(left: x - r/2, top: y - r/2,
            child: Container(width: r, height: r,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [color.withValues(alpha: 0.10), color.withValues(alpha: 0.02), Colors.transparent]))));
        }));
      },
    );
  }
}

// ── WalletPill ────────────────────────────────────────────────────────────────
class WalletPill extends StatelessWidget {
  final String address;
  final VoidCallback? onTap;
  const WalletPill({super.key, required this.address, this.onTap});
  String get _short => '${address.substring(0,4)}...${address.substring(address.length-4)}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
          color: AppColors.primary.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent)),
          const SizedBox(width: 7),
          Text(_short, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12,
              fontWeight: FontWeight.w700, color: AppColors.primaryLight, letterSpacing: 0.3)),
        ]),
      ),
    );
  }
}

// ── ProximityRing ─────────────────────────────────────────────────────────────
class ProximityRing extends StatefulWidget {
  final double? distance;
  final double radius;
  const ProximityRing({super.key, this.distance, required this.radius});
  @override State<ProximityRing> createState() => _ProximityRingState();
}

class _ProximityRingState extends State<ProximityRing> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  @override void initState() { super.initState(); _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(); }
  @override void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final inRange = widget.distance != null && widget.distance! <= widget.radius;
    final color   = inRange ? AppColors.teal : AppColors.danger;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => SizedBox(width: 180, height: 180,
        child: Stack(alignment: Alignment.center, children: [
          Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: (1-_pulse.value)*0.3), width: 1))),
          Container(width: 144, height: 144, decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
              color: color.withValues(alpha: inRange ? 0.06 : 0.02))),
          Container(width: 108, height: 108,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color.withValues(alpha: inRange ? 0.15 : 0.05), Colors.transparent]),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (widget.distance == null)
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(color)))
              else ...[
                Text('${widget.distance!.round()}m', style: TextStyle(fontFamily: 'Outfit', fontSize: 26,
                    fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
                Text(inRange ? "you're here" : 'get closer',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
              ],
            ])),
        ])),
    );
  }
}
