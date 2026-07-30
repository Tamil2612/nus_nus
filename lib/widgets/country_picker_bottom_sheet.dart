import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/country_code.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class CountryPickerBottomSheet extends StatefulWidget {
  const CountryPickerBottomSheet({super.key});

  @override
  State<CountryPickerBottomSheet> createState() => _CountryPickerBottomSheetState();
}

class _CountryPickerBottomSheetState extends State<CountryPickerBottomSheet> {
  final _searchCtrl = TextEditingController();
  List<CountryCode> _filtered = CountryCode.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = CountryCode.all
          .where((c) =>
              c.name.toLowerCase().contains(query) ||
              c.dialCode.contains(query) ||
              c.code.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.8.sh,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: Column(
        children: [
          12.verticalSpace,
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          16.verticalSpace,
          Text(
            'Select Country',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              fontFamily: 'Georgia',
            ),
          ),
          20.verticalSpace,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: TextStyle(color: AppColors.ink, fontSize: 14.sp),
              decoration: AppTheme.inputDecoration(
                'Search country or code...',
                icon: Icons.search_rounded,
              ),
            ),
          ),
          16.verticalSpace,
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final country = _filtered[index];
                return ListTile(
                  leading: Text(
                    country.flagEmoji,
                    style: TextStyle(fontSize: 22.sp),
                  ),
                  title: Text(
                    country.name,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Text(
                    country.dialCode,
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, country),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
