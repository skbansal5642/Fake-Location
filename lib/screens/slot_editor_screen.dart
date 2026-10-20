import 'package:flutter/material.dart';

import '../models/slot.dart';
import '../widgets/location_picker.dart';

/// Edits a schedule slot's name, time window and position.
class SlotEditorScreen extends StatefulWidget {
  const SlotEditorScreen({super.key, required this.initial});

  final Slot initial;

  @override
  State<SlotEditorScreen> createState() => _SlotEditorScreenState();
}

class _SlotEditorScreenState extends State<SlotEditorScreen> {
  late Slot _slot = widget.initial;
  late final _nameController = TextEditingController(text: widget.initial.name);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _slot.start : _slot.end,
    );
    if (picked == null) return;
    setState(() => _slot = start ? _slot.copyWith(start: picked) : _slot.copyWith(end: picked));
  }

  void _save() {
    final name = _nameController.text.trim();
    Navigator.pop(context, _slot.copyWith(name: name.isEmpty ? 'Location' : name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit time slot'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('From'),
                        subtitle: Text(_slot.start.format(context)),
                        onTap: () => _pickTime(start: true),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Until'),
                        subtitle: Text(_slot.end.format(context)),
                        onTap: () => _pickTime(start: false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: LocationPicker(
              initial: _slot.position,
              onChanged: (p, title) {
                setState(() => _slot = _slot.copyWith(position: p));
                if (title != null && _nameController.text.trim().isEmpty) _nameController.text = title;
              },
            ),
          ),
        ],
      ),
    );
  }
}
