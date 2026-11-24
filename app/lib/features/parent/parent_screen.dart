import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../data/models.dart';
import '../../logic/quiet_hours.dart';
import '../../services/kiosk.dart';
import '../../theme/colors.dart';
import '../../widgets/family_avatar.dart';
import '../../widgets/pin_pad.dart';

/// The grown-up area behind the PIN. Normal adult UI (small text, lists, switches),
/// not the child's big bubbly buttons.
class ParentScreen extends StatelessWidget {
  const ParentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FamilyStore>();
    final s = store.state;
    final settings = s.settings;

    return Scaffold(
      backgroundColor: AppColors.adultBackground,
      appBar: AppBar(
        backgroundColor: AppColors.adultBackground,
        title: Text("${s.childName}'s settings", style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            key: const Key('back-to-child'),
            icon: const Icon(Icons.lock_rounded),
            label: const Text('Lock & exit'),
            onPressed: () {
              context.read<Kiosk>().lock();
              context.go('/home');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Panel(
            title: 'Who she can talk to',
            children: [
              for (final (i, c) in s.contacts.indexed)
                Row(
                  key: Key('contact-row-${c.id}'),
                  children: [
                    FamilyAvatar(ring: c.color.main, size: 44),
                    const SizedBox(width: 10),
                    Expanded(child: Text(c.name, style: const TextStyle(fontSize: 18))),
                    IconButton(
                      key: Key('up-${c.id}'),
                      tooltip: 'Move up',
                      onPressed: i == 0 ? null : () => store.moveContact(c.id, -1),
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    ),
                    IconButton(
                      key: Key('down-${c.id}'),
                      tooltip: 'Move down',
                      onPressed: i == s.contacts.length - 1 ? null : () => store.moveContact(c.id, 1),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    IconButton(
                      key: Key('delete-${c.id}'),
                      tooltip: 'Remove',
                      onPressed: () => _confirmRemove(context, store, c),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              FilledButton.icon(
                key: const Key('add-contact'),
                onPressed: () => _addContact(context, store),
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Add family member'),
              ),
            ],
          ),
          _Panel(
            title: 'Invite a relative',
            subtitle: 'Send this code to a family member. It works once and expires in 48 hours.',
            children: [
              for (final inv in s.invites.take(3))
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: FamilyColor.yellow.light,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        inv.code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        inv.used ? 'Used by ${inv.usedBy}' : (inv.isValidAt(store.now) ? 'Waiting' : 'Expired'),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              OutlinedButton.icon(
                key: const Key('new-invite'),
                onPressed: store.createInvite,
                icon: const Icon(Icons.key_rounded),
                label: const Text('New invite code'),
              ),
            ],
          ),
          _Panel(
            title: 'Safety',
            children: [
              SwitchListTile(
                key: const Key('toggle-typing'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow typing'),
                subtitle: const Text('Off: voice, stickers and drawings only'),
                value: settings.typingAllowed,
                onChanged: (v) => store.updateSettings(settings.copyWith(typingAllowed: v)),
              ),
              SwitchListTile(
                key: const Key('toggle-filters'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Face filters on calls'),
                value: settings.filtersAllowed,
                onChanged: (v) => store.updateSettings(settings.copyWith(filtersAllowed: v)),
              ),
              SwitchListTile(
                key: const Key('toggle-quiet'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Quiet hours'),
                subtitle: const Text('No calls or messages: "Sleepy time"'),
                value: settings.quietOn,
                onChanged: (v) => store.updateSettings(settings.copyWith(quietOn: v)),
              ),
              if (settings.quietOn)
                Row(
                  children: [
                    const Text('From'),
                    TextButton(
                      key: const Key('quiet-from'),
                      onPressed: () => _pickTime(
                        context,
                        settings.quietFromMinutes,
                        (m) => store.updateSettings(settings.copyWith(quietFromMinutes: m)),
                      ),
                      child: Text(formatMinutes(settings.quietFromMinutes)),
                    ),
                    const Text('to'),
                    TextButton(
                      key: const Key('quiet-to'),
                      onPressed: () => _pickTime(
                        context,
                        settings.quietToMinutes,
                        (m) => store.updateSettings(settings.copyWith(quietToMinutes: m)),
                      ),
                      child: Text(formatMinutes(settings.quietToMinutes)),
                    ),
                  ],
                ),
              OutlinedButton.icon(
                key: const Key('change-pin'),
                onPressed: () => _changePin(context, store),
                icon: const Icon(Icons.password_rounded),
                label: const Text('Change parent PIN'),
              ),
            ],
          ),
          _Panel(
            title: 'Activity',
            children: [
              if (s.activity.isEmpty) const Text('Nothing yet', style: TextStyle(color: AppColors.muted)),
              for (final a in s.activity.take(20))
                Row(
                  children: [
                    Expanded(child: Text(a.text)),
                    Text(
                      '${a.at.day}/${a.at.month} ${formatMinutes(a.at.hour * 60 + a.at.minute)}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
            ],
          ),
          TextButton(
            onPressed: () {
              store.switchRole(Role.family);
              context.go('/family');
            },
            child: const Text('Demo: switch this device to a relative view'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, int minutes, ValueChanged<int> onPicked) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (t != null) onPicked(t.hour * 60 + t.minute);
  }

  Future<void> _confirmRemove(BuildContext context, FamilyStore store, Contact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${c.name}?'),
        content: const Text('Their tile disappears from the home screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('confirm-remove'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) store.removeContact(c.id);
  }

  Future<void> _addContact(BuildContext context, FamilyStore store) async {
    final result = await showDialog<(String, FamilyColor)>(context: context, builder: (_) => const _AddContactDialog());
    if (result != null) store.addContact(result.$1, result.$2);
  }

  Future<void> _changePin(BuildContext context, FamilyStore store) async {
    String? first;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(first == null ? 'New PIN' : 'Type it again'),
          content: PinPad(
            key: ValueKey(first),
            onComplete: (pin) {
              if (first == null) {
                setLocal(() => first = pin);
                return true;
              }
              if (pin != first) return false;
              store.changePin(pin);
              Navigator.pop(ctx);
              return true;
            },
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    // Material (not a coloured Container) so switch tiles can draw their ripple on it.
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 15)),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// Its own StatefulWidget so it owns the TextEditingController and disposes it
/// only when the dialog is really gone (after the closing animation).
class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog();

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _name = TextEditingController();
  FamilyColor _color = FamilyColor.green;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add family member'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('new-contact-name'),
          controller: _name,
          maxLength: 20,
          decoration: const InputDecoration(hintText: 'Name, e.g. Cousin Sara'),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final c in FamilyColor.choosable)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: c == _color ? AppColors.ink : Colors.transparent,
                  child: CircleAvatar(radius: 14, backgroundColor: c.main),
                ),
              ),
          ],
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        key: const Key('confirm-add'),
        onPressed: () {
          final name = _name.text.trim();
          Navigator.pop(context, name.isEmpty ? null : (name, _color));
        },
        child: const Text('Add'),
      ),
    ],
  );
}
