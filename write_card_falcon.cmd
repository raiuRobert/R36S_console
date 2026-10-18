@echo off
rem Writes the falcon-mode goodluckOS card image to the SD card in the PC reader (disk 3).
rem   write_card_falcon.cmd      panel 1 image (try this first)
rem   write_card_falcon.cmd 2    panel 2 image (if panel 1 gives a lit but blank screen)
rem Only the 4 MiB chunks that differ are rewritten, then verified. Approve the UAC prompt and
rem type 3 again when asked. Result log: firmware\goodluckos\<image>.flash.log
set IMG=ga36_a23_panel1_falcon.img
if "%1"=="2" set IMG=ga36_a23_panel2_falcon.img
echo Writing %IMG% to disk 3 ...
powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath 'C:\msys64\mingw64\bin\python.exe' -WorkingDirectory 'D:\dev\R36s_console' -ArgumentList '-I','D:\dev\R36s_console\tools\flash_sd.py','D:\dev\R36s_console\firmware\goodluckos\%IMG%','3','sync'"
