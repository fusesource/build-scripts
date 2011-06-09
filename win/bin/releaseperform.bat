@echo off

setlocal

set basedir=%~dp0
set basedir=%basedir:\=/%
set altGitURL=scm:git:file://%basedir%

set CMD=mvn -P release release:perform -Drelease-altGitURL=%altGitURL%
echo "Executing: %CMD%"
%CMD%
