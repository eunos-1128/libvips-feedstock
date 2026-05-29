@echo on
setlocal enabledelayedexpansion

@REM Override `MESON_ARGS` to drop `--pkg-config-path` (broken quoting on Windows); rely on `PKG_CONFIG_PATH` instead
set "MESON_ARGS=-Dbuildtype=release --prefix=%PREFIX%\Library -Dlibdir=lib -Ddefault_library=shared"

@REM `magick=disabled`: no Windows package available on conda-forge
@REM `introspection=disabled`: g-ir-scanner fails to link libarchive dependencies on Windows (Unix lib names: bz2, lz4, etc.)
set meson_config_args=^
    -Dauto_features=enabled ^
    -Dcgif=disabled ^
    -Dimagequant=disabled ^
    -Dmatio=disabled ^
    -Dnifti=disabled ^
    -Dopenexr=disabled ^
    -Dpdfium=disabled ^
    -Dquantizr=disabled ^
    -Duhdr=disabled ^
    -Dmagick=disabled ^
    -Dintrospection=disabled

@REM lcms2 on Windows (conda-forge) does not ship lcms2.pc; create a shim
for /f %%i in ('python -c "import json,glob; files=[f for f in glob.glob(r\"%PREFIX%\conda-meta\lcms2-*.json\") if f.split(chr(92))[-1].startswith(\"lcms2-\")]; print(json.load(open(files[0]))[\"version\"])"') do set LCMS2_VER=%%i
set "LIB_PREFIX=%PREFIX:\=/%/Library"
(
    echo prefix=%LIB_PREFIX%
    echo libdir=%LIB_PREFIX%/lib
    echo includedir=%LIB_PREFIX%/include
    echo.
    echo Name: lcms2
    echo Version: %LCMS2_VER%
    echo Description: Little CMS color management library
    echo Libs: -L%LIB_PREFIX%/lib -llcms2
    echo Cflags: -I%LIB_PREFIX%/include
) > "%BUILD_PREFIX%\Library\lib\pkgconfig\lcms2.pc"
if %ERRORLEVEL% neq 0 exit /b 1

@REM libheif.pc on Windows pulls in -lstdc++ via Requires.private (de265, x265)
@REM overwrite with a minimal shim that omits it
for /f %%i in ('python -c "import json,glob; files=[f for f in glob.glob(r\"%PREFIX%\conda-meta\libheif-*.json\") if __import__(\"os\").path.basename(f).startswith(\"libheif-\")]; print(json.load(open(files[0]))[\"version\"])"') do set LIBHEIF_VER=%%i
(
    echo prefix=%LIB_PREFIX%
    echo libdir=%LIB_PREFIX%/lib
    echo includedir=%LIB_PREFIX%/include
    echo.
    echo Name: libheif
    echo Version: %LIBHEIF_VER%
    echo Description: HEIF image codec
    echo Libs: -L%LIB_PREFIX%/lib -lheif
    echo Cflags: -I%LIB_PREFIX%/include
) > "%PREFIX%\Library\lib\pkgconfig\libheif.pc"
if %ERRORLEVEL% neq 0 exit /b 1

set "PKG_CONFIG_PATH=%PREFIX%\Library\lib\pkgconfig;%PREFIX%\Library\share\pkgconfig;%BUILD_PREFIX%\Library\lib\pkgconfig"

@REM MSVC does not support `__attribute__((weak))`
@REM Remove when libvips 8.19 is released (it builds with -Dfuzz=false by default)
sed -i "/subdir('fuzz')/d" meson.build
if %ERRORLEVEL% neq 0 exit /b 1

@REM MSVC does not define ssize_t; replace with la_ssize_t from libarchive
sed -i "s/^static ssize_t$/static la_ssize_t/" %SRC_DIR%/libvips/foreign/archive.c
if %ERRORLEVEL% neq 0 exit /b 1

meson setup build %MESON_ARGS% %meson_config_args%
if %ERRORLEVEL% neq 0 exit /b 1

meson compile -C build -j %CPU_COUNT%
if %ERRORLEVEL% neq 0 exit /b 1

@REM skip meson test on Windows (tests use sh scripts not available on Windows)
meson install -C build
if %ERRORLEVEL% neq 0 exit /b 1

@REM Remove .lib files from module directory
@REM (Windows: meson installs import libraries alongside DLLs, but modules are loaded dynamically, not linked)
for /d %%d in (%PREFIX%\Library\lib\vips-modules-*) do (
    del /f /q "%%d\*.lib"
)
if %ERRORLEVEL% neq 0 exit /b 1
