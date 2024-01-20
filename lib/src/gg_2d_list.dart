// @license
// Copyright (c) 2019 - 2023 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:typed_data';

import '../gg_list.dart';

// #############################################################################
class Gg2dList<V> {
  const Gg2dList({
    required this.rowCount,
    required this.colCount,
    required this.data,
    required this.dataT,
    required this.colHashes,
    required this.rowHashes,
    required this.hashCode,
    required this.createBuffer,
    required this.copyBuffer,
    required this.subList,
  });

  // ######################
  // Generate
  // ######################

  // ...........................................................................
  static Gg2dList<T> generate<T>({
    required T Function(int col, int row)? createValue,
    required T fill,
    required int rowCount,
    required int colCount,
  }) {
    return Gg2dList.special(
      rowCount: rowCount,
      colCount: colCount,
      createBuffer: (length) => List<T>.filled(length, growable: false, fill),
      copyBuffer: List<T>.from,
      subList: (p0, [start = 0, end]) => p0.sublist(start, end),
      createValue:
          createValue == null ? null : (col, row) => createValue(col, row),
    );
  }

  // ######################
  // Copy & modify
  // ######################

  // ...........................................................................
  Gg2dList<V> copyWithValue(int col, int row, V value) {
    // If nothing has changed, do nothing
    final oldVal = this.value(col, row);
    if (oldVal == value) {
      return this;
    }

    // Copy data and hashes
    final data = copyBuffer(this.data);
    final dataT = copyBuffer(this.dataT);
    final colHashes = Int64List.fromList(this.colHashes);
    final rowHashes = Int64List.fromList(this.rowHashes);

    // Calculate index
    final index = dataIndex(col, row, colCount);
    final indexT = dataIndexT(col, row, rowCount);

    // Update value
    data[index] = value;
    dataT[indexT] = value;

    // Update hashes
    rowHashes[row] = rowOrColHash(data, row, colCount);
    colHashes[col] = rowOrColHash(dataT, col, rowCount);

    final hashCode = overallHash(rowHashes: rowHashes);

    // Create a new object
    return Gg2dList<V>(
      rowCount: rowCount,
      colCount: colCount,
      data: data,
      dataT: dataT,
      colHashes: colHashes,
      rowHashes: rowHashes,
      hashCode: hashCode,
      createBuffer: createBuffer,
      copyBuffer: copyBuffer,
      subList: subList,
    );
  }

  // ######################
  // Data methods
  // ######################

  // ...........................................................................
  /// Transposes a given matrix, i.e. exchanges rows and cols
  static void transpose<T>({
    required List<T> original,
    required List<T> transposed,
    required int rowCount,
    required int colCount,
  }) {
    int iInversed = 0;
    int row = 0;
    int col = 0;

    for (final val in original) {
      iInversed = col * rowCount + row;
      transposed[iInversed] = val;
      col++;

      if (col >= colCount) {
        row++;
        col = 0;
      }
    }
  }

  // ######################
  // Hash
  // ######################

  // ...........................................................................
  /// Calculates
  static int rowOrColHash<T>(
    List<T> data,
    int rowOrCol,
    int cellsPerLine,
  ) {
    final startIndex = rowOrCol * cellsPerLine;

    return fnv1(data, startIndex, startIndex + cellsPerLine);
  }

// ...........................................................................
  static void updateAllHashes<T>({
    required List<T> data,
    required List<T> dataT,
    required Int64List rowHashes,
    required Int64List colHashes,
    required int rowCount,
    required int colCount,
  }) {
    for (var row = 0; row < rowCount; row++) {
      final hash = rowOrColHash(data, row, colCount);
      rowHashes[row] = hash;
    }

    for (var col = 0; col < colCount; col++) {
      final hash = rowOrColHash(dataT, col, rowCount);
      colHashes[col] = hash;
    }
  }

// ...........................................................................
  static int overallHash({required Int64List rowHashes}) => fnv1(rowHashes);

  // ######################
  // Calc index
  // ######################

  // ...........................................................................
  /// Calculates the row data index of a coordinate
  static int dataIndex(int col, int row, int colCount) => row * colCount + col;

  // ...........................................................................
  /// Calculates the column data index of a coordinate
  static int dataIndexT(int col, int row, int rowCount) => col * rowCount + row;

  // ######################
  // Data access
  // ######################

  // ...........................................................................
  V value(int col, int row) => data[dataIndex(col, row, colCount)];

  // ...........................................................................
  List<V> row(int row) => subList(
        data,
        dataIndex(0, row, colCount),
        dataIndex(0, row, colCount) + colCount,
      );

  // ...........................................................................
  List<V> col(int col) => subList(
        dataT,
        dataIndexT(col, 0, rowCount),
        dataIndexT(col, 0, rowCount) + rowCount,
      );

  // ###########################
  // Data manipulation delegates
  // ###########################

  // ...........................................................................
  final List<V> Function(int length) createBuffer;
  final List<V> Function(List<V>) copyBuffer;
  final List<V> Function(List<V>, int start, int? end) subList;

  // ######################
  // Data
  // ######################

  // ...........................................................................
  final int rowCount;
  final int colCount;
  final List<V> data;
  final List<V> dataT;
  final Int64List colHashes;
  final Int64List rowHashes;

  @override
  final int hashCode;

  // ...........................................................................
  @override
  bool operator ==(Object other) {
    return this.hashCode == other.hashCode;
  }

  // ######################
  // Private
  // ######################

  // ...........................................................................
  factory Gg2dList.special({
    required List<V> Function(int length) createBuffer,
    required List<V> Function(List<V>) copyBuffer,
    required List<V> Function(List<V>, int start, int? end) subList,
    required int colCount,
    required int rowCount,
    V Function(int col, int row)? createValue,
    V? minValue,
    V? maxValue,
  }) {
    // Create buffers
    final length = colCount * rowCount;
    final data = createBuffer(length);
    final dataT = createBuffer(length);

    // Generate data
    if (createValue != null) {
      var i = 0;
      for (var row = 0; row < rowCount; row++) {
        for (var col = 0; col < colCount; col++) {
          final val = createValue(col, row);
          data[i] = val;
          i++;
        }
      }
    }

    // transpose(data, dataT);
    transpose(
      original: data,
      transposed: dataT,
      rowCount: rowCount,
      colCount: colCount,
    );

    // Calculate hashes
    final rowHashes = Int64List(rowCount);
    final colHashes = Int64List(colCount);

    updateAllHashes(
      data: data,
      dataT: dataT,
      rowHashes: rowHashes,
      colHashes: colHashes,
      colCount: colCount,
      rowCount: rowCount,
    );
    final hashCode = overallHash(rowHashes: rowHashes);

    // Create result object
    final result = Gg2dList<V>(
      data: data,
      dataT: dataT,
      rowHashes: rowHashes,
      colHashes: colHashes,
      hashCode: hashCode,
      createBuffer: createBuffer,
      copyBuffer: copyBuffer,
      subList: subList,
      rowCount: rowCount,
      colCount: colCount,
    );

    // Return result object
    return result;
  }
}
