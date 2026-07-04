import { WASM_BASE64 } from './wasm_binary';

function base64ToUint8Array(base64: string): Uint8Array {
    if (typeof Buffer !== 'undefined') {
        return Buffer.from(base64, 'base64');
    }
    const binaryString = atob(base64);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes;
}

export class Poly16Duo {
    private instance!: WebAssembly.Instance;
    private memory!: WebAssembly.Memory;

    private constructor(instance: WebAssembly.Instance, memory: WebAssembly.Memory) {
        this.instance = instance;
        this.memory = memory;
    }

    public static async load(): Promise<Poly16Duo> {
        const wasmBytes = base64ToUint8Array(WASM_BASE64);
        const module = await WebAssembly.compile(wasmBytes);
        const instance = await WebAssembly.instantiate(module, {});
        const memory = instance.exports.memory as WebAssembly.Memory;
        return new Poly16Duo(instance, memory);
    }

    public verifyHawkStateless(
        publicKey: Uint8Array,
        signature: Uint8Array,
        msg: Uint8Array
    ): boolean {
        if (publicKey.length !== 896) {
            throw new Error(`Invalid public key length: expected 896, got ${publicKey.length}`);
        }
        if (signature.length !== 640) {
            throw new Error(`Invalid signature length: expected 640, got ${signature.length}`);
        }

        const exports = this.instance.exports as any;
        const verify_hawk_stateless = exports.verify_hawk_stateless;

        // Allocate buffers inside the WASM linear memory
        const heap = new Uint8Array(this.memory.buffer);
        
        // Offset mapping:
        // Offset 0: public key (896 bytes)
        // Offset 896: signature (640 bytes)
        // Offset 1536: message (msg.length bytes)
        // Offset 1536 + msg.length: scratchpad (16384 bytes)
        const pkOffset = 0;
        const sigOffset = pkOffset + publicKey.length;
        const msgOffset = sigOffset + signature.length;
        const scratchpadOffset = msgOffset + msg.length;

        // Ensure WASM memory has enough pages
        const totalRequiredBytes = scratchpadOffset + 16384;
        const requiredPages = Math.ceil(totalRequiredBytes / 65536);
        const currentPages = heap.length / 65536;
        if (requiredPages > currentPages) {
            this.memory.grow(requiredPages - currentPages);
        }

        const freshHeap = new Uint8Array(this.memory.buffer);
        freshHeap.set(publicKey, pkOffset);
        freshHeap.set(signature, sigOffset);
        freshHeap.set(msg, msgOffset);
        
        // Zero-fill scratchpad area
        freshHeap.fill(0, scratchpadOffset, scratchpadOffset + 16384);

        const result = verify_hawk_stateless(
            pkOffset,
            sigOffset,
            msgOffset,
            msg.length,
            scratchpadOffset
        );

        return result === 1 || result === true;
    }
}
