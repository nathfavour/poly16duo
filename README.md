# poly16duo

`poly16duo` is a zero-dependency, zero-allocation, post-quantum cryptographic (PQC) primitive written in Zig and compiled to freestanding WebAssembly (`wasm32-freestanding`). 

Designed for serverless edge runtimes, it features comptime domain-isolated execution loops, pure-SIMD serialization to prevent register spills, and a stateless memory model to guarantee absolute multi-tenant thread isolation.

## Features

- **Freestanding WebAssembly**: No polyfills, no JS-glue, zero system-call dependencies. Compiles to a self-contained WebAssembly binary under 10 KB.
- **Pure-SIMD Serializer**: Splicing algorithms execute strictly in 128-bit vector registers using `@shuffle` and bit-wise shifts, avoiding stack spills and scalar extraction instructions.
- **Strict Statelessness**: Functions operate purely on host-provided scratchpads, eliminating in-WASM global state leakages.
- **Comptime Domain Isolation**: Strict separation of ring parameters ($N=256, q=3329$ modular LWE KEM vs $N=512$ modulus-free HAWK signature verification) using Zig's compile-time static polymorphism.

## Directory Layout

- `src/main.zig`: Host interface exports and test entry point.
- `src/ring.zig`: Butterfly NTT loops, twiddle masking, and exact 64-bit convolution engines.
- `src/splicer.zig`: Bit-splicing register aligner for 10-bit, 12-bit, and 14-bit coefficients.
- `src/kem.zig`: Module-LWE KEM (Key Generation, Encapsulation, Decapsulation).
- `src/hawk.zig`: HAWK-512 digital signature verification layer.
- `build.zig`: Build configuration for native tests and WebAssembly targets.

## Building and Testing

### Prerequisites
- [Zig Compiler v0.16.0](https://ziglang.org/download/)

### Build the WebAssembly Binary
```bash
zig build
```
The compiled output is generated under `zig-out/wasm/poly16duo.wasm`.

### Run Unit Tests
```bash
zig build test
```

## License

This project is licensed under the [MIT License](LICENSE).
