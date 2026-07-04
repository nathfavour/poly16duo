# poly16duo Development Roadmap

This document outlines the milestones and roadmap for `poly16duo` v6.0.

## Phase 1: MVP Hardening (Completed)
- [x] Implement comptime static polymorphism for modular NTT vs Exact 64-bit integer convolution domains.
- [x] Write branchless, pure-SIMD serialization engines (`pack10`/`pack12`/`pack14`) to prevent vector-to-stack spills.
- [x] Create a strictly stateless export boundary for multi-tenant isolation.
- [x] Enable freestanding compilation under `wasm32-freestanding` yielding $<10$ KB footprints.

## Phase 2: Web Integration & Tooling (Current)
- [ ] Build a script to generate the inline Base64 TypeScript wrapper `wasm_binary.ts`.
- [ ] Create type-safe JS/TS wrappers to handle allocation of the host-provided 16KB execution scratchpads.
- [ ] Set up benchmark suites comparing scalar vs vector runtime performance.

## Phase 3: Hardening & Auditing
- [ ] Perform side-channel analysis and verify constant-time execution on x86_64, aarch64, and Wasm runtimes.
- [ ] Audit the BLAKE3 context separation matrix against known lattice-reduction attack bounds.
- [ ] Integrate fuzz testing for out-of-bound edge cases in splicing engines.
