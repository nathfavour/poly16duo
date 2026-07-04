const fs = require('fs');
const path = require('path');

async function testWasm() {
    const wasmPath = path.join(__dirname, '../zig-out/wasm/poly16duo.wasm');
    const wasmBuffer = fs.readFileSync(wasmPath);
    const { instance } = await WebAssembly.instantiate(wasmBuffer, {});
    
    console.log("WASM compiled and instantiated successfully!");
    console.log("Exported functions:", Object.keys(instance.exports));
    
    const verify = instance.exports.verify_hawk_stateless;
    if (typeof verify !== 'function') {
        throw new Error("verify_hawk_stateless is not exported or is not a function!");
    }
    
    const memory = instance.exports.memory;
    const heap = new Uint8Array(memory.buffer);
    
    const pk = new Uint8Array(896).fill(0x42);
    const sig = new Uint8Array(640).fill(0x11);
    const msg = new TextEncoder().encode("test message");
    
    const pkOffset = 0;
    const sigOffset = pkOffset + pk.length;
    const msgOffset = sigOffset + sig.length;
    const scratchpadOffset = msgOffset + msg.length;
    
    heap.set(pk, pkOffset);
    heap.set(sig, sigOffset);
    heap.set(msg, msgOffset);
    heap.fill(0, scratchpadOffset, scratchpadOffset + 16384);
    
    const result = verify(pkOffset, sigOffset, msgOffset, msg.length, scratchpadOffset);
    console.log("Verification result on dummy data (expected 0/false):", result);
    if (result !== 0 && result !== false) {
        throw new Error("Verification succeeded unexpectedly on dummy data!");
    }
    console.log("Integration test PASSED successfully!");
}

testWasm().catch(err => {
    console.error("Integration test FAILED:", err);
    process.exit(1);
});
