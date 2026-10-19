mod types;
mod parser;

use wasm_bindgen::prelude::*;
use crate::types::MelodyReport;
use crate::parser::parse_musicxml_melody;

#[wasm_bindgen]
pub fn is_melody_wasm_ready() -> bool {
    true
}

#[wasm_bindgen]
pub fn get_melody_engine_info() -> String {
    "Rust WebAssembly Melody Extractor v1.0.0 (SIMD/Native)".to_string()
}

#[wasm_bindgen]
pub fn extract_melody_from_musicxml(xml: &str) -> Result<JsValue, JsValue> {
    let report: MelodyReport = parse_musicxml_melody(xml);
    serde_wasm_bindgen::to_value(&report).map_err(|e| JsValue::from_str(&e.to_string()))
}
