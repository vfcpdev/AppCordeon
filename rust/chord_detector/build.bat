@echo off
echo =====================================================================
echo Compilando Motor de Deteccion de Acordes en Rust a WebAssembly (WASM)
echo =====================================================================

where wasm-pack >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: wasm-pack no esta instalado o no se encuentra en PATH.
    echo Instala Rust y wasm-pack ejecutando:
    echo   winget install Rustlang.Rustup
    echo   cargo install wasm-pack
    exit /b 1
)

echo Compilando target web hacia src/audio/wasm_pkg...
wasm-pack build --target web --out-dir ../../src/audio/wasm_pkg --release

if %errorlevel% equ 0 (
    echo.
    echo [EXITO] WebAssembly compilado correctamente en src/audio/wasm_pkg/
) else (
    echo.
    echo [ERROR] Fallo la compilacion de WebAssembly.
)
