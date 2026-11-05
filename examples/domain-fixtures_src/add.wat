;; Minimal WASM module for inspect-wasm-artifact (wabt wat2wasm)
(module
  (func $add (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add)
  (memory $mem (export "mem") 1)
  (global $counter (export "counter") (mut i32) (i32.const 0))
)
