# Katali BitNet

Katali BitNet is a lightweight Windows chat application and local HTTP API for running 1.58-bit language models on the CPU.

The current default is Falcon3 10B Instruct 1.58-bit. On the development PC it answers factual prompts at roughly **6.9 tokens/sec** using 8 CPU threads.

## Quick start

The binary release includes `build-katali\katali-bit-gui.exe`, `build-katali\katali-bit.exe`, and `katali-bit-api.exe`. Download a model separately using the links below.

Run the native Windows GUI:

```powershell
Start-Process .\build-katali\katali-bit-gui.exe -WorkingDirectory (Get-Location)
```

The GUI includes a dark chat interface, persistent model loading, New chat, Copy transcript, and tokens-per-second status.

The default model path is:

```text
models\Falcon3-10B-Instruct-1.58bit-GGUF\ggml-model-i2_s.gguf
```

## API tutorial

The local API listens on `127.0.0.1:8080`.

Start it with:

```powershell
.\katali-bit-api.exe
```

Check health:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/api/health
```

Send a chat request:

```powershell
$payload = @{
  messages = @(
    @{ role = "user"; content = "What is the capital of the Philippines?" }
  )
  max_tokens = 64
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
  -Uri http://127.0.0.1:8080/api/chat `
  -Method Post `
  -ContentType "application/json" `
  -Body $payload
```

Example response:

```json
{
  "response": "The capital of the Philippines is Manila.",
  "metrics": {
    "generated_tokens": 8,
    "tokens_per_second": 6.86
  },
  "model": "ggml-model-i2_s.gguf"
}
```

Using `curl.exe`:

```powershell
curl.exe -X POST http://127.0.0.1:8080/api/chat `
  -H "Content-Type: application/json" `
  -d '{"messages":[{"role":"user","content":"Explain BitNet in one sentence."}],"max_tokens":64}'
```

### API endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/health` | Check the engine and model |
| `POST` | `/api/chat` | Generate a response |
| `OPTIONS` | `/api/chat` | CORS preflight |

### Select another model

Set `BITNET_MODEL` before starting the server:

```powershell
$env:BITNET_MODEL = (Resolve-Path .\models\Llama3-8B-1.58-GGUF\ggml-model-i2_s.gguf).Path
.\katali-bit-api.exe
```

Use another port if needed:

```powershell
$env:KATALI_PORT = "8090"
.\katali-bit-api.exe
```

## Available models

Recommended compatible models:

- [BitNet b1.58 2B-4T GGUF](https://huggingface.co/microsoft/bitnet-b1.58-2B-4T-gguf)
- [Falcon3 3B Instruct 1.58-bit GGUF](https://huggingface.co/tiiuae/Falcon3-3B-Instruct-1.58bit-GGUF)
- [Llama 3 8B 1.58-bit GGUF](https://huggingface.co/eugenehp/Llama3-8B-1.58-100B-tokens-GGUF)
- [Falcon3 7B Instruct 1.58-bit GGUF](https://huggingface.co/tiiuae/Falcon3-7B-Instruct-1.58bit-GGUF)
- [Falcon3 10B Instruct 1.58-bit GGUF](https://huggingface.co/tiiuae/Falcon3-10B-Instruct-1.58bit-GGUF)

Experimental community models:

- [Qwen2.5-Coder 32B BitNet](https://huggingface.co/tzervas/qwen2.5-coder-32b-bitnet-1.58b)
- [Qwen3-Next ternary GGUF](https://huggingface.co/Schackay3/Qwen3-Next-80B-A3B-Instruct-ternary-GGUF)

The Falcon family, Llama 3 8B, and BitNet 2B are the safest choices for this project. Larger community ternary models may require a different runtime.

## Build from source

```powershell
cmake -S . -B build-katali -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
cmake --build build-katali --config Release --parallel 4
```

The runtime is based on Microsoft's [BitNet](https://github.com/microsoft/BitNet) and its `llama.cpp` backend.

## Measured performance

| Model | File size | Speed |
|---|---:|---:|
| Falcon3 3B Instruct | 2.2 GB | 16.45 tok/s |
| Llama 3 8B 1.58-bit | 3.86 GB | 8.24 tok/s |
| Falcon3 10B Instruct | 3.99 GB | 6.86 tok/s |

Measurements are from the local development PC using 8 CPU threads.

## Binary-only releases

End users only need the release executables, required runtime DLLs, this README, and a model downloaded from the links above. Do not include the C++ source, headers, vendored dependencies, build folders, logs, or temporary files in a binary-only release.

## Repository

[github.com/katalidevai/katali-bit](https://github.com/katalidevai/katali-bit)
