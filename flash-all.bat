@ECHO OFF
setlocal EnableDelayedExpansion
cd /d "%~dp0"

:: burnOS — Pixel 7 (panther) signed factory flash script
:: Requires signed release (burn/sign-release.sh) + avb_pkmd.bin in this folder.

set DEVICE=panther
set BUILD=2026062200
set MIN_FASTBOOT=350001
set BOOTLOADER=bootloader-panther-cloudripper-16.4-14540572.img
set RADIO=radio-panther-g5300q-251202-260127-B-14784800.img
set IMAGE=image-panther-%BUILD%.zip
set AVB_KEY=avb_pkmd.bin

PATH=%PATH%;"%SYSTEMROOT%\System32"

where /q fastboot
if %errorlevel% neq 0 (
  echo fastboot not found
  echo Install Android platform-tools and add fastboot to PATH.
  call:pakExit
)

for /f "tokens=3" %%a in ('fastboot --version ^| find "fastboot version "') do (
  set ver_str=%%a
  set ver_num=!ver_str:.=!
  if not !ver_num! geq %MIN_FASTBOOT% (
    echo fastboot version ^(!ver_str!^) is older than 35.0.1
    call:pakExit
  )
)

for /f "tokens=2" %%a in ('fastboot getvar product 2^>^&1 ^| findstr /i /c:"product:"') do set "product=%%a"
if /i not "%product%"=="%DEVICE%" (
  echo Wrong device: expected %DEVICE%, got %product%
  call:pakExit
)

if not exist "%BOOTLOADER%" ( echo Missing %BOOTLOADER% & call:pakExit )
if not exist "%RADIO%" ( echo Missing %RADIO% & call:pakExit )
if not exist "%IMAGE%" ( echo Missing %IMAGE% & call:pakExit )
if not exist "%AVB_KEY%" (
  echo Missing %AVB_KEY% — run sign-release.sh and generate-flash-bundle.sh first
  call:pakExit
)

echo Flashing signed burnOS %DEVICE% build %BUILD% ...
echo Do not unplug the device until this script finishes.

fastboot flash --slot=other bootloader %BOOTLOADER%
fastboot --set-active=other
fastboot reboot-bootloader
ping -n 5 127.0.0.1 >nul

fastboot flash --slot=other bootloader %BOOTLOADER%
fastboot --set-active=other
fastboot reboot-bootloader
ping -n 5 127.0.0.1 >nul

fastboot flash radio %RADIO%
fastboot reboot-bootloader
ping -n 5 127.0.0.1 >nul

fastboot -w --skip-reboot update %IMAGE%
fastboot reboot-bootloader
ping -n 5 127.0.0.1 >nul

echo Installing burnOS verified boot public key...
fastboot erase avb_custom_key
fastboot flash avb_custom_key %AVB_KEY%
fastboot reboot-bootloader
ping -n 5 127.0.0.1 >nul

echo.
echo Ready to lock. Run: fastboot flashing lock
echo Keep OEM unlocking ENABLED in Developer options after locking.
call:pakExit

:pakExit
echo Press any key to exit...
pause >nul
exit /b 0
