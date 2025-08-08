import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:foodyman/infrastructure/services/app_helpers.dart';
import 'package:foodyman/infrastructure/services/tr_keys.dart';
import 'package:foodyman/presentation/components/app_bars/app_bar_bottom_sheet.dart';
import 'package:foodyman/presentation/components/buttons/custom_button.dart';
import 'package:foodyman/presentation/components/keyboard_dismisser.dart';
import 'package:foodyman/presentation/components/text_fields/outline_bordered_text_field.dart';
import 'package:foodyman/presentation/theme/app_style.dart';
import 'package:flutter/services.dart';

class PhoneVerify extends ConsumerStatefulWidget {
  final String? initialPhone;
  final void Function(String phone) onSave;
  const PhoneVerify({Key? key, this.initialPhone, required this.onSave}) : super(key: key);

  @override
  ConsumerState<PhoneVerify> createState() => _PhoneVerifyState();
}

class _PhoneVerifyState extends ConsumerState<PhoneVerify> {
  late TextEditingController _phoneController;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Always start with empty input for editing, do not prefill with old phone
    _phoneController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onSave() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _error = 'Phone number is required.';
      });
      return;
    }
    if (!RegExp(r'^[1-9][0-9]{8}$').hasMatch(phone)) {
      if (phone.length != 9) {
        setState(() {
          _error = 'Phone number must be exactly 9 digits.';
        });
      } else if (phone.startsWith('0')) {
        setState(() {
          _error = 'Phone number should not start with 0.';
        });
      } else {
        setState(() {
          _error = 'Invalid phone number.';
        });
      }
      return;
    }
    setState(() { _loading = true; _error = null; });
    await Future.sync(() => widget.onSave('+212$phone'));
    
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: Container(
        margin: MediaQuery.of(context).viewInsets,
        decoration: BoxDecoration(
          color: AppStyle.bgGrey.withOpacity(0.96),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
          ),
        ),
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBarBottomSheet(
                  title: AppHelpers.getTranslation(TrKeys.phoneNumber),
                ),
                24.verticalSpace,
                OutlinedBorderTextField(
                  label: 'PHONE NUMBER',
                  textController: _phoneController,
                  inputType: TextInputType.number,
                  isError: _error != null,
                  descriptionText: _error,
                  prefix: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '+212',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  inputFormatters: [
                    // Only allow numbers, max 9 digits
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                ),
                24.verticalSpace,
                CustomButton(
                  title: AppHelpers.getTranslation(TrKeys.save),
                  isLoading: _loading,
                  onPressed: _loading ? null : _onSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
