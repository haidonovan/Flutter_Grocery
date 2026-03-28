import 'package:flutter/material.dart';

typedef SuggestionItemBuilder<T> = Widget Function(BuildContext context, T item);

class SuggestionSearchField<T> extends StatefulWidget {
  const SuggestionSearchField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.suggestions,
    required this.decoration,
    required this.itemBuilder,
    required this.selectionTextBuilder,
    this.onSelected,
    this.loading = false,
    this.emptyStateText,
    this.maxSuggestionHeight = 220,
    this.textInputAction,
    this.onSubmitted,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final List<T> suggestions;
  final InputDecoration decoration;
  final SuggestionItemBuilder<T> itemBuilder;
  final String Function(T item) selectionTextBuilder;
  final ValueChanged<T>? onSelected;
  final bool loading;
  final String? emptyStateText;
  final double maxSuggestionHeight;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SuggestionSearchField<T>> createState() =>
      _SuggestionSearchFieldState<T>();
}

class _SuggestionSearchFieldState<T> extends State<SuggestionSearchField<T>> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isSelectingSuggestion = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant SuggestionSearchField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _shouldShowSuggestions {
    final hasQuery = widget.value.trim().isNotEmpty;
    if ((!_focusNode.hasFocus && !_isSelectingSuggestion) || !hasQuery) {
      return false;
    }
    return widget.loading ||
        widget.suggestions.isNotEmpty ||
        widget.emptyStateText != null;
  }

  void _selectSuggestion(T item) {
    if (_isSelectingSuggestion) {
      return;
    }
    _isSelectingSuggestion = true;
    final selectionText = widget.selectionTextBuilder(item);
    _controller.value = TextEditingValue(
      text: selectionText,
      selection: TextSelection.collapsed(offset: selectionText.length),
    );
    widget.onChanged(selectionText);
    widget.onSelected?.call(item);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.unfocus();
      setState(() {
        _isSelectingSuggestion = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: widget.textInputAction,
          decoration: widget.decoration,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
        ),
        if (_shouldShowSuggestions) ...[
          const SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(maxHeight: widget.maxSuggestionHeight),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: widget.loading
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  )
                : widget.suggestions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.emptyStateText ?? 'No suggestions yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: widget.suggestions.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: scheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final item = widget.suggestions[index];
                      return InkWell(
                        onTapDown: (_) => _selectSuggestion(item),
                        onTap: () {},
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: widget.itemBuilder(context, item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
