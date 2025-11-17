import 'package:flutter/material.dart';

class InputField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final int maxLines;

  const InputField({super.key, required this.controller, required this.hint, this.onSubmitted, this.validator, this.maxLines = 1});

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  late FocusNode focusNode;
  bool isFocused = false;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    focusNode.addListener(() {
      setState(() {
        isFocused = focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void handleSubmit() {
    if (widget.validator != null) {
      final error = widget.validator!(widget.controller.text);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
        return;
      }
    }
    widget.onSubmitted?.call(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isFocused ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))] : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: focusNode,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.send), onPressed: handleSubmit, tooltip: 'Submit')
              : null,
          filled: true,
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {});
        },
        onSubmitted: (_) => handleSubmit(),
      ),
    );
  }
}
