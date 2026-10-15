// Dart adaptation of edge-tts 7.3.0 src/edge_tts/drm.py.
// Copyright (c) 2025- rany <rany@riseup.net>
// Modifications Copyright (c) 2026 Modu contributors.
// SPDX-License-Identifier: LGPL-3.0-only
// Source: https://github.com/rany2/edge-tts/blob/7.3.0/src/edge_tts/drm.py
// See LICENSES/edge-tts-LGPL-3.0.txt and LICENSE.

import 'dart:convert';
import 'dart:typed_data';

/// Consumer Read Aloud v2 authentication. This is a protocol-specific digest,
/// not ordinary SHA-256 and not a general-purpose cryptographic primitive.
String edgeTtsV2Token(int windowsTicks, String trustedClientToken) {
  final data = ascii.encode('$windowsTicks$trustedClientToken');
  final digest = _digest(data);
  final checksum = _checksum(data, digest);
  return '${_hex(checksum)}-${_hex(digest)}';
}

const _mask = 0xffffffff;
const _initial = [
  0x6A09E667,
  0xBB67AE85,
  0x3C6EF372,
  0xA54FF53A,
  0x510E527F,
  0x9B05688C,
  0x1F83D9AB,
  0x5BE0CD19,
];
const _state = [
  0xFD9FBEA2,
  0x91243CE7,
  0xBE499094,
  0xCD2E1E0A,
  0x6C006F49,
  0x04BD35AB,
  0xFEB0A7E4,
  0x03EFFBD2,
];
const _schedule = [
  0xEB24BF9E,
  0x1558691F,
  0xA0C09EE2,
  0x0CFA32BA,
  0xA622EE8C,
  0xD1DD9491,
  0xC0DD25A0,
  0xF9E70AB6,
  0xF0C31573,
  0x7058CE4E,
  0x7188E606,
  0x00E5AB33,
  0xD258B060,
  0x72766564,
];
const _roundConstants = [
  0x428A2F98,
  0x71374491,
  0xB5C0FBCF,
  0xE9B5DBA5,
  0x3956C25B,
  0x59F111F1,
  0x923F82A4,
  0xAB1C5ED5,
  0xD807AA98,
  0x12835B01,
  0x243185BE,
  0x550C7DC3,
  0x72BE5D74,
  0x80DEB1FE,
  0x9BDC06A7,
  0xC19BF174,
  0xE49B69C1,
  0xEFBE4786,
  0x0FC19DC6,
  0x240CA1CC,
  0x2DE92C6F,
  0x4A7484AA,
  0x5CB0A9DC,
  0x76F988DA,
  0x983E5152,
  0xA831C66D,
  0xB00327C8,
  0xBF597FC7,
  0xC6E00BF3,
  0xD5A79147,
  0x06CA6351,
  0x14292967,
  0x27B70A85,
  0x2E1B2138,
  0x4D2C6DFC,
  0x53380D13,
  0x650A7354,
  0x766A0ABB,
  0x81C2C92E,
  0x92722C85,
  0xA2BFE8A1,
  0xA81A664B,
  0xC24B8B70,
  0xC76C51A3,
  0xD192E819,
  0xD6990624,
  0xF40E3585,
  0x106AA070,
  0x19A4C116,
  0x1E376C08,
  0x2748774C,
  0x34B0BCB5,
  0x391C0CB3,
  0x4ED8AA4A,
  0x5B9CCA4F,
  0x682E6FF3,
  0x748F82EE,
  0x78A5636F,
  0x84C87814,
  0x8CC70208,
  0x90BEFFFA,
  0xA4506CEB,
  0xBEF9A3F7,
  0xC67178F2,
];
const _coefficients = [
  (0xE82E91B1, 0xB32700D0),
  (0x44DE24C6, 0x88DFF51D),
  (0x3BEB65BC, 0x29514038),
  (0xC89C5933, 0xB328CBDF),
  (0x8D1EC211, 0xD405B4D5),
  (0x314EF5D5, 0x26E55F3C),
  (0xE92491B1, 0x607801C6),
  (0xF0A5B9D5, 0x82B2C1FB),
  (0x06064CF3, 0xFA51A3DA),
  (0xDA79FA60, 0x207CC464),
  (0xBED20560, 0x3C3C74F3),
  (0x89F9C9F8, 0xD2D14B61),
  (0x35FA38C6, 0xBB04A2C1),
  (0xCB49E3C6, 0xC5626167),
];

String _hex(List<int> bytes) => bytes
    .map((value) => value.toRadixString(16).padLeft(2, '0'))
    .join()
    .toUpperCase();

int _rotate(int value, int bits) =>
    ((value >> bits) | (value << (32 - bits))) & _mask;
int _sigma0(int value) => _rotate(value, 7) ^ _rotate(value, 18) ^ (value >> 3);
int _sigma1(int value) =>
    _rotate(value, 17) ^ _rotate(value, 19) ^ (value >> 10);

void _expand(List<int> words, [int start = 16]) {
  for (var i = start; i < 64; i++) {
    words.add((_sigma1(words[i - 2]) +
            words[i - 7] +
            _sigma0(words[i - 15]) +
            words[i - 16]) &
        _mask);
  }
}

List<int> _rounds(List<int> state, List<int> words, [int start = 0]) {
  var a = state[0], b = state[1], c = state[2], d = state[3];
  var e = state[4], f = state[5], g = state[6], h = state[7];
  for (var i = start; i < 64; i++) {
    final constant = start == 14 && i == 14 ? 0xC9DC06A7 : _roundConstants[i];
    final t1 = h +
        (_rotate(e, 6) ^ _rotate(e, 11) ^ _rotate(e, 25)) +
        (g ^ (e & (f ^ g))) +
        constant +
        words[i];
    final t2 = (_rotate(a, 2) ^ _rotate(a, 13) ^ _rotate(a, 22)) +
        ((a & b) | (c & (a | b)));
    h = g;
    g = f;
    f = e;
    e = (d + t1) & _mask;
    d = c;
    c = b;
    b = a;
    a = (t1 + t2) & _mask;
  }
  return [a, b, c, d, e, f, g, h];
}

List<int> _addState(List<int> state, List<int> working) =>
    List.generate(8, (i) => (state[i] + working[i]) & _mask);

Uint8List _digest(List<int> data) {
  final words = List<int>.filled(14, 0, growable: true)
    ..add((data[0] << 16) | (data[1] << 8) | data[2])
    ..add((data[3] << 24) | (data[4] << 16) | (data[5] << 8) | data[6]);
  for (var i = 16; i < 30; i++) {
    var value = _schedule[i - 16];
    value += _sigma1(words[i - 2]) ^ (i == 16 ? 0x000B92C0 : 0);
    if (i - 7 >= 14) value += words[i - 7];
    if (i - 15 >= 14) {
      value += _sigma0(words[i - 15]) ^ (i == 29 ? 0x059C0B80 : 0);
    }
    words.add(value & _mask);
  }
  words.add((_sigma1(words[28]) +
          words[23] +
          _sigma0(words[15]) +
          words[14] +
          0xC9DC06A7 -
          _roundConstants[14]) &
      _mask);
  _expand(words, 31);
  var state = _addState(_initial, _rounds(_state, words, 14));
  final length = 57 + data.length;
  final padding = Uint8List(data.length - 7 + 1 + (55 - length) % 64 + 8);
  padding.setRange(0, data.length - 7, data, 7);
  padding[data.length - 7] = 0x80;
  final bytes = ByteData.sublistView(padding);
  bytes.setUint64(padding.length - 8, length * 8);
  for (var offset = 0; offset < padding.length; offset += 64) {
    final block = List.generate(16, (i) => bytes.getUint32(offset + i * 4));
    _expand(block);
    state = _addState(state, _rounds(state, block));
  }
  final result = ByteData(32);
  for (var i = 0; i < 8; i++) {
    result.setUint32(i * 4, state[i]);
  }
  return result.buffer.asUint8List();
}

Uint8List _checksum(List<int> data, Uint8List digest) {
  final hash = ByteData.sublistView(digest);
  final keyA = hash.getUint32(0, Endian.little) | 1;
  final keyB = hash.getUint32(4, Endian.little) | 1;
  final factors = [keyA * 0x82893933 & _mask, keyB * 0x82893933 & _mask];
  final terms =
      List.generate(14, (i) => _coefficients[i].$1 * factors[i % 2] & _mask);
  final offsets = _coefficients.map((pair) => pair.$2).toList();
  final padded = Uint8List(((data.length + 1 + 7) ~/ 8) * 8);
  padded.setRange(1, data.length + 1, data);
  final bytes = ByteData.sublistView(padded);
  for (var i = 0; i < padded.length ~/ 4; i++) {
    final word = bytes.getUint32(i * 4, Endian.little);
    var term = word * (i.isEven ? keyA : keyB);
    var offset = _rotate(word, 16) * (i.isEven ? 0xEF0569FB : 0xC31713DB);
    if (i == 0) {
      term += 0xF2F90B1A * factors[0];
      offset += 0x0B1A0000;
    }
    terms.add(term & _mask);
    offsets.add(offset & _mask);
  }
  var swapAcc = 0, swapLast = 0, state = 0, acc = 0;
  for (var i = 0; i < terms.length; i += 2) {
    final x = terms[i], y = terms[i + 1];
    var t = _rotate((offsets[i] + x) & _mask, 16);
    var q = t * 0x76F50F34 & _mask;
    swapAcc += (_rotate(q, 16) * 0xC3EFEA97 + q) & _mask;
    t = _rotate((offsets[i + 1] + y) & _mask, 16);
    q = t * 0x1881CE3C & _mask;
    swapLast = (_rotate(q, 16) * 0x35BD1EC9 + q) & _mask;
    swapAcc = (swapAcc + swapLast) & _mask;
    state = (state * keyA + x) & _mask;
    state = _rotate(state, 16) * 0xCF98B111 & _mask;
    state = _rotate(state, 16) * 0x87085B9F & _mask;
    state = _rotate(state, 16) * 0x12CEB96D & _mask;
    state = _rotate(state, 16) * 0x257E1D83 & _mask;
    acc += state;
    t = (state * keyB + y) & _mask;
    t = _rotate(t, 16) * 0xA27416F5 & _mask;
    t = _rotate(t, 16) * 0xD38396FF & _mask;
    state =
        _rotate(_rotate(t, 16) * 0x7C932B89 & _mask, 16) * 0xBFA49F69 & _mask;
    acc = (acc + state) & _mask;
  }
  final result = ByteData(8)
    ..setUint32(0, swapLast ^ state, Endian.little)
    ..setUint32(4, swapAcc ^ acc, Endian.little);
  return result.buffer.asUint8List();
}
