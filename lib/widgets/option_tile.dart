import 'package:flutter/material.dart';

class OptionTile extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color selectedBorderColor;
  final double fontSize;

  const OptionTile({
    Key? key,
    required this.text,
    required this.isSelected,
    required this.onTap,
    this.selectedColor = const Color(0xFFBF5700),
    this.selectedBorderColor = const Color.fromARGB(255, 238, 214, 134),
    this.fontSize = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12), // jarak antar opsi lebih besar
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 22, horizontal: 22), // padding lebih besar
            constraints:
                const BoxConstraints(minHeight: 80), // minimum tinggi ditambah
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [
                        Color(0xFFFF8A65), // Soft coral
                        Color(0xFFFFCC80), // Warm peach
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFFFF6B6B).withOpacity(0.25)
                      : Colors.grey.withOpacity(0.1),
                  offset: const Offset(0, 4),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: isSelected ? 0 : 0,
                ),
              ],
            ),
            child: Center(
              // teks di tengah secara vertikal dan horizontal
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.black : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
