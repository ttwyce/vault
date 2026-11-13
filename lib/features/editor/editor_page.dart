
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/markdown_preview_view.dart';

import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/db/vault_database.dart' show CategoryRow;
import '../../data/entry/entry_models.dart';
import '../../data/diary/diary_meta.dart';
import '../../data/entry/entry_repository_provider.dart';
import '../../data/entry/note_meta.dart';
import '../../data/taxonomy/inline_tag_parser.dart';
import '../../data/taxonomy/taxonomy_models.dart';
import '../../data/taxonomy/taxonomy_suggestions.dart';
import '../../data/taxonomy/taxonomy_repository_provider.dart';
import '../../data/write/write_gateway.dart';
import 'markdown_insert.dart';

/// 条目编辑器。新建（`entryId == null`）与编辑（`entryId != null`）共用。
///
/// 保存是「一次完整提交」：正文走 `EntryWrite`，分类/标签走
/// `setEntryTaxonomy`。两者是**独立同步实体**，不能把分类塞进
/// `entry.meta` —— 那样同名分类合并、删除分类后条目回未分类都得改 meta，
/// 双写必然不一致（docs/11 §2.6）。
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({
    super.key,
    this.entryId,
    this.initialKind = EntryKind.note,
    this.initialDate,
    this.initialBody,
  });

  /// 为 null 表示新建；非空表示编辑已有条目。
  final String? entryId;

  /// 新建时的类型。编辑态以数据库里的 `kind` 为准。
  final EntryKind initialKind;

  /// 新建日记的归属日期（YYYY-MM-DD）；补写过去某一天时由日记页传入。
  final String? initialDate;

  /// 新建时预填的正文（日记模板）；编辑已有条目时忽略。
  final String? initialBody;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  late EntryKind _kind = widget.initialKind;
  String? _inlineTagHint;

  /// 编辑态下从数据库读到的旧 `meta`。保存时要原样传回 ——
  /// 日记日期等扩展字段都住在 meta 里，不传回就等于把扩展字段清掉。
  String? _existingMeta;

  bool _preview = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  List<CategoryRow> _categories = const <CategoryRow>[];
  List<TagWithCount> _tags = const <TagWithCount>[];
  String? _categoryId;
  List<String> _tagIds = const <String>[];
  TaxonomySuggestion? _suggestion;
  bool _pinned = false;
  String? _diaryWeather;
  String? _diaryMood;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// 一次性取齐「正文 + 可选分类标签 + 当前关联」。
  ///
  /// 分两次 setState 会让页面在中间态闪一下「未分类」，
  /// 用户如果恰好在那一瞬点保存，就会把已有分类清掉。
  Future<void> _bootstrap() async {
    if (widget.entryId != null) setState(() => _loading = true);

    final entryRepo = ref.read(entryRepositoryProvider);
    final categories = await entryRepo.categories();
    final tags = await entryRepo.tags();

    String title = '';
    String body = '';
    String? existingMeta;
    EntryKind kind = widget.initialKind;
    String? notFound;
    String? categoryId;
    List<String> tagIds = const <String>[];
    bool pinned = false;
    String? weather;
    String? mood;

    final id = widget.entryId;
    if (id != null) {
      final row = await entryRepo.getRow(id);
      if (row == null) {
        notFound = '这条内容不存在，可能已被删除。';
      } else {
        title = row.title ?? '';
        body = row.body ?? '';
        existingMeta = row.meta;
        kind = EntryKind.fromCode(row.kind) ?? widget.initialKind;
        if (kind == EntryKind.note || kind == EntryKind.thought) {
          pinned = NoteMeta.fromJson(existingMeta).pinned;
        } else if (kind == EntryKind.diary) {
          final diaryMeta = DiaryMeta.fromJson(existingMeta);
          weather = diaryMeta.weather;
          mood = diaryMeta.mood;
        }
        final taxonomyRepo = ref.read(taxonomyRepositoryProvider);
        categoryId = await taxonomyRepo.categoryForEntry(id);
        tagIds = await taxonomyRepo.tagIdsForEntry(id);
      }
    }

    if (!mounted) return;
    _title.text = title;
    _body.text = widget.entryId == null
        ? (widget.initialBody ?? body)
        : body;
    setState(() {
      _categories = categories;
      _tags = tags;
      _categoryId = categoryId;
      _tagIds = tagIds;
      _existingMeta = existingMeta;
      _kind = kind;
      _pinned = pinned;
      _diaryWeather = weather;
      _diaryMood = mood;
      _error = notFound;
      _loading = false;
    });
    _refreshSuggestion();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    // 标题为空时用正文首行兜底（读侧 `displayTitle` 也做同样的事，
    // 这里在写侧就规范化，保证存进去的标题不是空串）。
    final String title = displayTitle(_title.text, _body.text);
    final String body = _body.text;

    final gateway = ref.read(writeGatewayProvider);
    try {
      late final String entryId;
      if (widget.entryId == null) {
        // 日记的日期是显式字段（补写需求），新建时落今天。
        String? meta;
        if (_kind == EntryKind.diary) {
          final now = DateTime.now();
          final date = widget.initialDate ?? diaryKey(now);
          meta = buildDiaryMeta(
            date: date,
            body: body,
            createdAtMs: now.millisecondsSinceEpoch,
            weather: _diaryWeather,
            mood: _diaryMood,
          ).toJsonString();
        } else if (_kind == EntryKind.note ||
            _kind == EntryKind.thought) {
          // docs/13 §3：笔记/想法 meta 只放 pinned + word_count；
          // 标签一律走关联表，不双写。
          meta = noteMetaForSave(null, body)
              .copyWith(pinned: _pinned)
              .toJsonString();
        }
        final created = await gateway.writeEntry(
          EntryWrite.create(kind: _kind, title: title, body: body, meta: meta),
        );
        entryId = created.snapshot.id;
      } else {
        // update 是整体替换语义：没改的字段（meta）也要原样传回。
        await gateway.writeEntry(
          EntryWrite.update(
            id: widget.entryId!,
            title: title,
            body: body,
            meta: _refreshedMeta(_existingMeta, body),
          ),
        );
        entryId = widget.entryId!;
      }

      // 关联整体替换，没选就是「未分类 / 无标签」。写入口会判幂等，
      // 没变化时不产生 oplog，所以每次保存都不会制造无意义的新版本。
      await gateway.setEntryTaxonomy(
        entryId: entryId,
        categoryId: _categoryId,
        tagIds: _tagIds,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on WriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Markdown 工具栏
  // ---------------------------------------------------------------------------

  /// 工具栏只改 `TextEditingController`，不触发保存。
  ///
  /// 插入后显式回写 `selection`：`value.copyWith(text:)` 若不带 selection，
  /// 光标会留在旧偏移量上，下一字符就插到错误位置。
  void _applyMarkdown(MarkdownAction action) {
    final selection = _body.selection;
    final edit = applyMarkdownAction(
      text: _body.text,
      selectionStart: selection.start,
      selectionEnd: selection.end,
      action: action,
    );
    _body.value = _body.value.copyWith(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.cursor),
      composing: TextRange.empty,
    );
  }

  Widget _buildMarkdownBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: SketchSpace.sm),
      child: Wrap(
        spacing: SketchSpace.sm,
        runSpacing: SketchSpace.sm,
        children: <Widget>[
          for (final action in MarkdownAction.values)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _saving ? null : () => _applyMarkdown(action),
              child: SketchTag(
                action.label,
                tone: SketchTone.ghost,
                dense: true,
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 分类 / 标签选择
  // ---------------------------------------------------------------------------

  String get _categoryLabel {
    final id = _categoryId;
    if (id == null) return '未分类';
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return '已删除的分类';
  }

  String _tagName(String id) {
    for (final t in _tags) {
      if (t.id == id) return t.name;
    }
    return id.length > 6 ? '${id.substring(0, 6)}…' : id;
  }

  Future<void> _pickCategory() async {
    // 空串代表「未分类」，null 代表用户点外部取消了选择 —— 两者不能混。
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        final p = sheetContext.sketch;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: const Text('未分类'),
                onTap: () => Navigator.of(sheetContext).pop(''),
              ),
              for (final c in _categories)
                ListTile(
                  title: Text(c.parentId == null ? c.name : '　└ ${c.name}'),
                  onTap: () => Navigator.of(sheetContext).pop(c.id),
                ),
              if (_categories.isEmpty)
                ListTile(
                  title: Text('还没有分类', style: TextStyle(color: p.muted)),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _categoryId = picked.isEmpty ? null : picked);
  }

  Future<void> _pickTags() async {
    final selected = <String>{..._tagIds};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) {
          final p = ctx.sketch;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(SketchSpace.md),
                  child: Text(
                    '最多 ${TaxonomyRules.maxTagsPerEntry} 个标签'
                    '（已选 ${selected.length}）',
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final t in _tags)
                        CheckboxListTile(
                          value: selected.contains(t.id),
                          title: Text(t.name),
                          onChanged: (bool? value) {
                            setSheetState(() {
                              if (value == true) {
                                if (selected.length >=
                                    TaxonomyRules.maxTagsPerEntry) {
                                  return;
                                }
                                selected.add(t.id);
                              } else {
                                selected.remove(t.id);
                              }
                            });
                          },
                        ),
                      if (_tags.isEmpty)
                        ListTile(
                          title: Text('还没有标签',
                              style: TextStyle(color: p.muted)),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _tagIds = selected.toList(growable: false));
  }

  String get _kindLabel => switch (_kind) {
        EntryKind.note => '笔记',
        EntryKind.thought => '想法',
        EntryKind.diary => '日记',
        EntryKind.aiDiary => 'AI 日记',
        EntryKind.bookmark => '归档',
        EntryKind.credential => '密码',
      };

  /// 编辑日记时保留 weather/mood/location/date，只刷新字数与补写标记。
  String? _refreshedDiaryMeta(String? raw, String body) {
    if (_kind != EntryKind.diary || raw == null || raw.trim().isEmpty) {
      return raw;
    }
    final DiaryMeta old;
    try {
      old = DiaryMeta.fromJson(raw);
    } on Object {
      return raw; // 坏 meta 不猜测、不覆盖，交给读侧隔离。
    }
    final now = DateTime.now();
    return old.copyWith(
      weather: _diaryWeather,
      mood: _diaryMood,
      clearWeather: _diaryWeather == null,
      clearMood: _diaryMood == null,
      wordCount: countDiaryWords(body),
      backfilled:
          isBackfilled(date: old.date, createdAtMs: now.millisecondsSinceEpoch),
    ).toJsonString();
  }

  /// 编辑态整体刷新 meta：日记刷新日期类字段；笔记/想法保留 pinned
  /// 并刷新 word_count；其它 kind 原样不动，避免覆盖各自扩展字段。
  String? _refreshedMeta(String? raw, String body) {
    if (_kind == EntryKind.diary) {
      return _refreshedDiaryMeta(raw, body);
    }
    if (_kind != EntryKind.note && _kind != EntryKind.thought) {
      return raw;
    }
    return NoteMeta.fromJson(raw).copyWith(
      pinned: _pinned,
      wordCount: countNoteWords(body),
    ).toJsonString();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    // 编辑器是被 push 出来的独立路由，没有 AppShell 的 Scaffold 兜底，
    // 必须自带 —— 否则 TextField 找不到 Material 祖先，直接崩。
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: widget.entryId == null ? '新建$_kindLabel' : '编辑$_kindLabel',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          SketchButton(
            label: _preview ? '编辑' : '预览',
            dense: true,
            onPressed: () => setState(() => _preview = !_preview),
          ),
          SketchButton(
            label: _saving ? '保存中…' : '保存',
            tone: SketchTone.primary,
            glyph: SketchGlyph.plus,
            onPressed: (_loading || _saving) ? null : _save,
          ),
        ],
        child: _buildBody(p),
      ),
    );
  }

  Widget _buildBody(SketchPalette p) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: p.red));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SketchSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_error != null) ...<Widget>[
            const SizedBox(height: SketchSpace.md),
            SketchFrame(
              radius: SketchRadii.cycle(1),
              fill: p.surface,
              borderColor: p.red,
              padding: const EdgeInsets.all(SketchSpace.md),
              tilt: SketchTilt.left,
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, height: 1.7, color: p.ink),
              ),
            ),
          ],
          TextField(
            controller: _title,
            enabled: !_saving,
            autofocus: widget.entryId == null,
            minLines: 1,
            // 标题有界：`maxLines: null` 在 Flex 里是无界高度，会把布局撑爆
            maxLines: 3,
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: p.ink,
            ),
            cursorColor: p.red,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '标题',
              hintStyle: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: p.muted),
            ),
          ),
          if (_inlineTagHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: SketchSpace.xs),
              child: Text(
                _inlineTagHint!,
                style: TextStyle(fontSize: 10.5, color: p.blue),
              ),
            ),
          _buildTaxonomyRow(),
          _buildDiaryMetaRow(),
          _buildSuggestionRow(),
          _buildMarkdownBar(),
          Expanded(
            child: _preview
                ? MarkdownPreview(source: _body.text)
                : TextField(
                    controller: _body,
                    enabled: !_saving,
                    onChanged: (String value) {
                      final trigger = detectInlineTag(
                        value,
                        _body.selection.baseOffset,
                      );
                      final hint = trigger.active
                          ? '输入 #${trigger.query}：匹配已有标签，'
                              '回车可采纳（上限 ${TaxonomyRules.maxTagsPerEntry}）'
                          : null;
                      setState(() {
                        _inlineTagHint = hint;
                        _refreshSuggestion();
                      });
                    },
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    style:
                        TextStyle(fontSize: 14, height: 1.8, color: p.ink),
                    cursorColor: p.red,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '开始写…',
                      hintStyle: TextStyle(
                          fontSize: 14, height: 1.8, color: p.muted),
                    ),
                  ),
          ),
          const SizedBox(height: SketchSpace.md),
        ],
      ),
    );
  }

  /// docs/11 §2.5：按标题/正文给 1 个分类 + 2~4 个标签建议，
  /// **只展示不自动写入**，采纳必须由用户点 chip。
  void _refreshSuggestion() {
    final next = suggestTaxonomy(
      title: _title.text,
      body: _body.text,
      categories: <({String id, String name})>[
        for (final c in _categories) (id: c.id, name: c.name),
      ],
      tags: _tags,
      existingTagIds: _tagIds.toSet(),
    );
    if (_suggestion?.toJson().toString() == next.toJson().toString()) return;
    _suggestion = next;
  }

  void _adoptSuggestion() {
    final suggestion = _suggestion;
    if (suggestion == null || suggestion.isEmpty) return;
    setState(() {
      if (suggestion.categoryId != null && _categoryId == null) {
        _categoryId = suggestion.categoryId;
      }
      final merged = <String>{..._tagIds, ...suggestion.tagIds}.toList();
      _tagIds = merged.length > TaxonomyRules.maxTagsPerEntry
          ? merged.sublist(0, TaxonomyRules.maxTagsPerEntry)
          : merged;
      _suggestion = null;
    });
  }

  Widget _buildTaxonomyRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: SketchSpace.sm),
      child: Wrap(
        spacing: SketchSpace.sm,
        runSpacing: SketchSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          GestureDetector(
            onTap: _saving ? null : _pickCategory,
            child: SketchTag(
              _categoryLabel,
              tone: _categoryId == null ? SketchTone.ghost : SketchTone.primary,
              dense: true,
            ),
          ),
          for (final id in _tagIds)
            GestureDetector(
              onTap: _saving ? null : _pickTags,
              child: SketchTag(
                '#${_tagName(id)}',
                tone: SketchTone.blue,
                dense: true,
              ),
            ),
          GestureDetector(
            onTap: _saving ? null : _pickTags,
            child: SketchTag('＋ 标签', tone: SketchTone.ghost, dense: true),
          ),
          if (_kind == EntryKind.note || _kind == EntryKind.thought)
            GestureDetector(
              onTap: _saving
                  ? null
                  : () => setState(() => _pinned = !_pinned),
              child: SketchTag(
                _pinned ? '已置顶' : '置顶',
                tone: _pinned ? SketchTone.primary : SketchTone.ghost,
                dense: true,
              ),
            ),
        ],
      ),
    );
  }

  /// 日记的天气 / 心情选择（docs/11 §1.5）。只写 meta，不动正文。
  Widget _buildDiaryMetaRow() {
    if (_kind != EntryKind.diary) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: SketchSpace.sm),
      child: Wrap(
        spacing: SketchSpace.sm,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _saving ? null : _cycleWeather,
            child: SketchTag(
              '天气：${_diaryWeather ?? "未填"}',
              tone: SketchTone.ghost,
              dense: true,
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _saving ? null : _cycleMood,
            child: SketchTag(
              '心情：${_diaryMood ?? "未填"}',
              tone: SketchTone.ghost,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  /// 天气 / 心情用「点一下换下一个」的轻量循环选择，避免弹层打断输入。
  static const List<String?> _weatherOptions = <String?>[
    null, '晴', '阴', '雨', '雪', '多云',
  ];

  static const List<String?> _moodOptions = <String?>[
    null, '平静', '好', '一般', '糟',
  ];

  void _cycleWeather() {
    final i = _weatherOptions.indexOf(_diaryWeather);
    setState(() => _diaryWeather =
        _weatherOptions[(i + 1) % _weatherOptions.length]);
  }

  void _cycleMood() {
    final i = _moodOptions.indexOf(_diaryMood);
    setState(
        () => _diaryMood = _moodOptions[(i + 1) % _moodOptions.length]);
  }

  Widget _buildSuggestionRow() {
    final suggestion = _suggestion;
    if (suggestion == null || suggestion.isEmpty || _saving) {
      return const SizedBox.shrink();
    }
    final labels = <String>[
      if (suggestion.categoryName != null) '分类：${suggestion.categoryName}',
      for (final name in suggestion.tagNames) '#$name',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: SketchSpace.sm),
      child: GestureDetector(
        onTap: _adoptSuggestion,
        child: SketchTag(
          '建议（点采纳，不自动写入）：${labels.join(' · ')}',
          tone: SketchTone.plain,
          dense: true,
        ),
      ),
    );
  }
}
