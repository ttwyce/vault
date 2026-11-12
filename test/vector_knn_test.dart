import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/vector_knn.dart';

/// docs/02 §8 A2 退路：Dart 内暴力余弦 KNN 测试。
void main() {
  test('余弦：同向 1、反向 -1、正交 0、零向量 0', () {
    expect(cosineSimilarity(<int>[1, 0], <int>[1, 0]), closeTo(1.0, 1e-9));
    expect(cosineSimilarity(<int>[1, 0], <int>[-1, 0]), closeTo(-1.0, 1e-9));
    expect(cosineSimilarity(<int>[1, 0], <int>[0, 1]), closeTo(0.0, 1e-9));
    expect(cosineSimilarity(<int>[0, 0], <int>[1, 1]), 0.0);
  });

  test('维度不一致 / 空向量拒绝', () {
    expect(
      () => cosineSimilarity(<int>[1], <int>[1, 2]),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => cosineSimilarity(<int>[], <int>[]),
      throwsA(isA<FormatException>()),
    );
  });

  test('KNN 降序 topK；坏维度跳过；同分按 id 稳定', () {
    final hits = bruteForceKnn(
      query: <int>[1, 0],
      vectors: <String, List<int>>{
        'near': <int>[1, 0],
        'mid': <int>[1, 1],
        'far': <int>[-1, 0],
        'bad': <int>[1, 2, 3],
      },
      topK: 2,
    );
    expect(hits.map((VectorHit h) => h.entryId).toList(),
        <String>['near', 'mid']);
    expect(hits.first.score, closeTo(1.0, 1e-9));

    final stable = bruteForceKnn(
      query: <int>[1, 0],
      vectors: <String, List<int>>{
        'b': <int>[1, 0],
        'a': <int>[1, 0],
      },
    );
    expect(stable.map((VectorHit h) => h.entryId).toList(),
        <String>['a', 'b']);
  });

  test('topK<=0 返回空；minScore 过滤', () {
    expect(
      bruteForceKnn(
        query: <int>[1, 0],
        vectors: <String, List<int>>{'a': <int>[1, 0]},
        topK: 0,
      ),
      isEmpty,
    );
    expect(
      bruteForceKnn(
        query: <int>[1, 0],
        vectors: <String, List<int>>{'far': <int>[-1, 0]},
        minScore: 0.5,
      ),
      isEmpty,
    );
  });
}
