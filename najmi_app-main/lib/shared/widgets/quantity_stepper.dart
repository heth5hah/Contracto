import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A pill-shaped quantity stepper control.
///
/// Displays (− [qty] +) in a rounded capsule with smooth animations.
class QuantityStepper extends StatelessWidget {
  final double quantity;
  final ValueChanged<double> onChanged;
  final double minValue;
  final double maxValue;
  final double step;
  final bool allowDecimals;
  final Color? activeColor;
  final double height;

  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.minValue = 0,
    this.maxValue = 9999,
    this.step = 1,
    this.allowDecimals = false,
    this.activeColor,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? const Color(0xFF4F46E5);
    final isAtMin = quantity <= minValue;
    final isAtMax = quantity >= maxValue;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrease button
          _StepperButton(
            icon: Icons.remove,
            onTap: isAtMin
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    final newVal = (quantity - step).clamp(minValue, maxValue);
                    onChanged(allowDecimals
                        ? newVal
                        : newVal.roundToDouble());
                  },
            color: color,
            height: height,
          ),

          // Quantity display
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Container(
              key: ValueKey(quantity),
              constraints: BoxConstraints(minWidth: height),
              alignment: Alignment.center,
              child: Text(
                allowDecimals
                    ? quantity.toStringAsFixed(1)
                    : quantity.toInt().toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),

          // Increase button
          _StepperButton(
            icon: Icons.add,
            onTap: isAtMax
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    final newVal = (quantity + step).clamp(minValue, maxValue);
                    onChanged(allowDecimals
                        ? newVal
                        : newVal.roundToDouble());
                  },
            color: color,
            height: height,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double height;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: SizedBox(
          width: height,
          height: height,
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: isDisabled ? color.withValues(alpha: 0.3) : color,
            ),
          ),
        ),
      ),
    );
  }
}
