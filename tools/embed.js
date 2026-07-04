const fs = require('fs');
const path = require('path');

const wasmPath = path.join(__dirname, '../zig-out/wasm/poly16duo.wasm');
const outputPath = path.join(__dirname, '../src/wasm_binary.ts');

if (!fs.existsSync(wasmPath)) {
  console.error("Wasm file not found. Please run 'zig build' first.");
  process.exit(1);
}

const wasmBuffer = fs.readFileSync(wasmPath);
const base64Wasm = wasmBuffer.toString('base64');

const tsContent = `// This file is auto-generated. Do not edit manually.
export const WASM_BASE64 = "${base64Wasm}";
`;

fs.writeFileSync(outputPath, tsContent);
console.log(`Successfully embedded Wasm to ${outputPath}`);
