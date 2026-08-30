import 'package:flutter/material.dart';

class FloatingIconMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const FloatingIconMenuItem({required this.icon, required this.label, required this.onTap});
}

/// Ekranın sol altında dikey ikon menüsü — AppBar'ı kalabalıklaştırmayan ek
/// fonksiyonlar için. Boşta %75 transparan, sadece ikonlar görünür. İlk
/// dokunma menüyü açar (isimler sağa doğru belirir), aynı (veya başka) öğeye
/// 2. dokunma o öğeyi çalıştırır ve menüyü kapatır. Menü dışına dokunmak da
/// kapatır. Pure Flutter widget — iOS/Android'de birebir aynı davranır.
class FloatingIconMenu extends StatefulWidget {
  final List<FloatingIconMenuItem> items;

  const FloatingIconMenu({super.key, required this.items});

  @override
  State<FloatingIconMenu> createState() => _FloatingIconMenuState();
}

class _FloatingIconMenuState extends State<FloatingIconMenu> {
  bool _expanded = false;

  void _handleTap(FloatingIconMenuItem item) {
    if (!_expanded) {
      setState(() => _expanded = true);
      return;
    }
    setState(() => _expanded = false);
    item.onTap();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: Stack(
        children: [
          if (_expanded)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _expanded = false),
              ),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: SafeArea(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _expanded ? 0.97 : 0.25,
                child: Material(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.items.map((item) {
                      return InkWell(
                        onTap: () => _handleTap(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item.icon, color: Colors.white, size: 22),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                child: _expanded
                                    ? Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(
                                          item.label,
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                        ),
                                      )
                                    : const SizedBox(height: 22),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
