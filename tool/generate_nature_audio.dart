// Development-only synthesiser for the Mangaale nature sound assets.
//
// This file is NOT part of the app. It lives outside `lib/` and is never
// compiled into a build. Run it only when the asset needs regenerating:
//
//     dart run tool/generate_nature_audio.dart
//
// It writes `assets/audio/water_drop.wav`.
//
// ---------------------------------------------------------------------------
// Why synthesise instead of shipping a recording
// ---------------------------------------------------------------------------
// A generated asset carries no licensing question and is reproducible — the
// RNG is seeded, so re-running this produces a byte-identical file. If a
// licensed recording is preferred later it drops into the same path and
// nothing else in the app changes.
//
// ---------------------------------------------------------------------------
// How a splash is built (and how to avoid the cartoon "bloop")
// ---------------------------------------------------------------------------
// A real object entering water is three overlapping things:
//
//   1. Impact  — a broadband surface-break transient, a few tens of ms.
//   2. Bubbles — the part the ear reads as "water". Each entrained bubble
//                rings as a damped sinusoid whose pitch *rises* as it
//                collapses (Minnaert resonance). A single loud one of these
//                is exactly the cartoon "bloop"; a couple of dozen quiet ones
//                at scattered frequencies and onsets is a splash.
//   3. Spray   — a soft band-limited fizz decaying over ~250 ms, which gives
//                the "spill" character rather than a dry click.
//
// The three failure modes named in review map directly onto this model:
//   * artificial sine tone  -> bubbles present, noise layers missing
//   * cartoon drop          -> one dominant bubble instead of many quiet ones
//   * tap-water stream      -> spray sustained too long with no transient
//
// So: no single partial is allowed to dominate, the tail is short, and the
// whole thing is gently low-passed so it stays warm rather than brittle when
// heard repeatedly.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _sampleRate = 32000;
const double _durationSeconds = 0.42;

/// Peak the rendered file is normalised to.
///
/// Deliberately well below full scale: this is a background courtesy sound
/// played on every add-to-cart, and the feedback service attenuates it further
/// at playback time. Headroom here means the file itself is never harsh.
const double _peakTarget = 0.52;

void main(List<String> args) {
  final samples = _renderWaterDrop();
  final file = File('assets/audio/water_drop.wav');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(_encodeWav16(samples, _sampleRate));

  final seconds = samples.length / _sampleRate;
  stdout.writeln('Wrote ${file.path}');
  stdout.writeln(
    '  ${samples.length} samples · '
    '${seconds.toStringAsFixed(3)}s · '
    '$_sampleRate Hz mono 16-bit · '
    '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
  );
}

List<double> _renderWaterDrop() {
  // Fixed seed: the asset must be reproducible across machines and reruns.
  final random = Random(20260902);
  final length = (_durationSeconds * _sampleRate).round();
  final out = List<double>.filled(length, 0);

  _addImpact(out, random);
  _addBubbles(out, random);
  _addSpray(out, random);

  // Absorption sweep. Water damps high frequencies faster than low ones, so a
  // real splash gets progressively darker as it settles. Without this the tail
  // brightens instead — the rising partials of the small bubbles outlive the
  // spray — and a rising tail is precisely what reads as electronic sparkle
  // rather than water. Measured spectral centroid must fall across the file.
  _sweepLowPassInPlace(out, startHz: 9800, endHz: 2200);

  // The high-pass removes sub-bass energy a phone speaker cannot reproduce and
  // that only muddies the result.
  _highPassInPlace(out, 190);

  _applyTailFade(out, 0.030);
  _normalise(out, _peakTarget);
  return out;
}

/// The surface break: a short broadband burst, softened at the very start so
/// it reads as a splash rather than a click.
void _addImpact(List<double> out, Random random) {
  const decay = 0.026;
  const attack = 0.0012;
  final scratch = List<double>.filled(out.length, 0);

  for (var i = 0; i < out.length; i++) {
    final t = i / _sampleRate;
    if (t > 0.10) break;
    final rise = 1 - exp(-t / attack);
    final fall = exp(-t / decay);
    scratch[i] = (random.nextDouble() * 2 - 1) * rise * fall;
  }

  // Band the transient into the range where a water impact actually lives.
  _highPassInPlace(scratch, 900);
  _lowPassInPlace(scratch, 7000);

  for (var i = 0; i < out.length; i++) {
    out[i] += scratch[i] * 0.68;
  }
}

/// The part that makes it read as water.
///
/// Twenty-two quiet bubbles, each a rising-pitch damped sinusoid, scattered
/// across frequency and onset time. Amplitudes are capped low and rolled off
/// with frequency so no single partial pokes out of the texture — that cap is
/// the whole difference between "splash" and "cartoon plink".
void _addBubbles(List<double> out, Random random) {
  const bubbleCount = 22;

  for (var b = 0; b < bubbleCount; b++) {
    // Onsets cluster tightly behind the impact and thin out after it, the way
    // real entrained air does. Spreading them wider pushes the loudest moment
    // away from the strike and the result swells instead of splashing.
    final onset = 0.002 + 0.048 * pow(random.nextDouble(), 2.1).toDouble();

    // Log-uniform across the audible bubble range: even spacing in pitch
    // rather than in Hz, so the texture sounds natural instead of banded.
    final baseFrequency = 520 * pow(4700 / 520, random.nextDouble()).toDouble();

    // Smaller bubbles ring higher and die faster.
    final pitchFactor = (baseFrequency - 520) / (4700 - 520);
    final life = 0.055 - 0.036 * pitchFactor + random.nextDouble() * 0.010;

    // Minnaert rise: pitch climbs as the bubble collapses. Capped in absolute
    // terms — an unbounded rise sends the small bubbles into a glassy 12 kHz
    // chime that no longer sounds like water.
    const riseCeilingHz = 6200.0;
    final requestedRise = 1.35 + random.nextDouble() * 1.5;
    final rise = min(requestedRise, max(1.1, riseCeilingHz / baseFrequency));

    // Quiet, and quieter still up high where the ear is most sensitive.
    final amplitude =
        (0.11 + random.nextDouble() * 0.14) * (1 - 0.55 * pitchFactor);

    final phase0 = random.nextDouble() * 2 * pi;
    final startIndex = (onset * _sampleRate).round();
    final endIndex = min(out.length, startIndex + (life * 5 * _sampleRate).round());

    var phase = phase0;
    for (var i = startIndex; i < endIndex; i++) {
      final t = (i - startIndex) / _sampleRate;
      final progress = t / life;
      final frequency = baseFrequency * (1 + (rise - 1) * progress);
      phase += 2 * pi * frequency / _sampleRate;

      // Short fade-in on each partial so no bubble starts with a click.
      final attack = 1 - exp(-t / 0.0009);
      final envelope = attack * exp(-t / life);
      out[i] += sin(phase) * envelope * amplitude;
    }
  }
}

/// The spill tail: soft fizz that decays away over ~250 ms.
///
/// Its band centre sweeps downward, which is what a settling water surface
/// does and what keeps this from sounding like a running tap.
void _addSpray(List<double> out, Random random) {
  final scratch = List<double>.filled(out.length, 0);

  for (var i = 0; i < out.length; i++) {
    final t = i / _sampleRate;
    // Arrives with the impact rather than after it, then falls away quickly.
    final rise = 1 - exp(-t / 0.0035);
    final fall = exp(-t / 0.062);
    scratch[i] = (random.nextDouble() * 2 - 1) * rise * fall;
  }

  // Downward-sweeping band, applied as a cascaded high-pass/low-pass pair with
  // time-varying cutoffs.
  _sweepBandInPlace(scratch, highStart: 2400, highEnd: 900, lowStart: 8200, lowEnd: 3400);

  for (var i = 0; i < out.length; i++) {
    out[i] += scratch[i] * 0.30;
  }
}

// ---------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------

void _lowPassInPlace(List<double> buffer, double cutoffHz) {
  final alpha = 1 - exp(-2 * pi * cutoffHz / _sampleRate);
  var state = 0.0;
  for (var i = 0; i < buffer.length; i++) {
    state += alpha * (buffer[i] - state);
    buffer[i] = state;
  }
}

/// One-pole low-pass whose cutoff glides from [startHz] down to [endHz] across
/// the buffer, modelling how water absorbs high frequencies as it settles.
void _sweepLowPassInPlace(
  List<double> buffer, {
  required double startHz,
  required double endHz,
}) {
  var state = 0.0;
  for (var i = 0; i < buffer.length; i++) {
    final progress = i / (buffer.length - 1);
    // Glide in pitch rather than in Hz, so the darkening is perceptually even.
    final cutoff = startHz * pow(endHz / startHz, progress).toDouble();
    final alpha = 1 - exp(-2 * pi * cutoff / _sampleRate);
    state += alpha * (buffer[i] - state);
    buffer[i] = state;
  }
}

void _highPassInPlace(List<double> buffer, double cutoffHz) {
  final rc = 1 / (2 * pi * cutoffHz);
  final dt = 1 / _sampleRate;
  final alpha = rc / (rc + dt);
  var previousIn = 0.0;
  var previousOut = 0.0;
  for (var i = 0; i < buffer.length; i++) {
    final input = buffer[i];
    previousOut = alpha * (previousOut + input - previousIn);
    previousIn = input;
    buffer[i] = previousOut;
  }
}

/// Cascaded high-pass then low-pass whose cutoffs glide linearly across the
/// buffer, giving the spray a settling character.
void _sweepBandInPlace(
  List<double> buffer, {
  required double highStart,
  required double highEnd,
  required double lowStart,
  required double lowEnd,
}) {
  final dt = 1 / _sampleRate;
  var hpPreviousIn = 0.0;
  var hpPreviousOut = 0.0;
  var lpState = 0.0;

  for (var i = 0; i < buffer.length; i++) {
    final progress = i / (buffer.length - 1);

    final highCutoff = highStart + (highEnd - highStart) * progress;
    final rc = 1 / (2 * pi * highCutoff);
    final hpAlpha = rc / (rc + dt);
    final input = buffer[i];
    hpPreviousOut = hpAlpha * (hpPreviousOut + input - hpPreviousIn);
    hpPreviousIn = input;

    final lowCutoff = lowStart + (lowEnd - lowStart) * progress;
    final lpAlpha = 1 - exp(-2 * pi * lowCutoff / _sampleRate);
    lpState += lpAlpha * (hpPreviousOut - lpState);

    buffer[i] = lpState;
  }
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

/// Ramps the last [seconds] to exactly zero so the file cannot end on a step,
/// which would be audible as a tick on every playback.
void _applyTailFade(List<double> buffer, double seconds) {
  final fadeLength = (seconds * _sampleRate).round();
  final start = buffer.length - fadeLength;
  for (var i = max(0, start); i < buffer.length; i++) {
    final progress = (i - start) / fadeLength;
    buffer[i] *= 1 - progress;
  }
  buffer[buffer.length - 1] = 0;
}

void _normalise(List<double> buffer, double peak) {
  var maximum = 0.0;
  for (final sample in buffer) {
    maximum = max(maximum, sample.abs());
  }
  if (maximum <= 0) return;
  final gain = peak / maximum;
  for (var i = 0; i < buffer.length; i++) {
    buffer[i] *= gain;
  }
}

Uint8List _encodeWav16(List<double> samples, int sampleRate) {
  const channels = 1;
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataSize = samples.length * blockAlign;

  final bytes = BytesBuilder();
  void writeAscii(String value) => bytes.add(value.codeUnits);
  void writeUint32(int value) => bytes.add(
        Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little),
      );
  void writeUint16(int value) => bytes.add(
        Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little),
      );

  writeAscii('RIFF');
  writeUint32(36 + dataSize);
  writeAscii('WAVE');
  writeAscii('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(channels);
  writeUint32(sampleRate);
  writeUint32(byteRate);
  writeUint16(blockAlign);
  writeUint16(bitsPerSample);
  writeAscii('data');
  writeUint32(dataSize);

  final pcm = Uint8List(dataSize);
  final view = pcm.buffer.asByteData();
  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    view.setInt16(i * 2, (clamped * 32767).round(), Endian.little);
  }
  bytes.add(pcm);

  return bytes.toBytes();
}
