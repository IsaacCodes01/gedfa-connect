import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';

class FlagStripe extends StatelessWidget {
  const FlagStripe({super.key, this.height = 6});

  final double height;

  @override
  Widget build(BuildContext context) {
        return SizedBox(
      height: height,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: AppColors.ghanaRed)),
          Expanded(child: ColoredBox(color: AppColors.ghanaGold)),
          Expanded(child: ColoredBox(color: AppColors.ghanaGreen)),
        ],
      ),
    );
  }
}