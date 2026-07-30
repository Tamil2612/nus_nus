import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../theme/app_colors.dart';

class ReceiptUploadCard extends StatefulWidget {
  final Uint8List? imageBytes;
  final ValueChanged<Uint8List?> onImageSelected;

  const ReceiptUploadCard({
    super.key,
    required this.imageBytes,
    required this.onImageSelected,
  });

  @override
  State<ReceiptUploadCard> createState() => _ReceiptUploadCardState();
}

class _ReceiptUploadCardState extends State<ReceiptUploadCard>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  Uint8List? get _image => widget.imageBytes;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    widget.onImageSelected(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Receipt",
          style: TextStyle(
            color: AppColors.paper,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        12.verticalSpace,
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: _image == null ? 300.h : 340.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(28.r),
                border: Border.all(
                  color: AppColors.brass.withValues(
                    alpha: .45 + (_controller.value * .3),
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _image == null ? _buildPlaceholder() : _buildPreview(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60.r,
            height: 60.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brass.withValues(alpha: .12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 28.r,
              color: AppColors.brass,
            ),
          ),
          12.verticalSpace,
          Text(
            "Upload Receipt",
            style: TextStyle(
              color: AppColors.paper,
              fontWeight: FontWeight.bold,
              fontSize: 17.sp,
            ),
          ),
          6.verticalSpace,
          Text(
            "Take a photo or choose from gallery.\nAI will extract the expense.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.paperDim,
              height: 1.3,
              fontSize: 11.5.sp,
            ),
          ),
          12.verticalSpace,
          Wrap(
            spacing: 6.w,
            children: const [
              _Badge("JPG"),
              _Badge("PNG"),
              _Badge("PDF"),
            ],
          ),
          16.verticalSpace,
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brass,
                    foregroundColor: AppColors.ink,
                    minimumSize: Size(0, 44.h),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  icon: Icon(Icons.photo_camera, size: 16.r),
                  label: Text("Camera", style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                ),
              ),
              8.horizontalSpace,
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.line.withValues(alpha: 0.5),
                    ),
                    foregroundColor: AppColors.paper,
                    minimumSize: Size(0, 44.h),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  icon: Icon(Icons.photo_library, size: 16.r),
                  label: Text("Gallery", style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Padding(
      padding: EdgeInsets.all(18.w),
      child: Column(
        children: [
          Expanded(
            child: Hero(
              tag: "receipt_preview",
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.r),
                  child: Image.memory(
                    _image!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )),
            ),
          ),
          18.verticalSpace,
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    widget.onImageSelected(null);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                  ),
                  icon: const Icon(Icons.delete),
                  label: const Text("Remove"),
                ),
              ),
              12.horizontalSpace,
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brass,
                    foregroundColor: AppColors.ink,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Replace"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14.w,
        vertical: 8.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.paper,
          fontWeight: FontWeight.w700,
          fontSize: 11.sp,
        ),
      ),
    );
  }
}
