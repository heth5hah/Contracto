import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? textColor;
  final Widget? leading;
  final double height;
  final bool centerTitle;

  const AppHeader({
    super.key,
    this.title,
    this.actions,
    this.showBackButton = true,
    this.backgroundColor,
    this.textColor,
    this.leading,
    this.height = 56.0,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTextColor =
        backgroundColor == null ? const Color(0xFF1A1A1A) : Colors.white;

    return Container(
      height: height + MediaQuery.of(context).padding.top,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        boxShadow: backgroundColor == null
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showBackButton && Navigator.canPop(context))
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: textColor ?? defaultTextColor,
                ),
                onPressed: () => Navigator.pop(context),
              )
            else if (leading != null)
              leading!,
            if (title != null) ...[
              if (centerTitle) const Spacer(),
              Text(
                title!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? defaultTextColor,
                ),
              ),
              if (centerTitle) const Spacer(),
            ],
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}
