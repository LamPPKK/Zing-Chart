import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/services/playback_queue_navigator.dart';

void main() {
  group('PlaybackQueueNavigator', () {
    test('keeps a stable, unique queue order', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'a', '', 'c'],
        currentId: 'b',
      );

      expect(navigator.queueIds, ['a', 'b', 'c']);
      expect(navigator.traversalOrderIds, ['a', 'b', 'c']);
      expect(navigator.currentId, 'b');
      expect(navigator.upcomingIds, ['c']);
    });

    test('uses one Fisher-Yates order without repeats per shuffle cycle', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd', 'e'],
        currentId: 'a',
        shuffleEnabled: true,
        random: Random(7),
      );
      final visited = <String>[navigator.currentId!];

      while (navigator.canGoNext()) {
        visited.add(navigator.moveNext()!);
      }

      expect(visited, navigator.traversalOrderIds);
      expect(visited.toSet(), {'a', 'b', 'c', 'd', 'e'});
      expect(visited, hasLength(5));
      expect(navigator.moveNext(), isNull);
      expect(navigator.currentId, visited.last);
    });

    test('accepts deterministic Random injection', () {
      PlaybackQueueNavigator build() => PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd', 'e'],
        currentId: 'c',
        shuffleEnabled: true,
        random: Random(99),
      );

      final first = build();
      final second = build();

      expect(first.traversalOrderIds, second.traversalOrderIds);
      expect(first.upcomingIds, second.upcomingIds);
    });

    test('Previous and forward follow actual playback history', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
      );

      expect(navigator.moveNext(), 'b');
      expect(navigator.moveNext(), 'c');
      expect(navigator.movePrevious(), 'b');
      expect(navigator.movePrevious(), 'a');
      expect(navigator.movePrevious(), isNull);

      expect(navigator.selectCurrent('a'), isTrue);
      expect(navigator.moveNext(), 'b');
      expect(navigator.moveNext(), 'c');
      expect(navigator.moveNext(), 'd');
      expect(navigator.historyIds, ['a', 'b', 'c', 'd']);
    });

    test('repeat all starts a fresh shuffle away from the boundary', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
        shuffleEnabled: true,
        random: Random(12),
      );
      while (navigator.canGoNext()) {
        navigator.moveNext();
      }
      final previousBoundary = navigator.currentId;

      final firstOfNextCycle = navigator.moveNext(repeatAll: true);

      expect(firstOfNextCycle, isNot(previousBoundary));
      expect(navigator.traversalOrderIds.toSet(), {'a', 'b', 'c', 'd'});
      expect(navigator.traversalOrderIds, hasLength(4));
      expect(navigator.traversalCursor, 0);

      final nextCycle = <String>[firstOfNextCycle!];
      while (navigator.canGoNext()) {
        nextCycle.add(navigator.moveNext()!);
      }
      expect(nextCycle.toSet(), {'a', 'b', 'c', 'd'});
      expect(nextCycle, hasLength(4));
    });

    test('Repeat All previews the exact next cycle boundary item', () {
      for (final shuffled in [false, true]) {
        final navigator = PlaybackQueueNavigator(
          queueIds: const ['a', 'b', 'c', 'd'],
          currentId: 'a',
          shuffleEnabled: shuffled,
          random: Random(12),
        );
        while (navigator.canGoNext()) {
          navigator.moveNext();
        }

        final preview = navigator.upcomingIdsFor(repeatAll: true);
        expect(preview, hasLength(4));
        expect(preview.first, isNot(navigator.currentId));
        expect(navigator.moveNext(repeatAll: true), preview.first);
      }
    });

    test('prepared shuffle Repeat All order survives state restore', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd', 'e'],
        currentId: 'a',
        shuffleEnabled: true,
        random: Random(17),
      );
      while (navigator.canGoNext()) {
        navigator.moveNext();
      }
      final prepared = navigator.upcomingIdsFor(repeatAll: true);
      final decoded = PlaybackQueueNavigatorState.fromJson(
        navigator.state.toJson(),
      );

      final restored = PlaybackQueueNavigator.restore(
        decoded,
        queueIds: navigator.queueIds,
        currentId: navigator.currentId,
        random: Random(999),
      );

      expect(restored.upcomingIdsFor(repeatAll: true), prepared);
      expect(restored.moveNext(repeatAll: true), prepared.first);
    });

    test('Repeat All Previous uses the traversal predecessor and wraps', () {
      final middle = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c'],
        currentId: 'b',
      );
      expect(middle.movePrevious(repeatAll: true), 'a');

      final first = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c'],
        currentId: 'a',
      );
      expect(first.movePrevious(repeatAll: true), 'c');
    });

    test('explicit selection consumes only the selected shuffle item', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
        shuffleEnabled: true,
        random: Random(3),
      );
      final selected = navigator.traversalOrderIds.last;
      final skipped = navigator.traversalOrderIds
          .skip(1)
          .where((id) => id != selected)
          .toSet();

      expect(navigator.selectCurrent(selected), isTrue);

      expect(navigator.currentId, selected);
      expect(navigator.historyIds, ['a', selected]);
      expect(navigator.upcomingIds.toSet(), skipped);
      expect(navigator.selectCurrent('missing'), isFalse);
    });

    test('sync preserves valid shuffle traversal and adds new IDs', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
        shuffleEnabled: true,
        random: Random(21),
      );
      navigator.moveNext();
      final current = navigator.currentId!;
      final removed = navigator.traversalOrderIds.firstWhere(
        (id) => id != current && id != 'a',
      );

      navigator.syncQueue(
        ['a', 'b', 'c', 'd', 'e'].where((id) => id != removed),
      );

      expect(navigator.currentId, current);
      expect(navigator.queueIds, isNot(contains(removed)));
      expect(navigator.traversalOrderIds, isNot(contains(removed)));
      expect(navigator.traversalOrderIds, contains('e'));

      final rest = <String>[];
      while (navigator.canGoNext()) {
        rest.add(navigator.moveNext()!);
      }
      expect(rest, contains('e'));
      expect(rest.toSet(), hasLength(rest.length));
    });

    test('sync heals a removed current when only forward history remains', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c'],
        currentId: 'a',
      );
      navigator.moveNext();
      navigator.moveNext();
      navigator.movePrevious();
      navigator.movePrevious();

      expect(
        () => navigator.syncQueue(const ['b', 'c'], currentId: 'b'),
        returnsNormally,
      );
      expect(navigator.currentId, 'b');
      expect(navigator.historyCursor, 0);
      expect(navigator.upcomingIds.first, 'c');
    });

    test('addNext inserts or moves an ID without duplication', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
      );

      expect(navigator.addNext('d'), isTrue);
      expect(navigator.queueIds, ['a', 'd', 'b', 'c']);
      expect(navigator.moveNext(), 'd');
      expect(navigator.queueIds.where((id) => id == 'd'), hasLength(1));

      expect(navigator.addNext('new'), isTrue);
      expect(navigator.queueIds, ['a', 'd', 'new', 'b', 'c']);
      expect(navigator.moveNext(), 'new');
      expect(navigator.queueIds.where((id) => id == 'new'), hasLength(1));
    });

    test('addNext overrides forward history in shuffle mode', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
        shuffleEnabled: true,
        random: Random(4),
      );
      navigator.moveNext();
      navigator.moveNext();
      navigator.movePrevious();
      final requested = navigator.queueIds.firstWhere(
        (id) => id != navigator.currentId,
      );

      expect(navigator.addNext(requested), isTrue);

      expect(navigator.upcomingIds.first, requested);
      expect(navigator.moveNext(), requested);
      expect(navigator.queueIds.toSet(), hasLength(navigator.queueIds.length));
    });

    test('reorders the actual ordered future with final-index semantics', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
      );

      expect(navigator.reorderUpcomingItem(2, 0), isTrue);
      expect(navigator.upcomingIds, ['d', 'b', 'c']);
      expect(navigator.plannedUpcomingIds, ['d', 'b', 'c']);
      expect(navigator.moveNext(), 'd');
      expect(navigator.moveNext(), 'b');
      expect(navigator.moveNext(), 'c');
      expect(navigator.moveNext(), isNull);
    });

    test('reorders a stable shuffle future without changing membership', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd', 'e'],
        currentId: 'a',
        shuffleEnabled: true,
        random: Random(31),
      );
      final before = navigator.upcomingIds;
      final moved = before.last;

      expect(navigator.reorderUpcomingItem(before.length - 1, 0), isTrue);

      expect(navigator.upcomingIds.first, moved);
      expect(navigator.upcomingIds.toSet(), before.toSet());
      expect(navigator.upcomingIds, hasLength(before.length));
      expect(navigator.moveNext(), moved);
    });

    test('direct selection consumes an item from a reconciled future', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
      );
      expect(navigator.reorderUpcomingItem(2, 0), isTrue);
      expect(navigator.upcomingIds, ['d', 'b', 'c']);

      navigator.syncQueue(const ['a', 'b', 'c', 'd'], currentId: 'd');

      expect(navigator.currentId, 'd');
      expect(navigator.upcomingIds, ['b', 'c']);
      expect(navigator.moveNext(), 'b');
    });

    test('editing forward history branches future but preserves Previous', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
      );
      expect(navigator.moveNext(), 'b');
      expect(navigator.moveNext(), 'c');
      expect(navigator.movePrevious(), 'b');
      expect(navigator.upcomingIds, ['c', 'd']);

      expect(navigator.reorderUpcomingItem(1, 0), isTrue);
      expect(navigator.upcomingIds, ['d', 'c']);
      expect(navigator.historyIds, ['a', 'b']);
      expect(navigator.historyCursor, 1);

      expect(navigator.moveNext(), 'd');
      expect(navigator.movePrevious(), 'b');
      expect(navigator.upcomingIds, ['d', 'c']);
      expect(navigator.moveNext(), 'd');
      expect(navigator.moveNext(), 'c');
    });

    test('reorders and persists the prepared Repeat All boundary cycle', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
        shuffleEnabled: true,
        random: Random(14),
      );
      while (navigator.canGoNext()) {
        navigator.moveNext();
      }
      final prepared = navigator.upcomingIdsFor(repeatAll: true);
      final moved = prepared.last;

      expect(
        navigator.reorderUpcomingItem(prepared.length - 1, 0, repeatAll: true),
        isTrue,
      );
      expect(navigator.upcomingIdsFor(repeatAll: true).first, moved);

      final restored = PlaybackQueueNavigator.restore(
        PlaybackQueueNavigatorState.fromJson(navigator.state.toJson()),
        random: Random(99),
      );
      expect(
        restored.upcomingIdsFor(repeatAll: true),
        navigator.upcomingIdsFor(repeatAll: true),
      );
      expect(restored.moveNext(repeatAll: true), moved);
    });

    test('disabling Repeat All drops an unconsumed boundary-only plan', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c'],
        currentId: 'c',
      );
      expect(navigator.reorderUpcomingItem(0, 2, repeatAll: true), isTrue);
      expect(navigator.upcomingIds, ['b', 'c', 'a']);
      expect(navigator.plannedUpcomingRepeatAllFlags, [true, true, true]);

      navigator.setRepeatAllEnabled(false);

      expect(navigator.upcomingIds, isEmpty);
      expect(navigator.canGoNext(), isFalse);
    });

    test(
      'disabling Repeat All keeps the cycle after its boundary is crossed',
      () {
        final navigator = PlaybackQueueNavigator(
          queueIds: const ['a', 'b', 'c'],
          currentId: 'c',
        );
        expect(navigator.reorderUpcomingItem(0, 2, repeatAll: true), isTrue);
        expect(navigator.moveNext(repeatAll: true), 'b');
        expect(navigator.plannedUpcomingRepeatAllFlags, [false, false]);

        navigator.setRepeatAllEnabled(false);

        expect(navigator.upcomingIds, ['c', 'a']);
        expect(navigator.moveNext(), 'c');
        expect(navigator.moveNext(), 'a');
        expect(navigator.moveNext(), isNull);
      },
    );

    test('direct selection crosses a prepared Repeat All boundary', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c'],
        currentId: 'c',
      );
      expect(navigator.reorderUpcomingItem(0, 2, repeatAll: true), isTrue);

      expect(navigator.selectCurrent('c'), isTrue);
      expect(navigator.plannedUpcomingRepeatAllFlags, [true, true, true]);
      expect(navigator.selectCurrent('b'), isTrue);
      expect(navigator.plannedUpcomingRepeatAllFlags, [false, false]);
      navigator.setRepeatAllEnabled(false);

      expect(navigator.upcomingIds, ['c', 'a']);
    });

    test('disabling Repeat All retains ordinary explicit future edits', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
      );
      expect(navigator.reorderUpcomingItem(2, 0), isTrue);
      expect(navigator.plannedUpcomingRepeatAllFlags, [false, false, false]);

      navigator.setRepeatAllEnabled(false);

      expect(navigator.upcomingIds, ['d', 'b', 'c']);
    });

    test('disabling Repeat All keeps explicit entries mixed into its plan', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c'],
        currentId: 'c',
      );
      expect(navigator.reorderUpcomingItem(0, 2, repeatAll: true), isTrue);
      expect(navigator.addNext('explicit'), isTrue);
      expect(navigator.upcomingIds, ['explicit', 'b', 'c', 'a']);
      expect(navigator.plannedUpcomingRepeatAllFlags, [
        false,
        true,
        true,
        true,
      ]);

      navigator.setRepeatAllEnabled(false);

      expect(navigator.upcomingIds, ['explicit']);
      expect(navigator.moveNext(), 'explicit');
      expect(navigator.moveNext(), isNull);
    });

    test(
      'Repeat All Previous preserves the played traversal after editing the next cycle',
      () {
        final navigator = PlaybackQueueNavigator(
          queueIds: const ['a', 'b', 'c'],
          currentId: 'c',
        );

        expect(navigator.upcomingIdsFor(repeatAll: true), ['a', 'b', 'c']);
        expect(navigator.reorderUpcomingItem(0, 2, repeatAll: true), isTrue);
        expect(navigator.plannedUpcomingIds, ['b', 'c', 'a']);

        expect(navigator.movePrevious(repeatAll: true), 'b');
        expect(navigator.plannedUpcomingIds, ['b', 'c', 'a']);
        expect(navigator.upcomingIds, ['c', 'b', 'c', 'a']);

        expect(navigator.moveNext(repeatAll: true), 'c');
        expect(navigator.plannedUpcomingIds, ['b', 'c', 'a']);
        expect(navigator.moveNext(repeatAll: true), 'b');
      },
    );

    test('disabling Repeat All preserves real forward history', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c'],
        currentId: 'c',
      );
      expect(navigator.reorderUpcomingItem(0, 2, repeatAll: true), isTrue);
      expect(navigator.upcomingIds, ['b', 'c', 'a']);
      expect(navigator.movePrevious(repeatAll: true), 'b');
      expect(navigator.upcomingIds, ['c', 'b', 'c', 'a']);
      expect(navigator.upcomingRepeatAllFlags, [false, true, true, true]);

      navigator.setRepeatAllEnabled(false);

      expect(navigator.upcomingIds, ['c']);
      expect(navigator.moveNext(), 'c');
      expect(navigator.moveNext(), isNull);
    });

    test('preserves duplicate future visits across Repeat All cycles', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c'],
        currentId: 'a',
      );
      expect(navigator.moveNext(), 'b');
      expect(navigator.moveNext(), 'c');
      expect(navigator.moveNext(repeatAll: true), 'a');
      expect(navigator.moveNext(repeatAll: true), 'b');
      expect(navigator.movePrevious(), 'a');
      expect(navigator.movePrevious(), 'c');
      expect(navigator.movePrevious(), 'b');
      expect(navigator.upcomingIds, ['c', 'a', 'b', 'c']);

      expect(navigator.reorderUpcomingItem(3, 0), isTrue);
      expect(navigator.upcomingIds, ['c', 'c', 'a', 'b']);

      final restored = PlaybackQueueNavigator.restore(
        PlaybackQueueNavigatorState.fromJson(navigator.state.toJson()),
      );
      expect(restored.upcomingIds, ['c', 'c', 'a', 'b']);
      expect(List.generate(4, (_) => restored.moveNext()), [
        'c',
        'c',
        'a',
        'b',
      ]);
      expect(restored.moveNext(), isNull);
    });

    test('selects the exact upcoming occurrence when IDs repeat', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c'],
        currentId: 'a',
      );
      expect(navigator.moveNext(), 'b');
      expect(navigator.moveNext(), 'c');
      expect(navigator.moveNext(repeatAll: true), 'a');
      expect(navigator.moveNext(repeatAll: true), 'b');
      expect(navigator.movePrevious(), 'a');
      expect(navigator.movePrevious(), 'c');
      expect(navigator.movePrevious(), 'b');
      expect(navigator.upcomingIds, ['c', 'a', 'b', 'c']);
      expect(navigator.reorderUpcomingItem(3, 1), isTrue);
      expect(navigator.upcomingIds, ['c', 'c', 'a', 'b']);
      expect(navigator.reorderUpcomingItem(1, 2), isTrue);
      expect(navigator.upcomingIds, ['c', 'a', 'c', 'b']);

      expect(navigator.selectUpcomingItem(2), 'c');

      expect(navigator.currentId, 'c');
      expect(navigator.upcomingIds, ['c', 'a', 'b']);
    });

    test(
      'planned future reconciles remove, append, Add Next and Smart IDs',
      () {
        final navigator = PlaybackQueueNavigator(
          queueIds: const ['a', 'b', 'c', 'd'],
          currentId: 'a',
        );
        expect(navigator.reorderUpcomingItem(2, 0), isTrue);
        expect(navigator.upcomingIds, ['d', 'b', 'c']);

        navigator.syncQueue(const ['a', 'b', 'c', 'e']);
        expect(navigator.upcomingIds, ['b', 'c', 'e']);

        expect(navigator.addNext('e'), isTrue);
        expect(navigator.upcomingIds, ['e', 'b', 'c']);

        navigator.syncQueue(const ['a', 'e', 'b', 'c', 'smart']);
        navigator.distributeUpcoming(const ['smart']);
        expect(navigator.upcomingIds, ['e', 'smart', 'b', 'c']);
        expect(navigator.queueIds.toSet(), {'a', 'b', 'c', 'e', 'smart'});
      },
    );

    test('explicit future replacement preserves the played Previous path', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd', 'e'],
        currentId: 'a',
      );
      expect(navigator.moveNext(), 'b');
      expect(navigator.moveNext(), 'c');

      navigator.replaceUpcoming(const ['e', 'd']);

      expect(navigator.upcomingIds, ['e', 'd']);
      expect(navigator.movePrevious(), 'b');
      expect(navigator.upcomingIds, ['c', 'e', 'd']);
      expect(navigator.moveNext(), 'c');
      expect(navigator.moveNext(), 'e');
      expect(navigator.moveNext(), 'd');
    });

    test('rejects invalid or no-op upcoming reorder indexes', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c'],
        currentId: 'a',
      );
      final before = navigator.state.toJson();

      expect(navigator.reorderUpcomingItem(-1, 0), isFalse);
      expect(navigator.reorderUpcomingItem(0, 2), isFalse);
      expect(navigator.reorderUpcomingItem(0, 0), isFalse);
      expect(navigator.state.toJson(), before);
    });

    test('distributes Smart Shuffle suggestions through the real future', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd', 's1', 's2'],
        currentId: 'a',
        shuffleEnabled: true,
        random: Random(9),
      );

      navigator.distributeUpcoming(const ['s1', 's2']);

      final upcoming = navigator.upcomingIds;
      expect(upcoming.toSet(), {'b', 'c', 'd', 's1', 's2'});
      expect(upcoming.indexOf('s1'), 1);
      expect(upcoming.last, isNot(anyOf('s1', 's2')));
    });

    test('state JSON restores traversal and history cursors', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
        shuffleEnabled: true,
        random: Random(42),
      );
      navigator.moveNext();
      navigator.moveNext();
      navigator.movePrevious();
      final decoded = PlaybackQueueNavigatorState.fromJson(
        navigator.state.toJson(),
      );

      final restored = PlaybackQueueNavigator.restore(
        decoded,
        random: Random(999),
      );

      expect(restored.queueIds, navigator.queueIds);
      expect(restored.traversalOrderIds, navigator.traversalOrderIds);
      expect(restored.traversalCursor, navigator.traversalCursor);
      expect(restored.historyIds, navigator.historyIds);
      expect(restored.historyCursor, navigator.historyCursor);
      expect(restored.currentId, navigator.currentId);
      expect(restored.plannedUpcomingIds, navigator.plannedUpcomingIds);
      expect(restored.moveNext(), navigator.moveNext());
    });

    test('caps long playback history without losing the current cursor', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b'],
        currentId: 'a',
      );

      for (var index = 0; index < 620; index++) {
        expect(navigator.moveNext(repeatAll: true), isNotNull);
      }

      expect(
        navigator.historyIds,
        hasLength(PlaybackQueueNavigator.maxHistoryEntries),
      );
      expect(navigator.historyCursor, navigator.historyIds.length - 1);
      expect(navigator.historyIds.last, navigator.currentId);
      final previousId = navigator.historyIds[navigator.historyCursor - 1];

      final restored = PlaybackQueueNavigator.restore(
        PlaybackQueueNavigatorState.fromJson(navigator.state.toJson()),
      );

      expect(restored.currentId, navigator.currentId);
      expect(restored.historyCursor, restored.historyIds.length - 1);
      expect(restored.movePrevious(), previousId);
    });

    test('ordered restore keeps its frontier while history is rewound', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
      );
      navigator.moveNext();
      navigator.moveNext();
      navigator.movePrevious();

      final restored = PlaybackQueueNavigator.restore(navigator.state);

      expect(restored.currentId, 'b');
      expect(restored.traversalCursor, 2);
      expect(restored.moveNext(), 'c');
      expect(restored.moveNext(), 'd');
    });

    test('ordered sync does not replay forward history at the frontier', () {
      final navigator = PlaybackQueueNavigator(
        queueIds: const ['a', 'b', 'c', 'd'],
        currentId: 'a',
      );
      navigator.moveNext();
      navigator.moveNext();
      navigator.movePrevious();

      navigator.syncQueue(const ['a', 'b', 'c', 'd', 'e']);

      expect(navigator.moveNext(), 'c');
      expect(navigator.moveNext(), 'd');
      expect(navigator.moveNext(), 'e');
    });

    test('restore heals removed IDs against an authoritative queue', () {
      final state = PlaybackQueueNavigatorState(
        queueIds: const ['a', 'removed', 'b'],
        shuffleEnabled: true,
        traversalOrderIds: const ['a', 'removed', 'b'],
        traversalCursor: 1,
        historyIds: const ['a', 'removed'],
        historyCursor: 1,
        currentId: 'removed',
      );

      final restored = PlaybackQueueNavigator.restore(
        state,
        queueIds: const ['a', 'b', 'new'],
        currentId: 'b',
        random: Random(5),
      );

      expect(restored.queueIds, ['a', 'b', 'new']);
      expect(restored.currentId, 'b');
      expect(restored.traversalOrderIds, isNot(contains('removed')));
      expect(restored.historyIds, isNot(contains('removed')));
    });
  });
}
