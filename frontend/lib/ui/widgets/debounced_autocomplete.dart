import 'dart:async';

import 'package:flutter/material.dart';

class _CancelException implements Exception {
  const _CancelException();
}

// An exception indicating that a network request has failed.
// ignore: unused_element
class _NetworkException implements Exception {
  const _NetworkException();
}

class AsyncAutocomplete<T extends Object> extends StatefulWidget {
  const AsyncAutocomplete({
    super.key,
    required this.onSelected,
    this.onChanged,
    // required this.optionsBuilder,
    required this.optionsViewBuilder,
    required this.search,
    required this.displayStringForOption,
    required this.initialValue,
    required this.textController,
    this.decorationField,
    this.validator,
    this.node,
  });

  final void Function(T) onSelected;
  // final FutureOr<Iterable<T>> Function(TextEditingValue textEditingValue)
  //     optionsBuilder;

  final Future<List<T>> Function(String query) search;
  final Widget Function(BuildContext context, void Function(T) onSelected,
      Iterable<T> options)? optionsViewBuilder;
  final void Function(String)? onChanged;
  final String Function(T) displayStringForOption;
  final TextEditingValue? initialValue;
  final TextEditingController textController;
  final InputDecoration? decorationField;
  final String? Function(String?)? validator;
  final FocusNode? node;
  @override
  State<AsyncAutocomplete<T>> createState() => _AsyncAutocompleteState<T>();
}

class _AsyncAutocompleteState<T extends Object>
    extends State<AsyncAutocomplete<T>> {
  // The query currently being searched for. If null, there is no pending
  // request.
  String? _currentQuery;
  late FocusNode _node;

  // The most recent options received from the API.
  late Iterable<T> _lastOptions = <T>[];

  late final _Debounceable<Iterable<T>?, String> _debouncedSearch;

  // Calls the "remote" API to search with the given query. Returns null when
  // the call has been made obsolete.
  Future<Iterable<T>?> _search(String query) async {
    _currentQuery = query;

    late final Iterable<T> options;
    try {
      options = await widget.search(_currentQuery!);
    } catch (error) {
      if (error is _NetworkException) {
        // setState(() {
        //   _networkError = true;
        // });
        return <T>[];
      }
      rethrow;
    }

    // If another search happened after this one, throw away these options.
    if (_currentQuery != query) {
      return null;
    }
    _currentQuery = null;

    return options;
  }

  @override
  void initState() {
    super.initState();
    _debouncedSearch = _debounce<Iterable<T>?, String>(_search);
    _node = widget.node ?? FocusNode(debugLabel: 'AutoCompleteField');
  }

  void requestFocus() {
    _node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<T>(
      focusNode: _node,
      textEditingController: widget.textController,
      fieldViewBuilder: (BuildContext context, TextEditingController controller,
          FocusNode focusNode, VoidCallback onFieldSubmitted) {
        // controller.text = widget.textController.text;
        return TextFormField(
          // initialValue: widget.textController.text,
          validator: widget.validator,
          decoration: widget.decorationField,
          controller: controller,
          focusNode: focusNode,
          onFieldSubmitted: (String value) {
            onFieldSubmitted();
          },
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) async {
        // setState(() {
        //   _networkError = false;
        // });
        if (widget.onChanged != null) {
          widget.onChanged!.call(textEditingValue.text);
        }

        final options = await _debouncedSearch(textEditingValue.text);
        if (options == null) {
          return _lastOptions;
        }
        _lastOptions = options;
        return options;
      },
      // initialValue: widget.initialValue,
      displayStringForOption: widget.displayStringForOption,
      optionsViewBuilder: widget.optionsViewBuilder!,
      onSelected: widget.onSelected,
    );
  }
}

typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

/// Returns a new function that is a debounced version of the given function.
///
/// This means that the original function will be called only after no calls
/// have been made for the given Duration.
_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    // TODO: expose parameter
    debounceTimer = _DebounceTimer(duration: const Duration(milliseconds: 50));
    try {
      await debounceTimer!.future;
    } catch (error) {
      if (error is _CancelException) {
        return null;
      }
      rethrow;
    }
    return function(parameter);
  };
}

// A wrapper around Timer used for debouncing.
class _DebounceTimer {
  _DebounceTimer({required Duration duration}) {
    _timer = Timer(duration, _onComplete);
  }

  late final Timer _timer;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    _completer.completeError(const _CancelException());
  }
}

// An exception indicating that the timer was canceled.
