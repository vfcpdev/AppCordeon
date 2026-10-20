@echo off
echo =========================================================================
echo Compilando Motor DSP Acordeon Vallenato a WebAssembly (WASM) y Test Bench
echo =========================================================================

where cargo >nul 2>nul
if %errorlevel% neq 0 (
    echo [AVISO] Rust/Cargo no esta instalado directamente en el PATH de Windows.
    echo Para compilar localmente:
    echo 1. Instala Rust desde https://rustup.rs o con: winget install Rustlang.Rustup
    echo 2. Agrega el target wasm32: rustup target add wasm32-unknown-unknown
    echo 3. Instala wasm-pack: cargo install wasm-pack
    echo 4. Vuelve a ejecutar este script.
    exit /b 1
)

echo [1/2] Compilando y ejecutando Test Bench Acustico de Evaluacion...
cargo run --release

echo.
echo [2/2] Compilando a WebAssembly para navegador (AudioWorklet)...
wasm-pack build --target web --out-dir ../../src/audio/accordion_dsp_wasm --release

echo.
echo Proceso finalizado.
