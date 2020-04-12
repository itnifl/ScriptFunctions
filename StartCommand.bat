@echo off
REM Atle Holm - September 2015
REM Version 1.0.0
set command=%1
set command=%command:~0,-1%
set command=%command:~1%
@echo @echo off > otherCommand.bat
@echo %command% >> otherCommand.bat
call otherCommand.bat
del otherCommand.bat