@echo on
setlocal enabledelayedexpansion

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

@REM Set pkg-config path so that host deps can be found
set "PKG_CONFIG_PATH=%LIBRARY_LIB%\pkgconfig;%LIBRARY_PREFIX%\share\pkgconfig;%BUILD_PREFIX%\Library\lib\pkgconfig"

@REM MSVC does not support `__attribute__((weak))`
@REM Remove when libvips 8.19 is released (it builds with -Dfuzz=false by default)
sed -i "/subdir('fuzz')/d" meson.build
if %ERRORLEVEL% neq 0 exit /b 1

@REM MSVC does not define ssize_t; replace with la_ssize_t from libarchive
@REM Remove when libvips 8.18.3 is released
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
for /d %%d in (%LIBRARY_LIB%\vips-modules-*) do (
    del /f /q "%%d\*.lib"
)
if %ERRORLEVEL% neq 0 exit /b 1
