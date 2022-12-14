#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# bleat on references to undefined shell variables
set -u

MINIZLIB_SOURCE_DIR="minizip-ng"

top="$(pwd)"
stage="$top"/stage

[ -f "$stage"/packages/include/zlib-ng/zlib.h ] || \
{ echo "You haven't yet run 'autobuild install'." 1>&2; exit 1; }

# load autobuild provided shell functions and variables
case "$AUTOBUILD_PLATFORM" in
    windows*)
        autobuild="$(cygpath -u "$AUTOBUILD")"
    ;;
    *)
        autobuild="$AUTOBUILD"
    ;;
esac
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

VERSION_HEADER_FILE="$MINIZLIB_SOURCE_DIR/mz.h"
version=$(sed -n -E 's/#define MZ_VERSION[ ]+[(]"([0-9.]+)"[)]/\1/p' "${VERSION_HEADER_FILE}")
build=${AUTOBUILD_BUILD_ID:=0}
echo "${version}.${build}" > "${stage}/VERSION.txt"

pushd "$MINIZLIB_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        # ------------------------ windows, windows64 ------------------------
        windows*)
            load_vsvars

            cmake -G "$AUTOBUILD_WIN_CMAKE_GEN" . \
                  -DBUILD_SHARED_LIBS=OFF \
                  -DMZ_COMPAT=ON \
                  -DMZ_BUILD_TEST=ON \
                  -DMZ_FETCH_LIBS=OFF\
                  -DMZ_BZIP2=OFF \
                  -DMZ_LIBBSD=OFF \
                  -DMZ_LZMA=OFF \
                  -DMZ_OPENSSL=OFF \
                  -DMZ_PKCRYPT=OFF \
                  -DMZ_SIGNING=OFF \
                  -DMZ_WZAES=OFF \
                  -DZLIB_INCLUDE_DIRS="$(cygpath -m $stage)/packages/include/zlib-ng/" \
                  -DZLIB_LIBRARIES="$(cygpath -m $stage)/packages/lib/release/zlib.lib"


            cmake --build . --config Release

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                ctest -C Release
            fi

            mkdir -p "$stage/lib/release"
            cp -a "Release/libminizip.lib" "$stage/lib/release/"

            mkdir -p "$stage/include/minizip-ng"
            cp -a *.h "$stage/include/minizip-ng"
        ;;

        # ------------------------- darwin, darwin64 -------------------------
        darwin*)

            opts="${TARGET_OPTS:--arch $AUTOBUILD_CONFIGURE_ARCH $LL_BUILD_RELEASE}"

            mkdir -p "$stage/lib/release"
            rm -rf Resources/ ../Resources tests/Resources/

            cmake ../${MINIZLIB_SOURCE_DIR} -GXcode \
                  -DCMAKE_C_FLAGS:STRING="$opts" \
                  -DCMAKE_CXX_FLAGS:STRING="$opts" \
                  -DBUILD_SHARED_LIBS=OFF \
                  -DMZ_COMPAT=ON \
                  -DMZ_BUILD_TEST=ON \
                  -DMZ_FETCH_LIBS=OFF \
                  -DMZ_BZIP2=OFF \
                  -DMZ_LIBBSD=OFF \
                  -DMZ_LZMA=OFF \
                  -DMZ_OPENSSL=OFF \
                  -DMZ_PKCRYPT=OFF \
                  -DMZ_SIGNING=OFF \
                  -DMZ_WZAES=OFF \
                  -DMZ_LIBCOMP=OFF \
                  -DCMAKE_INSTALL_PREFIX=$stage \
                  -DZLIB_INCLUDE_DIRS="$(cygpath -m $stage)/packages/include/zlib-ng/" \
                  -DZLIB_LIBRARIES="$(cygpath -m $stage)/packages/lib/release/libz.a"

            cmake --build . --config Release

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                ctest -C Release
            fi

            mkdir -p "$stage/lib/release"
            cp -a Release/libminizip*.a* "${stage}/lib/release/"

            mkdir -p "$stage/include/minizip-ng"
            cp -a *.h "$stage/include/minizip-ng"
        ;;            

        # -------------------------- linux, linux64 --------------------------
        linux*)
			# Prefer out of source builds
			rm -rf build
			mkdir -p build
			pushd build
	    
            # Default target per autobuild build --address-size
            opts="${TARGET_OPTS:-${AUTOBUILD_GCC_ARCH} $LL_BUILD_RELEASE}"

            # Handle any deliberate platform targeting
            if [ ! "${TARGET_CPPFLAGS:-}" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            cmake ${top}/${MINIZLIB_SOURCE_DIR} -G"Unix Makefiles" \
                  -DCMAKE_C_FLAGS:STRING="$opts" \
                  -DCMAKE_CXX_FLAGS:STRING="$opts" \
                  -DBUILD_SHARED_LIBS=OFF \
                  -DMZ_COMPAT=ON \
                  -DMZ_BUILD_TEST=ON \
                  -DMZ_FETCH_LIBS=OFF \
                  -DMZ_BZIP2=OFF \
                  -DMZ_LIBBSD=OFF \
                  -DMZ_LZMA=OFF \
                  -DMZ_OPENSSL=OFF \
                  -DMZ_PKCRYPT=OFF \
                  -DMZ_SIGNING=OFF \
                  -DMZ_WZAES=OFF \
				  -DMZ_ZSTD=OFF \
                  -DCMAKE_INSTALL_PREFIX=$stage \
                  -DZLIB_INCLUDE_DIRS="$stage/packages/include/zlib-ng/" \
                  -DZLIB_LIBRARIES="$stage/packages/lib/release/libz.a"

            cmake --build . --parallel 8  --config Release

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" -eq 0 ]; then
                ctest -C Release
            fi

            mkdir -p "$stage/lib/release"
            cp -a libminizip*.a* "${stage}/lib/release/"

            mkdir -p "$stage/include/minizip-ng"
            cp -a ${top}/${MINIZLIB_SOURCE_DIR}/*.h "$stage/include/minizip-ng"

	    popd
        ;;
    esac

    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/minizip-ng.txt"
popd

mkdir -p "$stage"/docs/minizip-ng/
cp -a README.Linden "$stage"/docs/minizip-ng/
