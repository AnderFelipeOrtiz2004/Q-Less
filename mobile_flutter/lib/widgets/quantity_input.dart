import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Selector de cantidad con teclado numérico y botones +/-.
class QuantityInput extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const QuantityInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    required this.max,
    this.enabled = true,
  });

  @override
  State<QuantityInput> createState() => _QuantityInputState();
}

class _QuantityInputState extends State<QuantityInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(QuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(int next) {
    final clamped = next.clamp(widget.min, widget.max);
    _controller.text = '$clamped';
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: !widget.enabled || widget.value <= widget.min
                ? null
                : () => _commit(widget.value - 1),
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              onSubmitted: (text) {
                final parsed = int.tryParse(text.trim()) ?? widget.min;
                _commit(parsed);
              },
              onEditingComplete: () {
                final parsed =
                    int.tryParse(_controller.text.trim()) ?? widget.min;
                _commit(parsed);
              },
            ),
          ),
          IconButton(
            onPressed: !widget.enabled || widget.value >= widget.max
                ? null
                : () => _commit(widget.value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
