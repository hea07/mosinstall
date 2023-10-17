@echo off

for /f "tokens=2 delims==" %%a in ('wmic bios get serialnumber /value') do set serial=%%a

set output_file=%~dp0GUID_%serial%.txt

wmic bios get serialnumber >> %output_file%
wmic path win32_computersystemproduct get uuid >> %output_file%

echo [92mGUID and Serialnumber have been saved to %output_file%[0m