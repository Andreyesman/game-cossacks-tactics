@echo off
setlocal EnableDelayedExpansion

:: Set colors and title
color 0A
title Font Downloader for Godot

echo ================================
echo    Font Downloader for Godot
echo ================================
echo.
echo This script will:
echo  1. Check your Windows Fonts directory for required fonts
echo  2. Copy found fonts to a local 'fonts' directory
echo  3. Attempt to download missing fonts from Google Fonts
echo.
echo Required fonts:
echo  - Inter Regular
echo.
echo Press any key to begin...
pause > nul

:: Create fonts directory if it doesn't exist
if not exist "fonts" mkdir "fonts"

echo Checking for required fonts...
echo.


echo Checking for Inter Regular...

:: Check Windows Fonts directory
if exist "%WINDIR%\Fonts\Inter-Regular.ttf" (
    echo Found in system fonts - copying...
    copy "%WINDIR%\Fonts\Inter-Regular.ttf" "fonts\Inter-Regular.ttf" > nul
    echo Copied successfully.
) else (
    echo Not found in system fonts - attempting download from Google Fonts...
    powershell -Command "&{$webClient=New-Object System.Net.WebClient; $webClient.Headers.Add('User-Agent', 'Mozilla/5.0'); $cssUrl='https://fonts.googleapis.com/css2?family=Inter:wght@400'; $css=$webClient.DownloadString($cssUrl); if($css -match 'src: url\((.*?)\)'){$fontUrl=$matches[1]; $webClient.DownloadFile($fontUrl, 'fonts\Inter-Regular.ttf')}}"
    if exist "fonts\Inter-Regular.ttf" (
        echo Downloaded successfully.
    ) else (
        echo Failed to download. Please download manually from: https://fonts.google.com/specimen/Inter
    )
)
echo.

echo.
echo All operations completed!
echo Font files have been saved to the 'fonts' directory.
echo.
pause
