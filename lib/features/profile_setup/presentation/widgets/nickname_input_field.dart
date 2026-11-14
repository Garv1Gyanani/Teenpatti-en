import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Rounded nickname text field with user icon prefix and live `X/15` counter.
class NicknameInputField extends StatelessWidget {
  const NicknameInputField({
    super.key,
    required this.controller,
    required this.maxLength,
    required this.currentLength,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final int maxLength;
  final int currentLength;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nickname', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLength: maxLength,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            LengthLimitingTextInputFormatter(maxLength),
          ],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.forestGreen,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.inputFill,
            counterText: '',
            hintText: 'Enter your nickname',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: AppColors.mutedText,
            ),
            prefixIcon: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.mutedText,
              size: 22,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$currentLength/$maxLength',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: errorText != null
                    ? Theme.of(context).colorScheme.error
                    : AppColors.inputBorder,
                width: 1.1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: errorText != null
                    ? Theme.of(context).colorScheme.error
                    : AppColors.forestGreen,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

