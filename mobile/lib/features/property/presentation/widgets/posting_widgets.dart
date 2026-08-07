import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Top progress bar shared by the posting steps: back button + bar + "Step N of 5".
class PostingProgressBar extends StatelessWidget {
  const PostingProgressBar({
    super.key,
    required this.step,
    this.total = 6,
    required this.onBack,
  });

  final int step;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_rounded), onPressed: onBack),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: step / total,
                minHeight: 5,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('Step $step of $total',
              style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class SecureNote extends StatelessWidget {
  const SecureNote(
      {super.key, this.text = 'All information is secure and private'});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline_rounded,
            size: 14, color: AppColors.inkSoft),
        const SizedBox(width: 6),
        Text(text,
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.inkSoft)),
      ],
    );
  }
}
