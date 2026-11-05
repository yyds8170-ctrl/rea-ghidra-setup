;; Second WASM fixture: different exported interface for compare-wasm-interfaces
(module
  (func $sub (export "sub") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.sub)
  (memory $mem (export "mem") 1)
)
