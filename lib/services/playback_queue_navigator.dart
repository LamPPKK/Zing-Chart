import 'dart:math';

/// Serializable traversal state for [PlaybackQueueNavigator].
///
/// The queue order and the shuffle traversal order are stored separately. The
/// history cursor can therefore move backwards and forwards without losing the
/// frontier of the active shuffle cycle.
class PlaybackQueueNavigatorState {
  PlaybackQueueNavigatorState({
    required Iterable<String> queueIds,
    required this.shuffleEnabled,
    required Iterable<String> traversalOrderIds,
    required this.traversalCursor,
    required Iterable<String> historyIds,
    required this.historyCursor,
    required this.currentId,
  }) : queueIds = List.unmodifiable(_uniqueIds(queueIds)),
       traversalOrderIds = List.unmodifiable(_uniqueIds(traversalOrderIds)),
       historyIds = List.unmodifiable(_historyIds(historyIds));

  static const int schemaVersion = 1;

  final List<String> queueIds;
  final bool shuffleEnabled;
  final List<String> traversalOrderIds;
  final int traversalCursor;
  final List<String> historyIds;
  final int historyCursor;
  final String? currentId;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'queueIds': queueIds,
    'shuffleEnabled': shuffleEnabled,
    'traversalOrderIds': traversalOrderIds,
    'traversalCursor': traversalCursor,
    'historyIds': historyIds,
    'historyCursor': historyCursor,
    'currentId': currentId,
  };

  factory PlaybackQueueNavigatorState.fromJson(Map<String, dynamic> json) {
    return PlaybackQueueNavigatorState(
      queueIds: _stringList(json['queueIds']),
      shuffleEnabled: json['shuffleEnabled'] == true,
      traversalOrderIds: _stringList(json['traversalOrderIds']),
      traversalCursor: _intValue(json['traversalCursor'], fallback: -1),
      historyIds: _stringList(json['historyIds']),
      historyCursor: _intValue(json['historyCursor'], fallback: -1),
      currentId: _validId(json['currentId']),
    );
  }
}

/// Owns deterministic queue traversal independently from audio playback.
///
/// A shuffle order is generated once per cycle with Fisher-Yates, so automatic
/// navigation never repeats an item before the cycle is exhausted. Playback
/// history is independent from the traversal cursor, which makes Previous and
/// the corresponding forward navigation reflect what the listener actually
/// heard.
class PlaybackQueueNavigator {
  static const int maxHistoryEntries = 500;

  PlaybackQueueNavigator({
    required Iterable<String> queueIds,
    String? currentId,
    bool shuffleEnabled = false,
    Random? random,
  }) : _random = random ?? Random(),
       _shuffleEnabled = shuffleEnabled {
    _initialize(queueIds, currentId: currentId);
  }

  PlaybackQueueNavigator._({required Random random}) : _random = random;

  /// Restores a saved cycle without generating a replacement shuffle order.
  ///
  /// [queueIds] can be supplied when the persisted player queue is authoritative
  /// (for example after a snapshot migration). Invalid and removed IDs are
  /// healed by [syncQueue].
  factory PlaybackQueueNavigator.restore(
    PlaybackQueueNavigatorState state, {
    Iterable<String>? queueIds,
    String? currentId,
    Random? random,
  }) {
    final navigator = PlaybackQueueNavigator._(random: random ?? Random());
    navigator._restore(state);
    if (queueIds != null || currentId != null) {
      navigator.syncQueue(queueIds ?? state.queueIds, currentId: currentId);
    }
    return navigator;
  }

  final Random _random;

  List<String> _queueIds = const [];
  bool _shuffleEnabled = false;
  List<String> _traversalOrderIds = const [];
  int _traversalCursor = -1;
  List<String> _historyIds = const [];
  int _historyCursor = -1;
  String? _currentId;
  List<String> _preparedRepeatOrderIds = const [];

  List<String> get queueIds => List.unmodifiable(_queueIds);

  bool get shuffleEnabled => _shuffleEnabled;

  /// The complete order of the active normal or shuffle cycle.
  List<String> get traversalOrderIds => List.unmodifiable(_traversalOrderIds);

  /// The furthest consumed position in [traversalOrderIds].
  ///
  /// It intentionally does not move backwards with [movePrevious].
  int get traversalCursor => _traversalCursor;

  List<String> get historyIds => List.unmodifiable(_historyIds);

  int get historyCursor => _historyCursor;

  String? get currentId => _currentId;

  bool get canGoPrevious => _historyCursor > 0;

  bool canGoNext({bool repeatAll = false}) {
    if (_currentId == null || _queueIds.isEmpty) return false;
    return _historyCursor + 1 < _historyIds.length ||
        _traversalCursor + 1 < _traversalOrderIds.length ||
        repeatAll;
  }

  /// IDs that Next will visit, starting with any forward playback history.
  List<String> get upcomingIds => upcomingIdsFor();

  /// Returns the real future traversal for the current repeat policy.
  ///
  /// At a Repeat All boundary the next cycle is prepared once and reused by
  /// [moveNext], so UI previews cannot disagree with the song that will play.
  List<String> upcomingIdsFor({bool repeatAll = false}) {
    final upcoming = <String>[
      if (_historyCursor + 1 < _historyIds.length)
        ..._historyIds.skip(_historyCursor + 1),
      if (_traversalCursor + 1 < _traversalOrderIds.length)
        ..._traversalOrderIds.skip(_traversalCursor + 1),
    ];
    if (upcoming.isNotEmpty || !repeatAll || _queueIds.isEmpty) {
      return List.unmodifiable(upcoming);
    }
    _prepareRepeatOrder();
    return List.unmodifiable(_preparedRepeatOrderIds);
  }

  PlaybackQueueNavigatorState get state => PlaybackQueueNavigatorState(
    queueIds: _queueIds,
    shuffleEnabled: _shuffleEnabled,
    traversalOrderIds: _traversalOrderIds,
    traversalCursor: _traversalCursor,
    historyIds: _historyIds,
    historyCursor: _historyCursor,
    currentId: _currentId,
  );

  /// Moves through forward history first, then advances the active cycle.
  ///
  /// Returns `null` when repeat is off and the cycle is exhausted. With
  /// [repeatAll], a new shuffle cycle is generated and its first item is kept
  /// different from the previous cycle boundary when possible.
  String? moveNext({bool repeatAll = false}) {
    if (_currentId == null || _queueIds.isEmpty) return null;

    if (_historyCursor + 1 < _historyIds.length) {
      _historyCursor++;
      _currentId = _historyIds[_historyCursor];
      return _currentId;
    }

    if (_traversalCursor + 1 < _traversalOrderIds.length) {
      _traversalCursor++;
      return _recordCurrent(_traversalOrderIds[_traversalCursor]);
    }

    if (!repeatAll) return null;
    final boundaryId = _currentId;
    _prepareRepeatOrder();
    _traversalOrderIds = _preparedRepeatOrderIds;
    _preparedRepeatOrderIds = const [];
    if (_traversalOrderIds.isEmpty) return null;
    _traversalCursor = 0;
    assert(_traversalOrderIds.first != boundaryId || _queueIds.length == 1);
    return _recordCurrent(_traversalOrderIds.first);
  }

  /// Moves to the song that was actually visited before the current one.
  String? movePrevious({bool repeatAll = false}) {
    if (_historyCursor > 0 && _historyIds.isNotEmpty) {
      _historyCursor--;
      _currentId = _historyIds[_historyCursor];
      return _currentId;
    }
    if (!repeatAll || _currentId == null || _traversalOrderIds.length < 2) {
      return null;
    }
    final currentIndex = _traversalOrderIds.indexOf(_currentId!);
    if (currentIndex < 0) return null;
    final previousIndex = currentIndex == 0
        ? _traversalOrderIds.length - 1
        : currentIndex - 1;
    final previousId = _traversalOrderIds[previousIndex];
    return selectCurrent(previousId) ? previousId : null;
  }

  /// Explicitly selects an ID without treating skipped shuffle items as played.
  ///
  /// Selecting an unplayed shuffle item consumes only that item. Selecting an
  /// already-consumed item is an intentional replay and leaves the cycle
  /// frontier intact.
  bool selectCurrent(String id) {
    if (!_queueIds.contains(id)) return false;

    if (_currentId == id) return true;

    _invalidatePreparedRepeatOrder();
    _truncateForwardHistory();
    if (_shuffleEnabled) {
      final targetIndex = _traversalOrderIds.indexOf(id);
      if (targetIndex > _traversalCursor) {
        final mutableOrder = [..._traversalOrderIds]..removeAt(targetIndex);
        final insertionIndex = (_traversalCursor + 1).clamp(
          0,
          mutableOrder.length,
        );
        mutableOrder.insert(insertionIndex, id);
        _traversalOrderIds = List.unmodifiable(mutableOrder);
        _traversalCursor = insertionIndex;
      }
    } else {
      _traversalOrderIds = List.unmodifiable(_queueIds);
      _traversalCursor = _queueIds.indexOf(id);
    }

    _recordCurrent(id);
    return true;
  }

  /// Enables or disables shuffle while preserving playback history.
  ///
  /// Forward history is discarded because changing the mode creates a new
  /// future traversal from the current item.
  void setShuffleEnabled(bool enabled) {
    if (_shuffleEnabled == enabled) return;
    _shuffleEnabled = enabled;
    _invalidatePreparedRepeatOrder();
    _truncateForwardHistory();
    _resetTraversalFromCurrent();
  }

  /// Reconciles add/remove/reorder mutations with the active traversal.
  ///
  /// Existing traversal and history are retained for IDs that remain valid.
  /// New IDs join the tail of the unconsumed shuffle order. If the current item
  /// was removed, the requested or first remaining queue item becomes current.
  void syncQueue(Iterable<String> queueIds, {String? currentId}) {
    final nextQueue = _uniqueIds(queueIds);
    if (nextQueue.isEmpty) {
      _clear();
      return;
    }

    final previousCurrent = _currentId;
    final requestedCurrent = nextQueue.contains(currentId)
        ? currentId
        : nextQueue.contains(previousCurrent)
        ? previousCurrent
        : nextQueue.first;
    final currentWasRemoved =
        previousCurrent != null && !nextQueue.contains(previousCurrent);

    _queueIds = List.unmodifiable(nextQueue);
    _invalidatePreparedRepeatOrder();
    _filterHistoryForQueue();

    if (_historyIds.isEmpty) {
      _historyIds = List.unmodifiable([requestedCurrent!]);
      _historyCursor = 0;
      _currentId = requestedCurrent;
      _resetTraversalFromCurrent();
      return;
    }

    if (_historyCursor < 0) {
      final requestedHistoryIndex = _historyIds.indexOf(requestedCurrent!);
      if (requestedHistoryIndex >= 0) {
        _historyCursor = requestedHistoryIndex;
      } else {
        _historyIds = List.unmodifiable([requestedCurrent, ..._historyIds]);
        _historyCursor = 0;
      }
    }
    _currentId = _historyIds[_historyCursor];
    if (_shuffleEnabled) {
      _reconcileShuffleOrder();
    } else {
      _reconcileOrderedTraversal();
    }

    if (currentWasRemoved || _currentId != requestedCurrent) {
      selectCurrent(requestedCurrent!);
    }
  }

  /// Inserts or moves [id] directly after the current item, without duplicates.
  ///
  /// The same ID is also made the next traversal result. Forward history is
  /// discarded because this operation intentionally branches the queue.
  bool addNext(String id) {
    if (!_isValidId(id)) return false;
    if (_queueIds.isEmpty || _currentId == null) {
      _initialize([id], currentId: id);
      return true;
    }
    if (id == _currentId) return false;

    _invalidatePreparedRepeatOrder();
    final mutableQueue = [..._queueIds]..remove(id);
    final currentQueueIndex = mutableQueue.indexOf(_currentId!);
    mutableQueue.insert(currentQueueIndex + 1, id);
    _queueIds = List.unmodifiable(mutableQueue);
    _truncateForwardHistory();

    if (_shuffleEnabled) {
      final mutableOrder = [..._traversalOrderIds];
      final oldIndex = mutableOrder.indexOf(id);
      if (oldIndex >= 0) {
        mutableOrder.removeAt(oldIndex);
        if (oldIndex <= _traversalCursor) _traversalCursor--;
      }
      final insertionIndex = (_traversalCursor + 1).clamp(
        0,
        mutableOrder.length,
      );
      mutableOrder.insert(insertionIndex, id);
      _traversalOrderIds = List.unmodifiable(mutableOrder);
    } else {
      _traversalOrderIds = List.unmodifiable(_queueIds);
      _traversalCursor = _queueIds.indexOf(_currentId!);
    }

    return true;
  }

  /// Distributes newly suggested IDs through the remaining traversal.
  ///
  /// Existing consumed items stay fixed. Forward history is intentionally
  /// branched because enabling Smart Shuffle creates a new future queue.
  void distributeUpcoming(Iterable<String> suggestedIds) {
    if (_currentId == null || _queueIds.isEmpty) return;
    final suggestions = _uniqueIds(
      suggestedIds.where((id) => id != _currentId && _queueIds.contains(id)),
    );
    if (suggestions.isEmpty) return;

    _invalidatePreparedRepeatOrder();
    _truncateForwardHistory();
    final suggestionSet = suggestions.toSet();
    final consumed = _traversalOrderIds
        .take(_traversalCursor + 1)
        .where((id) => !suggestionSet.contains(id))
        .toList(growable: true);
    if (!consumed.contains(_currentId)) consumed.add(_currentId!);
    final remaining = _traversalOrderIds
        .skip(_traversalCursor + 1)
        .where((id) => !suggestionSet.contains(id))
        .toList(growable: false);
    final distributed = <String>[];
    final length = max(remaining.length, suggestions.length);
    for (var index = 0; index < length; index++) {
      if (index < remaining.length) distributed.add(remaining[index]);
      if (index < suggestions.length) distributed.add(suggestions[index]);
    }
    _traversalOrderIds = List.unmodifiable([...consumed, ...distributed]);
    _traversalCursor = consumed.length - 1;
  }

  void _initialize(Iterable<String> queueIds, {String? currentId}) {
    final normalized = _uniqueIds(queueIds);
    if (normalized.isEmpty) {
      _clear();
      return;
    }
    _queueIds = List.unmodifiable(normalized);
    _currentId = normalized.contains(currentId) ? currentId : normalized.first;
    _historyIds = List.unmodifiable([_currentId!]);
    _historyCursor = 0;
    _resetTraversalFromCurrent();
  }

  void _restore(PlaybackQueueNavigatorState state) {
    _shuffleEnabled = state.shuffleEnabled;
    _queueIds = List.unmodifiable(_uniqueIds(state.queueIds));
    if (_queueIds.isEmpty) {
      _clear();
      return;
    }

    final validIds = _queueIds.toSet();
    final restoredHistory = state.historyIds
        .where(validIds.contains)
        .toList(growable: false);
    final restoredCurrent = validIds.contains(state.currentId)
        ? state.currentId
        : restoredHistory.isNotEmpty
        ? restoredHistory[state.historyCursor.clamp(
            0,
            restoredHistory.length - 1,
          )]
        : _queueIds.first;

    _historyIds = List.unmodifiable(restoredHistory);
    _historyCursor = _historyIds.isEmpty
        ? -1
        : state.historyCursor.clamp(0, _historyIds.length - 1);
    _capHistoryAroundCursor();
    _currentId = _historyCursor >= 0
        ? _historyIds[_historyCursor]
        : restoredCurrent;
    if (_currentId != restoredCurrent || _historyIds.isEmpty) {
      _truncateForwardHistory();
      _recordCurrent(restoredCurrent!);
    }

    if (!_shuffleEnabled) {
      final restoredOrder = _uniqueIds(
        state.traversalOrderIds.where(validIds.contains),
      );
      final frontierId =
          state.traversalCursor >= 0 &&
              state.traversalCursor < restoredOrder.length
          ? restoredOrder[state.traversalCursor]
          : null;
      _traversalOrderIds = List.unmodifiable(_queueIds);
      final restoredCursor = frontierId == null
          ? -1
          : _queueIds.indexOf(frontierId);
      _traversalCursor = restoredCursor >= 0
          ? restoredCursor
          : _queueIds.indexOf(_currentId!);
      return;
    }

    final restoredOrder = _uniqueIds(
      state.traversalOrderIds.where(validIds.contains),
    );
    restoredOrder.addAll(_queueIds.where((id) => !restoredOrder.contains(id)));
    _traversalOrderIds = List.unmodifiable(restoredOrder);
    _traversalCursor = state.traversalCursor.clamp(
      -1,
      _traversalOrderIds.length - 1,
    );

    final currentOrderIndex = _traversalOrderIds.indexOf(_currentId!);
    if (_historyCursor == _historyIds.length - 1 &&
        currentOrderIndex > _traversalCursor) {
      _traversalCursor = currentOrderIndex;
    }
  }

  void _reconcileShuffleOrder() {
    final validIds = _queueIds.toSet();
    final consumed = _traversalOrderIds
        .take(_traversalCursor + 1)
        .where(validIds.contains)
        .toList(growable: true);
    final remaining = _traversalOrderIds
        .skip(_traversalCursor + 1)
        .where(validIds.contains)
        .toList(growable: true);
    final knownIds = {...consumed, ...remaining};
    final additions = _queueIds
        .where((id) => !knownIds.contains(id))
        .toList(growable: true);
    _shuffle(additions);
    _traversalOrderIds = List.unmodifiable([
      ...consumed,
      ...remaining,
      ...additions,
    ]);
    _traversalCursor = consumed.length - 1;
  }

  void _reconcileOrderedTraversal() {
    String? frontierId;
    final lastConsumedIndex = _traversalCursor.clamp(
      -1,
      _traversalOrderIds.length - 1,
    );
    for (var index = lastConsumedIndex; index >= 0; index--) {
      final candidate = _traversalOrderIds[index];
      if (_queueIds.contains(candidate)) {
        frontierId = candidate;
        break;
      }
    }

    _traversalOrderIds = List.unmodifiable(_queueIds);
    final restoredCursor = frontierId == null
        ? -1
        : _queueIds.indexOf(frontierId);
    _traversalCursor = restoredCursor >= 0
        ? restoredCursor
        : _queueIds.indexOf(_currentId!);
  }

  void _filterHistoryForQueue() {
    final validIds = _queueIds.toSet();
    final filtered = <String>[];
    var filteredCursor = -1;
    for (var index = 0; index < _historyIds.length; index++) {
      final id = _historyIds[index];
      if (!validIds.contains(id)) continue;
      filtered.add(id);
      if (index <= _historyCursor) filteredCursor = filtered.length - 1;
    }
    _historyIds = List.unmodifiable(filtered);
    _historyCursor = filteredCursor;
  }

  void _resetTraversalFromCurrent() {
    if (_queueIds.isEmpty || _currentId == null) {
      _traversalOrderIds = const [];
      _traversalCursor = -1;
      return;
    }
    if (!_shuffleEnabled) {
      _traversalOrderIds = List.unmodifiable(_queueIds);
      _traversalCursor = _queueIds.indexOf(_currentId!);
      return;
    }

    final remaining = _queueIds
        .where((id) => id != _currentId)
        .toList(growable: true);
    _shuffle(remaining);
    _traversalOrderIds = List.unmodifiable([_currentId!, ...remaining]);
    _traversalCursor = 0;
  }

  List<String> _freshCycle({String? avoidFirstId}) {
    final order = [..._queueIds];
    if (_shuffleEnabled) _shuffle(order);
    if (order.length > 1 && order.first == avoidFirstId) {
      final replacement = order.indexWhere((id) => id != avoidFirstId);
      final first = order.first;
      order[0] = order[replacement];
      order[replacement] = first;
    }
    return List.unmodifiable(order);
  }

  void _prepareRepeatOrder() {
    if (_preparedRepeatOrderIds.isNotEmpty) return;
    _preparedRepeatOrderIds = _freshCycle(avoidFirstId: _currentId);
  }

  void _invalidatePreparedRepeatOrder() {
    _preparedRepeatOrderIds = const [];
  }

  String _recordCurrent(String id) {
    _truncateForwardHistory();
    _historyIds = List.unmodifiable([..._historyIds, id]);
    _historyCursor = _historyIds.length - 1;
    _capHistoryAroundCursor();
    _currentId = id;
    return id;
  }

  void _capHistoryAroundCursor() {
    if (_historyIds.length <= maxHistoryEntries) return;
    final start = (_historyCursor - maxHistoryEntries + 1).clamp(
      0,
      _historyIds.length - maxHistoryEntries,
    );
    _historyIds = List.unmodifiable(
      _historyIds.sublist(start, start + maxHistoryEntries),
    );
    _historyCursor -= start;
  }

  void _truncateForwardHistory() {
    if (_historyCursor + 1 >= _historyIds.length) return;
    _historyIds = List.unmodifiable(
      _historyIds.take(_historyCursor + 1).toList(growable: false),
    );
  }

  void _shuffle(List<String> ids) {
    for (var index = ids.length - 1; index > 0; index--) {
      final swapIndex = _random.nextInt(index + 1);
      final value = ids[index];
      ids[index] = ids[swapIndex];
      ids[swapIndex] = value;
    }
  }

  void _clear() {
    _queueIds = const [];
    _traversalOrderIds = const [];
    _traversalCursor = -1;
    _historyIds = const [];
    _historyCursor = -1;
    _currentId = null;
    _preparedRepeatOrderIds = const [];
  }
}

List<String> _uniqueIds(Iterable<String> ids) {
  final unique = <String>[];
  final seen = <String>{};
  for (final id in ids) {
    if (_isValidId(id) && seen.add(id)) unique.add(id);
  }
  return unique;
}

List<String> _historyIds(Iterable<String> ids) =>
    ids.where(_isValidId).toList(growable: false);

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().where(_isValidId).toList(growable: false)
    : const [];

String? _validId(Object? value) =>
    value is String && _isValidId(value) ? value : null;

bool _isValidId(String id) => id.trim().isNotEmpty;

int _intValue(Object? value, {required int fallback}) =>
    value is num ? value.toInt() : fallback;
