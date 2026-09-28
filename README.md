# Katali Bonsai Runtime

Binary-only release of the Katali CPU runtime for Bonsai Q1_0 GGUF
checkpoints, including Bonsai 1.7B and the experimental 27B path.

The optimized Windows AVX2 path uses Q8 activation quantization, a four-row
Q1×Q8 kernel, fused Q/K/V projections, and fused FFN gate/up projections.
On the development i5-10400 system it reached 25+ tok/s with 12 threads while
preserving coherent output on the fixed smoke prompts.

## Run

```powershell
$env:KATALI_BONSAI_Q8 = "1"
.\katali.exe generate Bonsai-1.7B-Q1_0.gguf "What is the capital of France?" --max 32 --threads 12
```

The model file is intentionally not included. Download or provide the Bonsai
Q1_0 GGUF separately.

## Download the model

Download `Bonsai-1.7B-Q1_0.gguf` from the official PrismML Hugging Face
repository:

[Direct download: Bonsai-1.7B-Q1_0.gguf](https://huggingface.co/prism-ml/Bonsai-1.7B-gguf/resolve/main/Bonsai-1.7B-Q1_0.gguf?download=true)

With the Hugging Face CLI:

```powershell
hf download prism-ml/Bonsai-1.7B-gguf Bonsai-1.7B-Q1_0.gguf --local-dir .
```

Place the downloaded file beside `katali.exe`, then run the command above.

For the larger 27B model, use:

```powershell
.\katali.exe generate Bonsai-27B-Q1_0.gguf "What is the capital of France?" --max 32 --threads 12
```

The 27B model runs in CPU/system-RAM mode and is substantially slower than the
1.7B build on ordinary desktop CPUs.

## Larger Bonsai models

The larger checkpoints are also available for testing. Download their Q1_0
files from the corresponding official repositories:

- [Bonsai 4B](https://huggingface.co/prism-ml/Bonsai-4B-gguf)
- [Bonsai 8B — direct Q1_0 download](https://huggingface.co/prism-ml/Bonsai-8B-gguf/resolve/main/Bonsai-8B-Q1_0.gguf?download=true)
- [Bonsai 27B — direct Q1_0 download](https://huggingface.co/prism-ml/Bonsai-27B-gguf/resolve/main/Bonsai-27B-Q1_0.gguf?download=true)

These larger model files are not stored in this GitHub repository.

Recommended files:

- `katali.exe` — CPU runtime
- `katali_cuda.dll`, `cudart64_13.dll` — optional CUDA runtime components
- `docs/bonsai-parity-report.md` — benchmark and correctness record
- `run_affinity_bench.ps1` — 12-thread affinity benchmark helper

This repository is a binary release; source code, build trees, model weights,
logs, and temporary artifacts are intentionally excluded.
