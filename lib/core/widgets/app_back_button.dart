import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.leftPadding = 12,
  });

  final VoidCallback onPressed;
  final double leftPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: Center(
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: Colors.black12,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16.sp),
            color: const Color(0xFF0F172A),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
