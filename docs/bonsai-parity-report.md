# Bonsai-1.7B Katali validation

Date: 2026-09-28

## Checkpoint and format

- File: `models/bonsai-1.7b/Bonsai-1.7B-Q1_0.gguf`
- Size: 248,302,272 bytes
- GGUF version: 3
- Architecture: Qwen3 dense
- Layers: 28
- Hidden size: 2048
- FFN size: 6144
- Vocabulary: 151,669
- Quantization: `BONSAI_Q1_0_G128`
- All 310 tensors were recognized by Katali’s inspector.

## Reference runtime

The upstream Bonsai Rust runtime completed a greedy CPU run for `The capital of France is` and produced:

```text
The capital of France is **Paris**.
```

The prompt IDs, generated IDs, and top logits are saved in `bonsai-golden-reference.md`.

## Katali runtime

Katali loaded the same checkpoint and completed a full 28-layer generation:

```text
The capital of France is Paris.
```

Measured on this machine:

- Prefill: 4.80 tok/s
- Decode: 1.71 tok/s
- CPU path, 8 threads
- 236.8 MiB mapped model file
- 466.75 MiB KV/state/scratch estimate

## Parity fix and final result

The first comparison exposed a tokenizer bug in Katali’s Qwen2 pre-tokenizer: it emitted separate space tokens instead of the space-prefixed word tokens used by the Bonsai tokenizer. The fix is in `vendor/katali_gguf/src/gguf_tokenizer.c`.

Katali now emits the exact 17 reference prompt IDs:

```text
[151644, 872, 198, 785, 6722, 315, 9625, 374, 151645, 198, 151644, 77091, 198, 151667, 271, 151668, 271]
```

The first top token matches the Rust reference (`785`, logit approximately `22.28` versus `22.32`), and the full greedy output matches exactly:

```text
The capital of France is **Paris**.
```

Katali’s visible generated IDs match the reference through the answer; Katali stops before printing the EOS token while the Rust counter includes it. This is normal front-end counting behavior, not a model-output mismatch.

Final status: Bonsai Q1_0/G128 loading, tokenization, dense Qwen3 execution, greedy sampling, and output parity are verified on the real checkpoint.

## CUDA Q1_0 experiment

The optional CUDA backend now supports type 41 (`BONSAI_Q1_0`) directly:

- 128 values per block
- 18 bytes per block
- FP16 scale followed by 128 LSB-first sign bits
- shared dequantization path used by GEMV and batched GEMV dispatch

The dense tier has an explicit `KATALI_DENSE_FULL_ATTN=1` switch for this
controlled experiment. With `KATALI_DENSE_GPU=1`, `KATALI_DENSE_FULL_ATTN=1`,
and `KATALI_DENSE_TIER=attn,lm`, the RTX 4060 run reported 1,017 CUDA matvec
launches and exercised all 28 attention layers plus the LM head.

The GPU run produced the same greedy answer:

```text
The capital of France is **Paris**.
```

The first top token remained `785` (`The`), matching the golden decision. The
mixed CPU/GPU path shifts raw logits numerically (GPU step 0: about `21.17`
versus the CPU reference `22.32`), so this is token-decision parity, not
bitwise-logit parity.

Measured decode on the RTX 4060:

- CPU-only: about 1.72 tok/s
- CUDA attention + LM head: about 2.67 tok/s
- CUDA residency: 89 MiB; FFN remains CPU-side

This is a real improvement, but it is not yet comparable to the 2B BitNet
benchmark because most of the Bonsai network still runs on the CPU and each
GPU projection currently incurs host/device synchronization.

## Hyphae-style CPU Q1 x Q8 path

Hyphae's important CPU optimization is not merely an AVX2 sign loop. It
quantizes the activation vector once to Q8_0, then reuses that compact vector
for every Q1 output row. Katali now has this path behind
`KATALI_BONSAI_Q8=1` on Windows x86-64 AVX2/FMA.

The path was tested against the same golden prompt and preserved the exact
greedy answer:

```text
The capital of France is **Paris**.
```

The first top token remained `785` (`The`). The raw logits shift slightly,
as expected from Q8 activation quantization, but no token decision changed in
the golden run.

Measured on the i5-10400 with 8 threads:

- Previous Katali CPU Q1 path: about 1.72 tok/s
- Hyphae-style Q1 x Q8 path: 17.38 tok/s
- Speedup: about 10.1x
- CUDA was disabled for this run; the weights remained CPU/system-RAM resident

This brings the 1.7B Bonsai experiment into the same throughput range as the
recorded 2B BitNet CPU result (~16 tok/s). The optimization is opt-in until a
broader parity suite confirms the quantized-activation behavior across prompts.

### Four-row kernel and dispatch tuning

The Q1 x Q8 path now also supports a four-output-row kernel. Four weight rows
share each quantized activation load, and fused projection groups prepare one
Q8 activation buffer for all jobs with the same input vector. The LM head uses
the same path, which is important because its vocabulary-sized row count makes
it the largest single matvec in decode.

On the same Windows i5-10400 system, using the Bonsai-1.7B Q1_0 model and a
24-token decode sample:

| Configuration | Decode speed | Result |
| --- | ---: | --- |
| Q1 x Q8, single-row, 8 threads | 17.35 tok/s | expected answer |
| Q1 x Q8, four-row, 8 threads | 18.89 tok/s | expected answer |
| Q1 x Q8, four-row, 12 threads | **22.82 tok/s** | expected answer |
| Four-row, 12 threads, split dispatch=2 | 18.69 tok/s | expected answer |

The recommended run configuration is therefore `KATALI_BONSAI_Q8=1` with
`--threads 12`; leave `KATALI_GGUF_SPLIT_DISPATCH` at its default of 1.

### Stability and profiling follow-up

The four-row path was checked with 32-token greedy generations on the fixed
smoke prompts. The C-function prompt produced a coherent answer at 22.79
tok/s. The tokenizer, quality/speed, and ternary-risk prompts remained
coherent but measured 10.69, 11.52, and 11.00 tok/s respectively because the
longer generated contexts make attention/KV work grow per token. This means
22.8 tok/s is a valid short-context decode result, not a universal rate.

The new opt-in role profiler shows, on the 24-token factual run, decode matvec
at 91.3% of measured phase time and dispatch wait at 6.6%. The LM head accounts
for 0.1096 s across 25 decode calls (about 12% of the decode kernel time),
while attention Q/K/V/O together account for roughly half. The LM-head role is
now attributed correctly in the CPU fallback profiler. Oversubscribing beyond
12 threads regressed the factual benchmark (20 threads: 20.32 tok/s), so 12
threads remains the current optimum.

A four-row software-prefetch experiment did not improve the result (22.78
tok/s versus the 22.82 tok/s profiled run), so it was not retained. The next
high-value optimization is attention/KV reuse; LM-head-only tuning has a
limited ceiling because it is about 12% of decode kernel time.

### Fused Q/K/V follow-up

The CPU attention path now fuses the Q, K, and V projections when
`KATALI_BONSAI_Q8=1` and the dense GPU tier is inactive. They share one
dispatch and one Q8 activation preparation. The CUDA/tier route is unchanged.

After the change, the factual prompt measured 24.09 tok/s at 32 requested
tokens and 24.16 tok/s at 64 requested tokens (29 tokens emitted before EOS).
The C-function prompt remained correct and measured 24.36 tok/s for 32
generated tokens. `q4_selftest` passed after the rebuild.

### Affinity check

A fixed 12-logical-CPU affinity mask (`0xFFF`) measured 24.61 tok/s on the
factual prompt. Restricting execution to the six physical-core bits (`0x555`)
measured 23.79 tok/s, so the logical-thread mask is preferred. The benchmark
wrapper is `run_affinity_bench.ps1` at the workspace root.

### Fused FFN gate/up follow-up

The shared Bonsai FFN gate and up projections also consume the same activation,
so they now use the fused dispatcher under `KATALI_BONSAI_Q8=1`. This preserved
the C-function response and raised the factual benchmark to 25.27 tok/s. A
second smoke prompt about ternary-weight risks remained coherent at 25.48
tok/s. The final build and `q4_selftest` both pass.
