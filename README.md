# Katali Bonsai Runtime

Binary-only release of the Katali CPU runtime for Bonsai Q1_0 GGUF
checkpoints, including Bonsai 1.7B and the experimental 27B path.

The optimized Windows AVX2 path uses Q8 activation quantization, a four-row
Q1×Q8 kernel, fused DeltaNet projections, fused FFN gate/up projections, and
inline scheduling for tiny projections. On the development i5-10400 system
the Bonsai 27B path measured about 1.6 tok/s with 12 threads while preserving
coherent output on the fixed smoke prompts.

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

Direct download: <https://huggingface.co/prism-ml/Bonsai-27B-gguf/resolve/main/Bonsai-27B-Q1_0.gguf?download=true>

```powershell
.\katali.exe generate Bonsai-27B-Q1_0.gguf "What is the capital of France?" --max 32 --threads 12
```

The 27B model runs in CPU/system-RAM mode and is substantially slower than the
1.7B build on ordinary desktop CPUs.

For maximum throughput on an NVIDIA GPU, enable Katali's fused CUDA DeltaNet
path while keeping the large FFN weights in system RAM:

```powershell
$env:KATALI_CUDA_MOE = "1"
$env:KATALI_CUDA_GDN = "1"
$env:KATALI_CUDA_DP4A = "1"
.\katali.exe generate Bonsai-27B-Q1_0.gguf "Hello" --max 32 --threads 12
```

On the development RTX 4060/i5-10400 system this CUDA path measured slower
than the CPU/RAM path because of launch and transfer overhead. For maximum
27B throughput, leave these CUDA variables unset and use `--threads 12`.
The full dense-GPU residency tier is also not recommended because its extra
transfer overhead measured slower.

## Local HTTP API

Start the loopback-only API with the optimized runtime:

```powershell
.\katali.exe api --port 8080
```

It provides `GET /health`, `POST /generate`, the short `POST /v1/chat` route,
and the OpenAI-compatible `POST /v1/chat/completions`. Include the model path
in each generation request:

```powershell
$body = @{
  model = 'C:\models\Bonsai-1.7B-Q1_0.gguf'
  messages = @(@{ role = 'user'; content = 'What is the capital of France?' })
  max_tokens = 32
} | ConvertTo-Json -Depth 4

Invoke-RestMethod http://127.0.0.1:8080/v1/chat/completions `
  -Method Post -ContentType 'application/json' -Body $body
```

### API-key tutorial

This local server does not require or validate an API key. It listens only on
`127.0.0.1`, so a key is unnecessary for local use. OpenAI-compatible clients
that require a non-empty key can use any placeholder value; it is not checked
by Katali:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:8080/v1",
    api_key="local-not-used",
)

reply = client.chat.completions.create(
    model=r"C:\models\Bonsai-1.7B-Q1_0.gguf",
    messages=[{"role": "user", "content": "Say hello"}],
    max_tokens=32,
)
print(reply.choices[0].message.content)
```

Do not expose this server to a network interface: it has no authentication
layer. Keep it bound to loopback or place an authenticated reverse proxy in
front of it.

For incremental output, add `stream = $true` to the request. The server binds
to `127.0.0.1` only and processes requests sequentially.

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
