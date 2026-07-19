import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Result of one controller operation.
///
/// [committed] is false when a newer request or disposal made this completion
/// stale. Stale operations never mutate visible state.
class PageOperationResult {
  const PageOperationResult._({required this.committed, this.error});

  const PageOperationResult.success() : this._(committed: true);

  const PageOperationResult.failure(Object error)
    : this._(committed: true, error: error);

  const PageOperationResult.stale() : this._(committed: false);

  final bool committed;
  final Object? error;

  bool get succeeded => committed && error == null;
}

/// A small generation token for page-owned async work that is not otherwise
/// worth moving into a full controller.
class RequestGenerationGuard {
  int _generation = 0;
  bool _disposed = false;

  int begin() => ++_generation;

  bool isCurrent(int generation) => !_disposed && generation == _generation;

  void invalidate() => _generation++;

  void dispose() {
    _disposed = true;
    _generation++;
  }
}

typedef PageFetcher<Q, T> = Future<List<T>> Function(Q query, int page);

/// Latest-query-wins controller for search, filter and ranking pages.
class PagedRequestController<Q, T> extends ChangeNotifier {
  PagedRequestController({required PageFetcher<Q, T> fetchPage})
    : _fetchPage = fetchPage;

  final PageFetcher<Q, T> _fetchPage;
  final List<T> _items = <T>[];

  Q? _query;
  Object? _error;
  int _page = 0;
  int _generation = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _disposed = false;

  UnmodifiableListView<T> get items => UnmodifiableListView<T>(_items);
  Q? get query => _query;
  Object? get error => _error;
  int get page => _page;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isDisposed => _disposed;

  Future<PageOperationResult> refresh(Q query) async {
    if (_disposed) return const PageOperationResult.stale();
    final generation = ++_generation;
    _query = query;
    _items.clear();
    _error = null;
    _page = 0;
    _hasMore = true;
    _isLoading = true;
    _isLoadingMore = false;
    notifyListeners();

    try {
      final values = await _fetchPage(query, 1);
      if (!_isCurrent(generation)) {
        return const PageOperationResult.stale();
      }
      _items
        ..clear()
        ..addAll(values);
      _page = 1;
      _hasMore = values.isNotEmpty;
      _isLoading = false;
      notifyListeners();
      return const PageOperationResult.success();
    } catch (error) {
      if (!_isCurrent(generation)) {
        return const PageOperationResult.stale();
      }
      _error = error;
      _isLoading = false;
      notifyListeners();
      return PageOperationResult.failure(error);
    }
  }

  Future<PageOperationResult> loadMore() async {
    if (_disposed || _isLoading || _isLoadingMore || !_hasMore) {
      return const PageOperationResult.stale();
    }
    final query = _query;
    if (query == null) return const PageOperationResult.stale();

    final generation = _generation;
    final nextPage = _page + 1;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final values = await _fetchPage(query, nextPage);
      if (!_isCurrent(generation)) {
        return const PageOperationResult.stale();
      }
      if (values.isEmpty) {
        _hasMore = false;
      } else {
        _items.addAll(values);
        _page = nextPage;
      }
      _isLoadingMore = false;
      notifyListeners();
      return const PageOperationResult.success();
    } catch (error) {
      if (!_isCurrent(generation)) {
        return const PageOperationResult.stale();
      }
      _isLoadingMore = false;
      notifyListeners();
      return PageOperationResult.failure(error);
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  List<String> validateInvariants() {
    final errors = <String>[];
    if (_page < 0) errors.add('page must be non-negative');
    if (_isLoading && _isLoadingMore) {
      errors.add('initial and load-more states cannot both be loading');
    }
    if (_page == 0 && _items.isNotEmpty) {
      errors.add('items require at least one committed page');
    }
    return errors;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

typedef EntityDetailsFetcher<I, D> = Future<D> Function(I id);
typedef EntityListFetcher<I, T> = Future<List<T>> Function(I id);

/// Parallel details/subjects/related state used by character and person pages.
class EntityDetailsController<I, D, S, R> extends ChangeNotifier {
  EntityDetailsController({
    required EntityDetailsFetcher<I, D> fetchDetails,
    required EntityListFetcher<I, S> fetchSubjects,
    EntityListFetcher<I, R>? fetchRelated,
  }) : _fetchDetails = fetchDetails,
       _fetchSubjects = fetchSubjects,
       _fetchRelated = fetchRelated;

  final EntityDetailsFetcher<I, D> _fetchDetails;
  final EntityListFetcher<I, S> _fetchSubjects;
  final EntityListFetcher<I, R>? _fetchRelated;

  D? _details;
  List<S> _subjects = <S>[];
  List<R> _related = <R>[];
  Object? _detailsError;
  Object? _subjectsError;
  Object? _relatedError;
  bool _isLoadingDetails = false;
  bool _isLoadingSubjects = false;
  bool _isLoadingRelated = false;
  int _generation = 0;
  bool _disposed = false;

  D? get details => _details;
  UnmodifiableListView<S> get subjects => UnmodifiableListView<S>(_subjects);
  UnmodifiableListView<R> get related => UnmodifiableListView<R>(_related);
  Object? get detailsError => _detailsError;
  Object? get subjectsError => _subjectsError;
  Object? get relatedError => _relatedError;
  bool get isLoadingDetails => _isLoadingDetails;
  bool get isLoadingSubjects => _isLoadingSubjects;
  bool get isLoadingRelated => _isLoadingRelated;
  bool get isDisposed => _disposed;

  Future<void> load(I id) async {
    if (_disposed) return;
    final generation = ++_generation;
    _details = null;
    _subjects = <S>[];
    _related = <R>[];
    _detailsError = null;
    _subjectsError = null;
    _relatedError = null;
    _isLoadingDetails = true;
    _isLoadingSubjects = true;
    _isLoadingRelated = _fetchRelated != null;
    notifyListeners();

    final operations = <Future<void>>[
      _loadDetails(id, generation),
      _loadSubjects(id, generation),
      if (_fetchRelated != null) _loadRelated(id, generation),
    ];
    await Future.wait(operations);
  }

  Future<void> _loadDetails(I id, int generation) async {
    try {
      final value = await _fetchDetails(id);
      if (!_isCurrent(generation)) return;
      _details = value;
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _detailsError = error;
    } finally {
      if (_isCurrent(generation)) {
        _isLoadingDetails = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadSubjects(I id, int generation) async {
    try {
      final values = await _fetchSubjects(id);
      if (!_isCurrent(generation)) return;
      _subjects = List<S>.from(values);
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _subjectsError = error;
    } finally {
      if (_isCurrent(generation)) {
        _isLoadingSubjects = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadRelated(I id, int generation) async {
    try {
      final values = await _fetchRelated!(id);
      if (!_isCurrent(generation)) return;
      _related = List<R>.from(values);
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _relatedError = error;
    } finally {
      if (_isCurrent(generation)) {
        _isLoadingRelated = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
