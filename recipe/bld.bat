@echo on
setlocal enabledelayedexpansion

@REM `introspection=disabled`: g-ir-scanner fails to link libarchive dependencies on Windows (Unix lib names: bz2, lz4, etc.)
@REM
@REM -Dc_args workaround for ImageMagick headers built with autotools/clang:
@REM   The installed magick-config.h sets MAGICKCORE_HAVE___ATTRIBUTE__=1,
@REM   causing method-attribute.h to emit raw __attribute__(...) and
@REM   magick_restrict to expand to __restrict__ -- both GCC/Clang-only syntax
@REM   that MSVC (cl.exe) does not understand.
@REM   /DMAGICKCORE_WINDOWS_SUPPORT redirects method-attribute.h to the
@REM   MSVC-safe branch where these macros become no-ops.
@REM   /Dssize_t=ptrdiff_t: ssize_t is POSIX-only, not defined in the MSVC SDK.
@REM   NOTE: CL and CFLAGS env vars are not reliably propagated to meson compile;
@REM   -Dc_args is the official Meson way to pass per-compiler flags.
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
    -Dintrospection=disabled ^
    -Dc_args="/DMAGICKCORE_WINDOWS_SUPPORT /Dssize_t=ptrdiff_t"

@REM Set pkg-config path so that host deps can be found
set "PKG_CONFIG_PATH=%LIBRARY_LIB%\pkgconfig;%LIBRARY_PREFIX%\share\pkgconfig;%BUILD_PREFIX%\Library\lib\pkgconfig"

@REM MSVC does not support `__attribute__((weak))`
@REM Remove when libvips 8.19 is released (it builds with -Dfuzz=false by default)
sed -i "/subdir('fuzz')/d" meson.build
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
