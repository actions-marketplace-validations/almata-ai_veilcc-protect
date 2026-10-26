<p align="center">
  <img src="assets/veilcc-icon.png" alt="VeilCC" width="88" />
</p>

# VeilCC Protect — GitHub Action

Protect the functions worth stealing on every release. Your build produces a
compiled object (to seal) or LLVM IR (to obfuscate); this action returns a
protected artifact you link exactly as before. The protection runs server-side,
so the algorithm never ships inside your binary.

## Usage (hosted API — your passes stay server-side)

```yaml
- name: Build the sensitive unit
  run: clang -O2 -c license.c -o license.o

- name: Protect with VeilCC
  id: veil
  uses: almata-ai/veilcc-protect@v1
  with:
    input: license.o
    level: seal                       # obfuscate | seal | device-bound
    proto: "uint32_t check_license(const char*)"
    anti-debug: true
    output: license.sealed.o
    receipt: build-receipt.json
    api-key: ${{ secrets.VEILCC_KEY }}

- name: Link the protected object
  run: clang ${{ steps.veil.outputs.protected }} main.o -o app
```

Obfuscating IR instead:

```yaml
- run: clang -O2 -S -emit-llvm -c secret.c -o secret.ll
- uses: almata-ai/veilcc-protect@v1
  with:
    input: secret.ll
    level: obfuscate
    symbols: my_secret_fn=max
    seed: "0x9f3ac1d2e4b60718"         # optional: reproducible build
    output: secret.o
    api-key: ${{ secrets.VEILCC_KEY }}
```

## Local mode (air-gapped CI — obfuscate only, uses a local plugin)

```yaml
- uses: almata-ai/veilcc-protect@v1
  with:
    input: secret.ll
    symbols: my_secret_fn=max
    mode: local
    plugin: ./build/llvm-pass/libVeilPass.so   # requires LLVM opt/llc on PATH
```

## Inputs
| input | required | default | notes |
|---|---|---|---|
| `input` | yes | — | object `.o` (seal) or IR `.ll`/`.bc` (obfuscate) |
| `level` | no | `seal` | `obfuscate` · `seal` · `device-bound` |
| `proto` | no | — | seal: sealed function's C signature |
| `symbols` | no | — | `fn=max`, comma-separated for several |
| `target` | no | `auto-detect` | output triple |
| `persistent` | no | `false` | seal: cache the decrypted function |
| `anti-debug` | no | `false` | seal: fold a debugger check into the key |
| `key-provider` | no | — | device-bound: runtime key-unwrap symbol |
| `seed` | no | — | obfuscate: fixed build seed (`0x…`) |
| `output` | no | `veil-protected.o` | protected artifact path |
| `receipt` | no | — | write the signed receipt JSON here |
| `mode` | no | `api` | `api` or `local` |
| `api-key` | api | — | store as a secret |
| `api-url` | no | `https://veilcc.com` | on-prem: point at your own API |
| `plugin` | local | — | `libVeilPass.(so\|dylib)` |

Output: `protected` — path to the protected artifact.

API mode speaks the same contract as the [`veil` CLI](https://veilcc.com/docs/cli) and the console:
`POST {api-url}/api/protect`. On-prem and air-gapped teams set `api-url` to their
own Protection API; the object never leaves the network. Full reference:
https://veilcc.com/docs/cli
