@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT_DIR=%~dp0.."
set "SCRIPT_DIR=%~dp0"
set "ENV_FILE=%SCRIPT_DIR%db.env"
set "BACKUP_DIR=%ROOT_DIR%\backups"

if exist "%ENV_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
        if not "%%~A"=="" (
            if /i not "%%~A"=="rem" (
                if /i not "%%~A:~0,1"=="#" set "%%~A=%%~B"
            )
        )
    )
)

if "%PGHOST%"=="" set "PGHOST=localhost"
if "%PGPORT%"=="" set "PGPORT=5432"
if "%PGUSER%"=="" set "PGUSER=postgres"
if "%PGDATABASE%"=="" set "PGDATABASE=postgres"
if "%PROJECT_DB%"=="" set "PROJECT_DB=saas_analysis"

if "%~1"=="" goto :usage

set "ACTION=%~1"

if /i "%ACTION%"=="initdb" goto :initdb
if /i "%ACTION%"=="setup" goto :setup
if /i "%ACTION%"=="validate" goto :validate
if /i "%ACTION%"=="query" goto :query
if /i "%ACTION%"=="all" goto :all
if /i "%ACTION%"=="backup" goto :backup
if /i "%ACTION%"=="restore" goto :restore
if /i "%ACTION%"=="dropdb" goto :dropdb
if /i "%ACTION%"=="help" goto :usage

echo [error] Unknown action: %ACTION%
goto :usage

:initdb
echo [initdb] Ensuring database "%PROJECT_DB%" exists...
psql -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" -d "%PGDATABASE%" -tAc "SELECT 1 FROM pg_database WHERE datname='%PROJECT_DB%'" | findstr /r /c:"1" >nul
if %errorlevel%==0 (
    echo [initdb] Database already exists.
    exit /b 0
)

createdb -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" "%PROJECT_DB%"
if errorlevel 1 (
    echo [error] Failed to create database "%PROJECT_DB%".
    exit /b 1
)

echo [initdb] Database created.
exit /b 0

:setup
call :initdb
if errorlevel 1 exit /b 1

echo [setup] Running master_setup.sql on "%PROJECT_DB%"...
psql -v ON_ERROR_STOP=1 -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" -d "%PROJECT_DB%" -f "%SCRIPT_DIR%master_setup.sql"
if errorlevel 1 (
    echo [error] Setup failed.
    exit /b 1
)

echo [setup] Completed.
exit /b 0

:validate
echo [validate] Running validation scripts on "%PROJECT_DB%"...
psql -v ON_ERROR_STOP=1 -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" -d "%PROJECT_DB%" -f "%SCRIPT_DIR%master_validate.sql"
if errorlevel 1 (
    echo [error] Validation failed.
    exit /b 1
)

echo [validate] Completed.
exit /b 0

:query
echo [query] Running profitability query on "%PROJECT_DB%"...
psql -v ON_ERROR_STOP=1 -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" -d "%PROJECT_DB%" -f "%ROOT_DIR%\queries\01_current_profitability.sql"
if errorlevel 1 (
    echo [error] Query execution failed.
    exit /b 1
)

echo [query] Completed.
exit /b 0

:all
call :setup
if errorlevel 1 exit /b 1

call :validate
if errorlevel 1 exit /b 1

echo [all] End-to-end run completed.
exit /b 0

:backup
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%i"
set "DB_DUMP_FILE=%BACKUP_DIR%\%PROJECT_DB%_%STAMP%.dump"
set "GLOBALS_FILE=%BACKUP_DIR%\globals_%STAMP%.sql"

echo [backup] Creating database dump: "%DB_DUMP_FILE%"
pg_dump -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" -d "%PROJECT_DB%" -Fc -f "%DB_DUMP_FILE%"
if errorlevel 1 (
    echo [error] Database backup failed.
    exit /b 1
)

echo [backup] Creating cluster globals backup: "%GLOBALS_FILE%"
pg_dumpall -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" --globals-only > "%GLOBALS_FILE%"
if errorlevel 1 (
    echo [error] Globals backup failed.
    exit /b 1
)

echo [backup] Completed successfully.
exit /b 0

:restore
if "%~2"=="" (
    echo [error] Missing dump file path.
    echo Example: run_all.bat restore backups\saas_analysis_20260423_163000.dump
    exit /b 1
)

set "DUMP_FILE=%~2"
if not exist "%DUMP_FILE%" (
    set "DUMP_FILE=%ROOT_DIR%\%~2"
)
if not exist "%DUMP_FILE%" (
    echo [error] Dump file not found: %~2
    exit /b 1
)

echo [restore] Recreating "%PROJECT_DB%"...
dropdb --if-exists -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" "%PROJECT_DB%"
if errorlevel 1 (
    echo [error] Failed to drop database "%PROJECT_DB%".
    exit /b 1
)

createdb -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" "%PROJECT_DB%"
if errorlevel 1 (
    echo [error] Failed to create database "%PROJECT_DB%".
    exit /b 1
)

echo [restore] Restoring dump "%DUMP_FILE%"...
pg_restore -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" -d "%PROJECT_DB%" --clean --if-exists --no-owner --no-privileges "%DUMP_FILE%"
if errorlevel 1 (
    echo [error] Restore failed.
    exit /b 1
)

echo [restore] Completed successfully.
exit /b 0

:dropdb
echo [dropdb] Dropping "%PROJECT_DB%"...
dropdb --if-exists -h "%PGHOST%" -p "%PGPORT%" -U "%PGUSER%" "%PROJECT_DB%"
if errorlevel 1 (
    echo [error] Failed to drop database "%PROJECT_DB%".
    exit /b 1
)

echo [dropdb] Completed.
exit /b 0

:usage
echo Usage: run_all.bat [action]
echo.
echo Actions:
echo   initdb     Create target DB if missing
echo   setup      Run schema + seed scripts
echo   validate   Run data quality checks + main query
echo   query      Run main profitability query only
echo   all        Run setup + validate
echo   backup     Backup DB data + PostgreSQL globals to backups\
echo   restore    Restore DB from dump file path
echo   dropdb     Drop target DB
echo   help       Show this message

exit /b 1
