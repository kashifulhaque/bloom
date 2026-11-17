/// Private, local reflective journal with prompts.
library;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'insights_data.dart';

/// The journal list, shown as a tab of the insights screen.
class JournalView extends StatelessWidget {
  const JournalView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final entries = JournalData.entries(store);
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final muted = BloomTokens.of(context).muted;
    final prompt = kJournalPrompts[daysBetween(DateTime(2024), today()) % kJournalPrompts.length];

    return BloomPage(
      showBack: false,
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xxl),
      spacing: Space.md,
      children: [
        BloomCard.tinted(
          color: BloomColors.luteal,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconBadge(emoji: '✨', color: BloomColors.luteal, size: 36),
              Gap.h12,
              Text("Today's prompt",
                  style: t.labelLarge?.copyWith(color: readableTint(BloomColors.luteal, theme.brightness))),
            ]),
            Gap.v12,
            Text(prompt, style: t.headlineSmall?.copyWith(height: 1.25)),
            Gap.v16,
            Wrap(spacing: Space.sm, runSpacing: Space.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
              FilledButton.icon(
                onPressed: () => openJournalEditor(context, prompt: prompt),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Write'),
              ),
              TextButton.icon(
                onPressed: () => openJournalEditor(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New entry with another prompt'),
              ),
            ]),
          ]),
        ),
        Row(children: [
          Icon(Icons.lock_rounded, size: 14, color: muted),
          Gap.h8,
          Expanded(
            child: Text('Your journal stays on this device. Nobody else can read it.', style: t.bodySmall),
          ),
        ]),
        if (entries.isEmpty)
          const EmptyState(
            emoji: '📖',
            color: BloomColors.luteal,
            title: 'Your journal is empty',
            body: 'Writing a few lines a day can help you notice patterns in your mood and your cycle.',
            compact: true,
          )
        else ...[
          SectionHeader('Entries', subtitle: '${entries.length} so far'),
          for (final e in entries) _EntryCard(entry: e),
        ],
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = entry;
    return BloomCard(
      padding: Insets.cardCompact,
      onTap: () => openJournalEditor(context, entry: e),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          IconBadge(emoji: e.mood, color: BloomColors.luteal, size: 48),
          Gap.v8,
          Text(DateFormat('MMM').format(e.date).toUpperCase(), style: t.labelSmall?.copyWith(letterSpacing: 0.8)),
          Text('${e.date.day}', style: t.titleLarge?.copyWith(height: 1.1)),
        ]),
        Gap.h16,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('EEEE').format(e.date), style: t.labelMedium?.copyWith(color: BloomTokens.of(context).muted)),
            if (e.prompt.isNotEmpty) ...[
              Gap.v4,
              Text(e.prompt, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
            ],
            Gap.v4,
            Text(e.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(height: 1.45)),
          ]),
        ),
      ]),
    );
  }
}

void openJournalEditor(BuildContext context, {JournalEntry? entry, String? prompt}) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => JournalEditor(entry: entry, prompt: prompt)));
}

class JournalEditor extends StatefulWidget {
  const JournalEditor({super.key, this.entry, this.prompt});
  final JournalEntry? entry;
  final String? prompt;

  @override
  State<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<JournalEditor> {
  late final TextEditingController _text = TextEditingController(text: widget.entry?.text ?? '');
  late String _mood = widget.entry?.mood ?? '🙂';
  late String _prompt = widget.entry?.prompt ?? widget.prompt ?? kJournalPrompts.first;
  late DateTime _date = widget.entry?.date ?? today();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final store = context.read<AppStore>();
    if (_text.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write something first.')));
      return;
    }
    JournalData.save(
      store,
      JournalEntry(
        id: widget.entry?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date: _date,
        mood: _mood,
        prompt: _prompt,
        text: _text.text.trim(),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final store = context.read<AppStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text("You can't undo this."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      JournalData.delete(store, widget.entry!.id);
      Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: today(),
    );
    if (d != null) setState(() => _date = dayOf(d));
  }

  void _pickPrompt() {
    showAppBottomSheet<void>(
      context,
      builder: (c) => AppBottomSheet(
        title: 'Pick a prompt',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final p in kJournalPrompts)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: Space.sm),
              shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
              title: Text(p),
              selected: p == _prompt,
              trailing: p == _prompt ? const Icon(Icons.check_rounded) : null,
              onTap: () {
                setState(() => _prompt = p);
                Navigator.pop(c);
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    return Scaffold(
      body: BloomPage(
        eyebrow: fmtLong(_date).toUpperCase(),
        title: widget.entry == null ? 'New entry' : 'Edit entry',
        actions: [
          if (widget.entry != null)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(fmtFull(_date)),
              onPressed: _pickDate,
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How do you feel?', style: t.titleMedium),
            Gap.v12,
            Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
              for (final m in kJournalMoods)
                _MoodButton(emoji: m, selected: m == _mood, onTap: () => setState(() => _mood = m)),
            ]),
          ]),
          BloomCard.tinted(
            color: BloomColors.luteal,
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.xs, Space.md),
            onTap: _pickPrompt,
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PROMPT',
                      style: t.labelSmall?.copyWith(
                          letterSpacing: 1, color: readableTint(BloomColors.luteal, theme.brightness))),
                  Gap.v4,
                  Text(_prompt, style: t.titleMedium),
                ]),
              ),
              IconButton(tooltip: 'Change prompt', onPressed: _pickPrompt, icon: const Icon(Icons.swap_horiz_rounded)),
            ]),
          ),
          TextField(
            controller: _text,
            minLines: 8,
            maxLines: null,
            autofocus: widget.entry == null,
            textCapitalization: TextCapitalization.sentences,
            style: t.bodyLarge?.copyWith(height: 1.6),
            decoration: const InputDecoration(hintText: 'Start writing...', alignLabelWithHint: true),
          ),
          GradientButton(label: 'Save entry', icon: Icons.check_rounded, expanded: true, onPressed: _save),
        ],
      ),
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({required this.emoji, required this.selected, required this.onTap});
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    const c = BloomColors.luteal;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: Motion.medium,
        curve: Motion.spring,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? c.withValues(alpha: dark ? 0.3 : 0.18) : theme.cardTheme.color,
            border: Border.all(
              color: selected ? c : BloomTokens.of(context).border,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24, height: 1))),
            ),
          ),
        ),
      ),
    );
  }
}
