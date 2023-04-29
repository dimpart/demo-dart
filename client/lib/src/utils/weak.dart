/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * =============================================================================
 */

///
///  Weak Value Map
///

class WeakValueMap<K, V> implements Map<K, V> {
  WeakValueMap() : _inner = {};

  final Map<K, WeakReference<dynamic>?> _inner;

  Map<K, V> toMap() {
    // remove empty entry
    _inner.removeWhere((key, wr) => wr?.target == null);
    // convert
    return _inner.map((key, wr) => MapEntry(key, wr?.target));
  }

  @override
  String toString() => toMap().toString();

  @override
  Map<RK, RV> cast<RK, RV>() => toMap().cast();

  @override
  bool containsValue(Object? value) => toMap().containsValue(value);

  @override
  bool containsKey(Object? key) => _inner[key]?.target != null;

  @override
  V? operator [](Object? key) => _inner[key]?.target;

  @override
  void operator []=(K key, V value) =>
      _inner[key] = value == null ? null : WeakReference(value);

  @override
  Iterable<MapEntry<K, V>> get entries => toMap().entries;

  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) convert) =>
      toMap().map(convert);

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    for (var entry in newEntries) {
      this[entry.key] = entry.value;
    }
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) =>
      _inner.update(key, (wr) {
        V val = wr?.target;
        if (val != null) {
          val = update(val);
        } else if (ifAbsent != null) {
          val = ifAbsent();
        }
        return val == null ? null : WeakReference(val);
      })?.target;

  @override
  void updateAll(V Function(K key, V value) update) =>
      _inner.updateAll((key, wr) {
        V val = wr?.target;
        if (val == null) {
          return null;
        }
        val = update(key, val);
        return val == null ? null : WeakReference(val);
      });

  @override
  void removeWhere(bool Function(K key, V value) test) =>
      _inner.removeWhere((key, wr) {
        V val = wr?.target;
        return val == null || test(key, val);
      });

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    WeakReference<dynamic>? wr = _inner[key];
    V val = wr?.target;
    if (val == null) {
      val = ifAbsent();
      this[key] = val;
    }
    return val;
  }

  @override
  void addAll(Map<K, V> other) => other.forEach((key, value) {
    this[key] = value;
  });

  @override
  V? remove(Object? key) => _inner.remove(key)?.target;

  @override
  void clear() => _inner.clear();

  @override
  void forEach(void Function(K key, V value) action) => _inner.forEach((key, wr) {
    V val = wr?.target;
    if (val != null) {
      action(key, val);
    }
  });

  @override
  Iterable<K> get keys => toMap().keys;

  @override
  Iterable<V> get values => toMap().values;

  @override
  int get length => toMap().length;

  @override
  bool get isEmpty => toMap().isEmpty;

  @override
  bool get isNotEmpty => toMap().isNotEmpty;

}

///
///  Weak Set
///

class WeakSet<E extends Object> implements Set<E> {
  WeakSet() : _inner = {};

  final Set<WeakReference<dynamic>> _inner;

  @override
  void clear() => _inner.clear();

  @override
  Set<E> toSet() {
    Set<E> set = {};
    E? item;
    Set<WeakReference<dynamic>> ghosts = {};
    for (WeakReference<dynamic> wr in _inner) {
      item = wr.target;
      if (item == null) {
        // target released, remove the reference from inner set later
        ghosts.add(wr);
      } else {
        set.add(item);
      }
    }
    _inner.removeAll(ghosts);
    return set;
  }

  @override
  List<E> toList({bool growable = true}) => toSet().toList(growable: growable);

  @override
  String toString() => toSet().toString();

  @override
  Iterator<E> get iterator => toSet().iterator;

  @override
  int get length => toSet().length;

  @override
  bool get isEmpty => toSet().isEmpty;

  @override
  bool get isNotEmpty => toSet().isNotEmpty;

  @override
  E get first => toSet().first;

  @override
  E get last => toSet().last;

  @override
  E get single => toSet().single;

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) =>
      toSet().firstWhere(test, orElse: orElse);

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) =>
      toSet().lastWhere(test, orElse: orElse);

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) =>
      toSet().singleWhere(test, orElse: orElse);

  @override
  bool any(bool Function(E element) test) => toSet().any(test);

  @override
  bool every(bool Function(E element) test) => toSet().every(test);

  @override
  E? lookup(Object? object) => toSet().lookup(object);

  @override
  bool contains(Object? value) => toSet().contains(value);

  @override
  bool containsAll(Iterable<Object?> other) => toSet().containsAll(other);

  @override
  E elementAt(int index) => toSet().elementAt(index);

  @override
  bool add(E value) => !contains(value) && _inner.add(WeakReference(value));

  @override
  void addAll(Iterable<E> elements) {
    for (var e in elements) {
      add(e);
    }
  }

  @override
  bool remove(Object? value) {
    for (var wr in _inner) {
      if (wr.target == value) {
        return _inner.remove(wr);
      }
    }
    return false;
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    Set<dynamic> removing = {};
    E? item;
    for (var e in elements) {
      for (var wr in _inner) {
        item = wr.target;
        if (item == e || item == null) {
          removing.add(wr);
        }
      }
    }
    return _inner.removeAll(removing);
  }

  @override
  void removeWhere(bool Function(E element) test) =>
      _inner.removeWhere((wr) {
        E? item = wr.target;
        return item == null || test(item);
      });

  @override
  Set<E> difference(Set<Object?> other) => toSet().difference(other);

  @override
  Set<E> intersection(Set<Object?> other) => toSet().intersection(other);

  @override
  void forEach(void Function(E element) action) => toSet().forEach(action);

  @override
  String join([String separator = ""]) => toSet().join(separator);

  @override
  Set<E> union(Set<E> other) => toSet().union(other);

  @override
  Set<R> cast<R>() => toSet().cast();

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) =>
      toSet().expand(toElements);

  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      toSet().fold(initialValue, combine);

  @override
  Iterable<E> followedBy(Iterable<E> other) => toSet().followedBy(other);

  @override
  Iterable<T> map<T>(T Function(E e) toElement) => toSet().map(toElement);

  @override
  E reduce(E Function(E value, E element) combine) => toSet().reduce(combine);

  @override
  void retainAll(Iterable<Object?> elements) => toSet().retainAll(elements);

  @override
  void retainWhere(bool Function(E element) test) => toSet().retainWhere(test);

  @override
  Iterable<E> skip(int count) => toSet().skip(count);

  @override
  Iterable<E> skipWhile(bool Function(E value) test) => toSet().skipWhile(test);

  @override
  Iterable<E> take(int count) => toSet().take(count);

  @override
  Iterable<E> takeWhile(bool Function(E value) test) => toSet().takeWhile(test);

  @override
  Iterable<E> where(bool Function(E element) test) => toSet().where(test);

  @override
  Iterable<T> whereType<T>() => toSet().whereType();
}
