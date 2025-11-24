import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

typedef CountrySelected = void Function(Country country);

class PhoneFieldWithFlag extends StatefulWidget {
  final TextEditingController controller;
  final String? initialIso; // e.g. "SG"
  final String? initialDial; // e.g. "+65"
  final CountrySelected? onCountrySelected;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;

  const PhoneFieldWithFlag({
    Key? key,
    required this.controller,
    this.initialIso,
    this.initialDial,
    this.onCountrySelected,
    this.hintText,
    this.validator,
    this.keyboardType = TextInputType.phone,
  }) : super(key: key);

  @override
  State<PhoneFieldWithFlag> createState() => _PhoneFieldWithFlagState();
}

class _PhoneFieldWithFlagState extends State<PhoneFieldWithFlag> {
  Country? _selected;

  void _showPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (country) {
        setState(() => _selected = country);
        widget.onCountrySelected?.call(country);
      },
      countryListTheme: const CountryListThemeData(bottomSheetHeight: 480),
    );
  }

  String _isoToFlag(String iso) {
    if (iso.length != 2) return iso;
    final a = iso.toUpperCase().codeUnitAt(0);
    final b = iso.toUpperCase().codeUnitAt(1);
    const base = 0x1F1E6;
    return String.fromCharCode(base + (a - 65)) + String.fromCharCode(base + (b - 65));
  }

  @override
  Widget build(BuildContext context) {
    final dial = _selected != null ? '+${_selected!.phoneCode}' : (widget.initialDial ?? '');
    final flag = _selected != null ? _selected!.flagEmoji : (widget.initialIso != null ? _isoToFlag(widget.initialIso!) : '??');

    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hintText ?? 'Phone number',
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        prefixIcon: InkWell(
          onTap: _showPicker,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(dial, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_drop_down, size: 20),
            ]),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
