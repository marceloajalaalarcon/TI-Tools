@echo off
:: Batch Script para Iniciar as Ferramentas de T.I. com Permissões de Admin
:: Resolve problemas de codificacao e permissoes

REM Força o console para UTF-8 para evitar erros com caracteres especiais se houver
chcp 65001 >nul

REM Verifica se está rodando como admin
NET SESSION >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    GOTO :RunPS
) ELSE (
    echo Solicitando permissoes de administrador...
    GOTO :Elevate
)

:Elevate
PROMPT $P$G
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
"%temp%\getadmin.vbs"
DEL "%temp%\getadmin.vbs"
exit /B

:RunPS
REM Executa o script PowerShell ignorando a política de execução
echo Iniciando Ferramentas...
pushd "%~dp0"
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "avancadoFerramentas.ps1"
popd

echo.
echo Se o script fechou inesperadamente, tente executar este .bat como Administrador.
pause
