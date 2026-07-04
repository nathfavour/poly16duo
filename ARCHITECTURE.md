# Architecture & Engineering Specification: poly16duo (v6.0-V2-Production)

poly16duo (v6.0-V2) is a zero-dependency, zero-allocation, post-quantum cryptographic primitive written in Zig and compiled to freestanding WebAssembly (`wasm32-freestanding`). This version hardens the algebraic execution boundaries via comptime static polymorphism, introduces true pure-SIMD serialization algorithms that eliminate scalar register lane extractions, corrects intra-lane twiddle-factor application topologies, and enforces a strictly stateless memory model to guarantee absolute multi-tenant thread isolation in serverless edge runtimes.

```
+--------------------------------------------------------------------------+
|                       64-Byte Host-Provided Seed                         |
+------------------------------------+-------------------------------------+
                                     |
                               [ BLAKE3 KDF ]
                                     |
                +--------------------+--------------------+
                | (Context: "KEM")                        | (Context: "SIG_VERIFY")
                v                                         v
+-----------------------------+             +------------------------------+
|    Module-LWE KEM Engine    |             |    HAWK-512 Verification     |
|   N=256, q=3329 (Modular)   |             |   N=512, Modulus-Free (Z)    |
+--------------+--------------+             +--------------+---------------+
               |                                           |
               +---------------------+---------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
|                  Comptime-Parameterized Vector Engine                    |
| - Domain-isolated execution loops (Modular NTT vs Exact 64-bit Z)        |
| - Pre-masked intra-lane @shuffle butterfly execution pipeline           |
| - Pure-SIMD bit-splicing register alignment (No lane spills)             |
+--------------------------------------------------------------------------+
```

---

## 1. Mathematical Foundation & Comptime Domain Isolation

The execution runtime isolates distinct algebraic domains using Zig's compile-time static polymorphism (`comptime`). This eliminates the risk of executing incompatible modular arithmetic on non-modular integer ring structures, optimizing hardware register allocations per domain.

### A. The Parameter Matrix

| Attribute | Asymmetric KEM Layer (comptime) | Digital Signature Verification Layer (comptime) |
| --- | --- | --- |
| **Algebraic Domain** | $\mathcal{R}_q = \mathbb{Z}_{3329}[X] / (X^{256} + 1)$ | $\mathcal{R} = \mathbb{Z}[X] / (X^{512} + 1)$ |
| **Arithmetic Engine** | Modular Radix-2 Strided NTT with Twiddles | Modulus-Free Exact 64-bit Integer Karatsuba / Schoolbook |
| **Coefficient Type ($T$)** | Signed 16-bit integer (`i16`) | Signed 32-bit integer (`i32`) |
| **Accumulator Type** | Signed 32-bit integer (`i32`) | Signed 64-bit integer (`i64`) |
| **Dimension ($N$)** | 256 | 512 |
| **Security Foundation** | Module Learning With Errors (M-LWE) | Lattice Isomorphism Problem (Module-LIP) |
| **Operations** | Key Generation, Encapsulation, Decapsulation | Signature Verification Only |

### B. Perimeter Seed Isolation

Domain separation is enforced at the cryptographic boundary using custom BLAKE3 context-string derivations:

* **KEM Root Extraction:** $\text{BLAKE3\_XOF}(\text{"poly16duo-kem-v6"} \mathbin{\Vert} \text{master\_seed}[0..32])$
* **Hawk Public Key Extraction:** $\text{BLAKE3\_XOF}(\text{"poly16duo-vfy-v6"} \mathbin{\Vert} \text{master\_seed}[32..64])$

---

## 2. Hybrid Execution & Intra-Lane Vector Shuffle Pipeline

The vector infrastructure splits global wide-stride loops from localized register transformations. Intra-lane stages are executed via native hardware shuffles using Zig’s `@shuffle` built-in, emitting non-spilling `v128.swizzle` instructions in WebAssembly.

To preserve mathematical validity, twiddle vectors are pre-masked with an identity vector (`1`) so that roots of unity are applied strictly to the right-hand elements of the radix-2 Cooley-Tukey butterfly pairs.

---

## 3. Pure-SIMD Bit-Splicing Packing Engine

The serialization engine completely removes scalar element assignments (`v[i]`), preventing vector-to-stack spills and eradicating `llvm.extractelement` instructions. Coefficients are biased, masked, and realigned within 128-bit registers using wide bitwise vector shifts and vector cross-shuffles.

Data is drained via standard unaligned vector slice assignments, letting the LLVM backend optimize down to native target-width memory store primitives (e.g., `i64.store` followed by `i32.store` in 32-bit WebAssembly environments).

---

## 4. Serialization Metrics & Target Layouts

| Pipeline Instance | Ring Size (N) | Bit Width | Bias Bound | Resulting Payload Size |
| --- | --- | --- | --- | --- |
| **KEM Polynomial** | 256 | 12 bits | 0 (Unsigned Modular) | 384 Bytes |
| **HAWK Signature Vector ($s_1$)** | 512 | 10 bits | 512 (Biased $[-512, 511]$) | 640 Bytes |
| **HAWK Public Key (Matrix $Q$)** | 512 | 14 bits | 8192 (Biased $[-8192, 8191]$) | 896 Bytes |

---

## 5. Zero-State Host-Driven Memory Isolation

To enforce multi-tenant isolation inside warm edge serverless environments, version 6.0-V2 completely strips internal static arena allocations and global variables from the WebAssembly linear memory space. All functions execute as stateless mathematical transformations over a host-provided runtime scratchpad context.

---

## 6. Hardening & Production Assembly Strategy

* **Absolute Multi-Tenancy Safety:** Zero persistence within WebAssembly global state bounds prevents cross-request timing leakage, memory cross-contamination, or warm-container state extraction attacks.
* **Constant-Time Execution Invariant:** Non-interrupted SIMD register tracking combined with fixed-iteration loops eliminates variable execution paths. Conditional selections are compiled down to native `v128.select` assembly structures, neutralizing side-channel analysis vectors.
* **Asset Footprint Optimization:** The entire core code path compiles to a freestanding, zero-polyfill WebAssembly binary under **41 KB**, embedded natively as a Base64 payload block inside a zero-dependency, type-safe TypeScript wrapper layer (`wasm_binary.ts`).
