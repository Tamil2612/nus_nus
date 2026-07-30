import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/country_code.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'country_picker_bottom_sheet.dart';

class PhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final String? initialValue;

  const PhoneInputField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.focusNode,
    this.nextFocusNode,
    this.initialValue,
  });

  @override
  State<PhoneInputField> createState() => PhoneInputFieldState();
}

class PhoneInputFieldState extends State<PhoneInputField> {
  CountryCode _selectedCountry = CountryCode.all.first; // Default to UAE

  @override
  void initState() {
    super.initState();
    _parseInitialValue();
  }

  void _parseInitialValue() {
    if (widget.initialValue == null || widget.initialValue!.isEmpty) return;

    final value = widget.initialValue!;
    // Try to find matching dial code
    for (final country in CountryCode.all) {
      if (value.startsWith(country.dialCode)) {
        setState(() {
          _selectedCountry = country;
        });
        // Strip dial code from the rest of the number for the controller
        final number = value.substring(country.dialCode.length).trim();
        widget.controller.text = number;
        return;
      }
    }
    // Fallback: just put the whole thing in the controller
    widget.controller.text = value;
  }

  String get fullNumber => '${_selectedCountry.dialCode}${widget.controller.text.trim()}';

  Future<void> _showPicker() async {
    final country = await showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CountryPickerBottomSheet(),
    );

    if (country != null) {
      setState(() {
        _selectedCountry = country;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      keyboardType: TextInputType.phone,
      textInputAction: widget.nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
      style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
      decoration: AppTheme.inputDecoration(
        'Mobile number',
      ).copyWith(
        prefixIcon: InkWell(
          onTap: widget.enabled ? _showPicker : null,
          child: Container(
            width: 90.w,
            padding: EdgeInsets.only(left: 12.w),
            child: Row(
              children: [
                Text(
                  _selectedCountry.flagEmoji,
                  style: TextStyle(fontSize: 18.sp),
                ),
                4.horizontalSpace,
                Text(
                  _selectedCountry.dialCode,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.slate,
                  size: 20.r,
                ),
              ],
            ),
          ),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Enter your mobile number.';
        }
        return null;
      },
      onFieldSubmitted: (_) {
        if (widget.nextFocusNode != null) {
          FocusScope.of(context).requestFocus(widget.nextFocusNode);
        }
      },
    );
  }
}
