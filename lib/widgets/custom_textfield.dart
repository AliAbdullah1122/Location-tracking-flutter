import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  // ignore: use_key_in_widget_constructors
  const CustomTextField(
      {this.hint,
      this.label,
      this.pretext,
      this.sufText,
      this.maxLength,
      this.initialValue,
      this.icon,
      this.enabled,
      this.prefixIcon,
      this.suffixIcon,
      this.keyType,
      this.keyAction,
      this.textEditingController,
      this.onSubmitted,
      this.validate,
      this.validator,
      this.onChanged,
      this.colors,
      this.fillColors,
      // ignore: non_constant_identifier_names
      this.AllowClickable = false,
      this.validatorText,
      this.inputformater,
      this.onClick});
  final VoidCallback? onClick;
  final Color? colors, fillColors;
  // ignore: non_constant_identifier_names
  final bool? AllowClickable;
  final String? hint;
  final String? label;
  final String? pretext;
  final String? sufText;
  final String? initialValue;
  final int? maxLength;
  final bool? enabled;
  final Widget? icon, prefixIcon, suffixIcon;
  final TextInputType? keyType;
  final TextEditingController? textEditingController;
  final TextInputAction? keyAction;
  final String? Function(String?)? validate;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? validator;
  final ValueChanged<String>? onChanged;
  final String? validatorText;
  final List<TextInputFormatter>? inputformater;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.height * 0.03,
          vertical: MediaQuery.of(context).size.height * 0.01),
      child: TextFormField(
          inputFormatters: inputformater ?? [],
          autofocus: true,
          onChanged: onChanged,
          maxLength: maxLength,
          controller: textEditingController,
          enabled: enabled,
          keyboardType: keyType,
          textInputAction: keyAction,
          validator: validate,
          initialValue: initialValue,
          decoration: InputDecoration(
            fillColor: fillColors ?? const Color(0xffF2F2F2),
            filled: true,
            isDense: true,
            prefixText: pretext,
            suffixText: sufText,
            focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(10)),
            border: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey, width: 2),
                borderRadius: BorderRadius.all(Radius.circular(10))),
            labelText: label,
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            labelStyle: Theme.of(context).textTheme.headline4!.copyWith(
                color: colors ?? Colors.grey.withOpacity(0.5),
                fontFamily: 'PoppinsRegular',
                fontWeight: FontWeight.bold,
                fontSize: 14),
            hintStyle: Theme.of(context).textTheme.headline4!.copyWith(
                  color: colors ?? Colors.grey.withOpacity(0.5),
                  fontFamily: 'PoppinsRegular',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
          ),
          onFieldSubmitted: onSubmitted),
    );
  }
}
