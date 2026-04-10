import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InputLabel extends StatelessWidget {
  const InputLabel({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:  EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style:  TextStyle(
          fontSize: 12.sp,
          color: const Color(0xFF4C669A),
        ),
      ),
    );
  }
}
