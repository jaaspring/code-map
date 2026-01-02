import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12), // match OptionTile margin
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          //backgroundColor: const Color(0xFFFF8A65), // Soft coral-orange
          backgroundColor: Colors.black, // Soft coral-orange
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            vertical: 22,
            horizontal: 22,
          ), // match OptionTile padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // match OptionTile radius
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}