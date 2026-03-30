@echo off
color 0A
echo =========================================
echo      INICIANDO TERMO-CONVERSOR...
echo =========================================
echo.
echo Abriendo la pagina web en tu navegador...
start http://localhost:8080/index.html

echo.
echo Iniciando el motor de Prolog...
echo (NO CIERRES ESTA VENTANA NEGRA MIENTRAS USAS LA PAGINA)
echo.

swipl -s servidor.pl -g iniciar_servidor

pause