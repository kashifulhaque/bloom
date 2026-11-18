/// Private, local reflective journal with prompts, set as dated diary pages
/// on ruled paper.
library;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'insights_data.dart';

/// The journal list, shown as a tab of the Library screen.
class JournalView extends StatelessWidget {
  const JournalView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final entries = JournalData.entries(store);
    final p = BloomColors.of(context);
    final prompt = kJournalPrompts[daysBetween(DateTime(2024), today()) % kJournalPrompts.length];

    return BloomPage(
      showBack: false,
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, Space.xxl),
      children: [
        // Today's prompt, set as an epigraph.
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            BotanicalGlyph(Botanical.sprig, size: 20, color: p.ink2),
            Gap.h8,
            const MonoLabel("Today's prompt"),
          ]),
          Gap.v12,
          Text(prompt, style: Almanac.italic(context, size: 25).copyWith(height: 1.3)),
          Gap.v20,
          Wrap(spacing: Space.lg, runSpacing: Space.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            InkButton(label: 'Write', icon: Icons.edit_outlined, dense: true, onPressed: () => openJournalEditor(context, prompt: prompt)),
            InkLink('Choose another prompt', size: 13.5, onTap: () => openJournalEditor(context)),
          ]),
        ]),
        Row(children: [
          Icon(Icons.lock_outline, size: 13, color: p.ink2),
          Gap.h8,
          const Expanded(child: MonoLabel('Kept on this device. Nobody else can read it.', size: 9.5)),
        ]),
        if (entries.isEmpty)
          const EmptyState(
            glyph: Botanical.sprout,
            title: 'The first page is blank',
            body: 'A few lines a day can help you notice how your mood moves with your cycle.',
            compact: true,
          )
        else ...[
          SectionHeader('Diary', label: '${entries.length} ${entries.length == 1 ? 'page' : 'pages'}', padding: const EdgeInsets.only(top: Space.xl)),
          Column(children: [
            for (final e in entries) ...[const Hairline(), _EntryPage(entry: e)],
            const Hairline(),
          ]),
        ],
      ],
    );
  }
}

/// One diary page: a mono date, the mood the user chose, the serif first
/// line, and the rest of the entry on ruled lines.
class _EntryPage extends StatelessWidget {
  const _EntryPage({required this.entry});
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final e = entry;
    final text = e.text.trim();
    final nl = text.indexOf('\n');
    final firstLine = nl < 0 ? text : text.substring(0, nl).trim();
    final rest = nl < 0 ? '' : text.substring(nl + 1).trim();
    const lineHeight = 26.0;
    return Pressable(
      semanticLabel: 'Journal entry, ${DateFormat('EEEE d MMMM').format(e.date)}',
      onTap: () => openJournalEditor(context, entry: e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: MonoLabel(DateFormat('EEE d MMM yyyy').format(e.date))),
            Text(e.mood, style: const TextStyle(fontSize: 15, height: 1)),
          ]),
          if (e.prompt.isNotEmpty) ...[
            Gap.v8,
            Text(e.prompt, maxLines: 1, overflow: TextOverflow.ellipsis, style: Almanac.italic(context, size: 14, color: p.ink2)),
          ],
          Gap.v8,
          Text(firstLine, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: Almanac.serif(size: 19, weight: 370, color: p.ink, height: 1.3)),
          if (rest.isNotEmpty)
            RuledText(
              rest,
              maxLines: 3,
              lineHeight: lineHeight,
              style: Almanac.sans(size: 14.5, color: p.ink),
            ),
        ]),
      ),
    );
  }
}

/// Text on ruled lines: a hairline under every line, like a notebook page.
class RuledText extends StatelessWidget {
  const RuledText(this.text, {super.key, required this.style, this.lineHeight = 26, this.maxLines});
  final String text;
  final TextStyle style;
  final double lineHeight;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final s = style.copyWith(height: lineHeight / style.fontSize!);
    return CustomPaint(
      painter: _RulesPainter(color: BloomColors.of(context).hairline, lineHeight: lineHeight),
      child: Text(text, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, style: s),
    );
  }
}

class _RulesPainter extends CustomPainter {
  _RulesPainter({required this.color, required this.lineHeight, this.minLines = 0});
  final Color color;
  final double lineHeight;
  final int minLines;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final lines = (size.height / lineHeight).floor().clamp(minLines, 999);
    for (var i = 1; i <= lines; i++) {
      final y = i * lineHeight - 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RulesPainter old) => old.color != color || old.lineHeight != lineHeight || old.minLines != minLines;
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
    Almanac.tick();
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final store = context.read<AppStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tear out this page?'),
        content: const Text("This deletes the entry from this device. You can't undo it."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BloomColors.resolve(c, BloomColors.error)),
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
      builder: (c) {
        final p = BloomColors.of(c);
        return AppBottomSheet(
          eyebrow: 'Prompts',
          title: 'Pick a prompt',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < kJournalPrompts.length; i++) ...[
              if (i > 0) const Hairline(),
              Pressable(
                selected: kJournalPrompts[i] == _prompt,
                onTap: () {
                  setState(() => _prompt = kJournalPrompts[i]);
                  Navigator.pop(c);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.md),
                  child: Row(children: [
                    SizedBox(width: 32, child: Text(i < 9 ? '0${i + 1}' : '${i + 1}', style: Almanac.data(c, size: 11.5))),
                    Expanded(
                      child: Text(
                        kJournalPrompts[i],
                        style: kJournalPrompts[i] == _prompt
                            ? Almanac.italic(c, size: 17)
                            : Almanac.sans(size: 15, color: p.ink, height: 1.4),
                      ),
                    ),
                    if (kJournalPrompts[i] == _prompt) Icon(Icons.check, size: 18, color: p.ink),
                  ]),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    const lineHeight = 30.0;
    final bodyStyle = Almanac.sans(size: 16.5, color: p.ink, height: lineHeight / 16.5);
    return Scaffold(
      body: BloomPage(
        eyebrow: 'Journal · ${fmtLong(_date)}',
        title: widget.entry == null ? 'A new page' : 'Edit this page',
        actions: [
          if (widget.entry != null)
            IconButton(tooltip: 'Delete', icon: Icon(Icons.delete_outline, color: p.ink2, size: 20), onPressed: _delete),
          InkLink('Save', onTap: _save),
        ],
        children: [
          Marginalia(
            label: 'Dated',
            child: Align(alignment: Alignment.centerLeft, child: InkLink(fmtFull(_date), size: 14, onTap: _pickDate)),
          ),
          Marginalia(
            label: 'Mood',
            child: Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
              for (final m in kJournalMoods)
                _MoodButton(emoji: m, selected: m == _mood, onTap: () => setState(() => _mood = m)),
            ]),
          ),
          Marginalia(
            label: 'Prompt',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_prompt, style: Almanac.italic(context, size: 19).copyWith(height: 1.35)),
              InkLink('Change prompt', size: 13, onTap: _pickPrompt),
            ]),
          ),
          const Hairline(),
          CustomPaint(
            painter: _RulesPainter(color: p.hairline, lineHeight: lineHeight, minLines: 8),
            child: TextField(
              controller: _text,
              minLines: 8,
              maxLines: null,
              autofocus: widget.entry == null,
              textCapitalization: TextCapitalization.sentences,
              style: bodyStyle,
              strutStyle: StrutStyle(fontSize: 16.5, height: lineHeight / 16.5, forceStrutHeight: true),
              decoration: InputDecoration(
                hintText: 'Begin here…',
                hintStyle: Almanac.italic(context, size: 17, color: p.ink2),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                contentPadding: const EdgeInsets.only(top: 3),
              ),
            ),
          ),
          Gap.v8,
          InkButton(label: 'Save entry', icon: Icons.check, expanded: true, onPressed: _save),
        ],
      ),
    );
  }
}

/// A user-chosen mood: the emoji in a small hairline square, outlined in
/// ink when selected.
class _MoodButton extends StatelessWidget {
  const _MoodButton({required this.emoji, required this.selected, required this.onTap});
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Pressable(
      selected: selected,
      semanticLabel: 'Mood $emoji',
      borderRadius: Radii.mdAll,
      onTap: () {
        Almanac.tick();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.curve,
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: Radii.mdAll,
          border: Border.all(color: selected ? p.ink : Colors.transparent, width: selected ? 1.2 : 1),
        ),
        child: AnimatedOpacity(
          duration: Motion.medium,
          opacity: selected ? 1 : 0.65,
          child: Text(emoji, style: const TextStyle(fontSize: 20, height: 1)),
        ),
      ),
    );
  }
}
