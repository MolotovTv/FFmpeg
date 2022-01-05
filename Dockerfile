FROM debian:buster-slim as builder

WORKDIR /tmp

# Arg
ARG \
    AOM_VERSION=v3.2.0 \
    CUDA_TOOLKIT_VERSION=11-1 \
    FDKAAC_VERSION=v2.0.2 \
    FFMPEG_VERSION=release/5.0 \
    FREETYPE_VERSION=VER-2-11-1 \
    FONTCONFIG_VERSION=2.13.1-2 \
    FRIDIBI_VERSION=v1.0.11 \
    GETTEXT_VERSION=0.21 \
    HARFBUZZ_VERSION=3.2.0 \
    LAME_VERSION=3.100 \
    LIBASS_VERSION=0.15.2 \
    LIBFREI0R_VERSION=v1.7.0 \
    LIBOPENCORE_AMR_VERSION=0.1.5 \
    LIBTHEORA_VERSION=1.1.1+dfsg.1-15 \
    LIBVDPAU_VERSION=1.4 \
    LIBVMAF_VERSION=v2.3.0 \
    LIBVORBIS_VERSION=1.3.7 \
    LIBVPX_VERSION=v1.11.0 \
    LIBWEBP_VERSION=v1.2.0 \
    MESON_VERSION=0.55.0 \
    NV_CODER_HEADER_VERSION=n11.0.10.0 \
    OPENH264_VERSION=v2.1.1 \
    OPENJPEG_VERSION=v2.4.0 \
    OPUS_VERSION=1.3.1 \
    RUBBERBAND_VERSION=v1.9.2 \
    SOXR_VERSION=0.1.3 \
    SPEEX_VERSION=1.2.0 \
    SRT_VERSION=v1.4.4 \
    VID_STAB_VERSION=v1.1.0 \
    VO_AMRWBENC_VERSION=v0.1.3 \
    X264_VERSION=stable \
    X265_VERSION=3.5 \
    XVIDCORE_VERSION=1.3.7 \
    ZIMG_VERSION=release-3.0.2 \
    ZVBI_VERSION=v0.2.35 \
    DEBIAN_FRONTEND=noninteractive

# Env
ENV \
    PATH=/usr/local/cuda/bin:$PATH \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/:/usr/local/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH \
    LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

# Apt
RUN \
    apt update

# Cuda repos
RUN \
    apt -y install gnupg2 software-properties-common && \
    apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/debian10/x86_64/7fa2af80.pub && \
    add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/debian10/x86_64/ /" && \
    apt update

# Install deps, cuda...
RUN \
    apt -y install \
        autoconf \
        autopoint \
        cmake \
        cuda-toolkit-${CUDA_TOOLKIT_VERSION} \
        curl \
        gettext \
        git \
        libfontconfig1-dev=${FONTCONFIG_VERSION} \
        liblz-dev \
        liblzma-dev \
        libssl-dev \
        libtheora-dev=${LIBTHEORA_VERSION} \
        libtool \
        libtool-bin \
        libx11-dev \
        libxml2-dev \
        nasm \
        ninja-build \
        pkg-config \
        python3-pip \
        wget \
        yasm \
        zlib1g-dev && \
    pip3 install meson==${MESON_VERSION}

# Install ffmpeg nv-codec-headers
RUN \
    git clone --depth 1 --branch ${NV_CODER_HEADER_VERSION} https://github.com/FFmpeg/nv-codec-headers.git && \
    cd nv-codec-headers && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf nv-codec-headers

# Install x264
RUN \
    git clone --depth 1 --branch ${X264_VERSION} https://code.videolan.org/videolan/x264.git && \
    cd x264 && \
    ./configure --enable-static --enable-pic && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf x264

# Install x265
RUN \
    git clone --depth 1 --branch ${X265_VERSION} https://bitbucket.org/multicoreware/x265_git && \
    cd x265_git/build/linux && \
    cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release ../../source && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf x265_git

# Install fdk-aac
RUN \
    git clone --depth 1 --branch ${FDKAAC_VERSION} https://github.com/mstorsjo/fdk-aac && \
    cd fdk-aac && \
    autoreconf -fiv && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf fdk-aac

# Install lame
RUN \
    curl -O -L https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz && \
    tar xzvf lame-${LAME_VERSION}.tar.gz && \
    cd lame-${LAME_VERSION} && \
    ./configure --enable-nasm --enable-pic && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf lame-${LAME_VERSION} lame-${LAME_VERSION}.tar.gz

# Install opus
RUN \
    curl -O -L https://archive.mozilla.org/pub/opus/opus-${OPUS_VERSION}.tar.gz && \
    tar xzvf opus-${OPUS_VERSION}.tar.gz && \
    cd opus-${OPUS_VERSION} && \
    ./configure --enable-pic && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf opus-${OPUS_VERSION} opus-${OPUS_VERSION}.tar.gz

# Install libvpx
RUN \
    git clone --depth 1 --branch ${LIBVPX_VERSION} https://chromium.googlesource.com/webm/libvpx.git && \
    cd libvpx && \
    ./configure --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm --enable-pic && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf libvpx

# Install frei0r
RUN \
    git clone --depth 1 --branch ${LIBFREI0R_VERSION} https://github.com/dyne/frei0r.git && \
    mkdir -p frei0r/build && \
    cd frei0r/build && \
    cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf frei0r

# Install vmaf
RUN \
    git clone --depth 1 --branch ${LIBVMAF_VERSION} https://github.com/Netflix/vmaf.git && \
    cd vmaf/libvmaf && \
    meson build --buildtype release -Denable_asm=false -Denable_tests=false && \
    ninja -j$(nproc) -vC build && \
    ninja -vC build install && \
    cd /tmp && \
    rm -rf vmaf

# Install aom
RUN \
    git clone --depth 1 --branch ${AOM_VERSION} https://aomedia.googlesource.com/aom && \
    mkdir -p aom/aom_build && \
    cd aom/aom_build && \
    cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCONFIG_TUNE_VMAF=1 -DENABLE_NASM=on .. && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf aom

# Install libopencore-arm
RUN \
    wget https://freefr.dl.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-${LIBOPENCORE_AMR_VERSION}.tar.gz && \
    tar xvf opencore-amr-${LIBOPENCORE_AMR_VERSION}.tar.gz && \
    cd opencore-amr-${LIBOPENCORE_AMR_VERSION} && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf opencore-amr-${LIBOPENCORE_AMR_VERSION} opencore-amr-${LIBOPENCORE_AMR_VERSION}.tar.gz

# Install openh264
RUN \
    git clone --depth 1 --branch ${OPENH264_VERSION} https://github.com/cisco/openh264.git && \
    cd openh264 && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf openh264

# Install openjpeg
RUN \
    git clone --depth 1 --branch ${OPENJPEG_VERSION} https://github.com/uclouvain/openjpeg.git && \
    mkdir -p openjpeg/build && \
    cd openjpeg/build && \
    cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf openjpeg

# Install rubberband
RUN \
    git clone --depth 1 --branch ${RUBBERBAND_VERSION} https://github.com/breakfastquay/rubberband.git && \
    cd rubberband && \
    meson build && \
    ninja -j$(nproc) -vC build && \
    ninja -vC build install && \
    cd /tmp && \
    rm -rf rubberband

# Install soxr
RUN \
    git clone --depth 1 --branch ${SOXR_VERSION} https://github.com/chirlu/soxr.git && \
    mkdir -p soxr/build && \
    cd soxr/build && \
    cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf soxr

# Install speex
RUN \
    wget http://downloads.us.xiph.org/releases/speex/speex-${SPEEX_VERSION}.tar.gz && \
    tar xvf speex-${SPEEX_VERSION}.tar.gz && \
    cd speex-${SPEEX_VERSION} && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf speex-${SPEEX_VERSION} speex-${SPEEX_VERSION}.tar.gz

# Install vidstab
RUN \
    git clone --depth 1 --branch ${VID_STAB_VERSION} https://github.com/georgmartius/vid.stab.git && \
    mkdir -p vid.stab/build && \
    cd vid.stab/build && \
    cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf vid.stab

# Install fribidi
RUN \
    git clone --depth 1 --branch ${FRIDIBI_VERSION} https://github.com/fribidi/fribidi.git && \
    cd fribidi && \
    meson -Ddocs=false build && \
    ninja -j$(nproc) -vC build && \
    ninja -vC build install && \
    cd /tmp && \
    rm -rf fribidi

# Install vo-amrwbenc
RUN \
    git clone --depth 1 --branch ${VO_AMRWBENC_VERSION} https://github.com/mstorsjo/vo-amrwbenc.git && \
    cd vo-amrwbenc && \
    autoreconf -i && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf vo-amrwbenc

# Install libvorbis
RUN \
    wget http://downloads.xiph.org/releases/vorbis/libvorbis-${LIBVORBIS_VERSION}.tar.xz && \
    tar xvf libvorbis-${LIBVORBIS_VERSION}.tar.xz && \
    cd libvorbis-${LIBVORBIS_VERSION} && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf libvorbis-${LIBVORBIS_VERSION} libvorbis-${LIBVORBIS_VERSION}.tar.xz

# Install libwebp
RUN \
    git clone --depth 1 --branch ${LIBWEBP_VERSION} https://chromium.googlesource.com/webm/libwebp && \
    mkdir -p libwebp/build && \
    cd libwebp/build && \
    cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON .. && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf libwebp

# Install xvidcore
RUN \
    wget https://downloads.xvid.com/downloads/xvidcore-${XVIDCORE_VERSION}.tar.gz && \
    tar xvf xvidcore-${XVIDCORE_VERSION}.tar.gz && \
    cd xvidcore/build/generic && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf xvidcore xvidcore-${XVIDCORE_VERSION}.tar.gz

# Install zimg
RUN \
    git clone --depth 1 --branch ${ZIMG_VERSION} https://github.com/sekrit-twc/zimg.git && \
    cd zimg && \
    autoreconf -i && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf zimg

# Install libvdpau
RUN \
    git clone --depth 1 --branch ${LIBVDPAU_VERSION} https://gitlab.freedesktop.org/vdpau/libvdpau.git && \
    cd libvdpau && \
    meson build && \
    ninja -j$(nproc) -vC build && \
    ninja -vC build install && \
    cd /tmp && \
    rm -rf libvdpau

# Install gettext
RUN \
    wget http://ftp.gnu.org/pub/gnu/gettext/gettext-${GETTEXT_VERSION}.tar.xz && \
    tar xvf gettext-${GETTEXT_VERSION}.tar.xz && \
    cd gettext-${GETTEXT_VERSION} && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf gettext-${GETTEXT_VERSION} gettext-${GETTEXT_VERSION}.tar.xz

# Install zvbi
RUN \
    git clone --depth 1 --branch ${ZVBI_VERSION} git://git.opendreambox.org/git/zvbi.git && \
    cd zvbi && \
    autoreconf -i && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf zvbi

# Install freetype
RUN \
    git clone --depth 1 --branch ${FREETYPE_VERSION} https://gitlab.freedesktop.org/freetype/freetype.git && \
    cd freetype && \
    meson build && \
    ninja -j$(nproc) -vC build && \
    ninja -vC build install && \
    cd /tmp && \
    rm -rf freetype

# Install harfbuzz
RUN \
    git clone --depth 1 --branch ${HARFBUZZ_VERSION} https://github.com/harfbuzz/harfbuzz.git && \
    cd harfbuzz && \
    meson build && \
    ninja -j$(nproc) -vC build && \
    ninja -vC build install && \
    cd /tmp && \
    rm -rf harfbuzz

# Install libass
RUN \
    git clone --depth 1 --branch ${LIBASS_VERSION} https://github.com/libass/libass.git && \
    cd libass && \
    ./autogen.sh && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf libass

# Install srt
RUN \
    git clone --depth 1 --branch ${SRT_VERSION} https://github.com/Haivision/srt.git && \
    mkdir -p srt/build && \
    cd srt/build && \
    cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON .. && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf srt

# Install ffmpeg
RUN \
    git clone --depth 1 --branch ${FFMPEG_VERSION} https://github.com/MolotovTv/ffmpeg.git && \
    cd ffmpeg && \
    #nvenc
    sed -i 's/compute_30/compute_60/' configure && \
    sed -i 's/sm_30/sm_60/' configure && \
    ./configure \
        --disable-debug \
        --disable-doc \
        --disable-ffplay \
        --disable-static \
        --disable-w32threads \
        --enable-cuda-nvcc \
        --enable-cuvid \
        --enable-ffnvcodec \
        --enable-fontconfig \
        --enable-frei0r \
        --enable-gpl \
        --enable-gray \
        --enable-libaom \
        --enable-libass \
        --enable-libfdk_aac \
        --enable-libfreetype \
        --enable-libfribidi \
        --enable-libmp3lame \
        --enable-libnpp \
        --enable-libopencore-amrnb \
        --enable-libopencore-amrwb \
        --enable-libopenh264 \
        --enable-libopenjpeg \
        --enable-libopus \
        --enable-librubberband \
        --enable-libsoxr \
        --enable-libsrt \
        --enable-libspeex \
        --enable-libtheora \
        --enable-libvidstab \
        --enable-libvmaf \
        --enable-libvo-amrwbenc \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libwebp \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libxml2 \
        --enable-libxvid \
        --enable-libzimg \
        --enable-libzvbi \
        --enable-nonfree \
        --enable-openssl \
        --enable-pthreads \
        --enable-shared \
        --enable-vdpau \
        --enable-version3 \
        --enable-zlib \
        --extra-cflags=-I/usr/local/cuda/include \
        --extra-ldflags=-L/usr/local/cuda/lib64 \
        --extra-libs="-lpthread -lm -lz" \
        --pkg-config-flags="--static" && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf ffmpeg

# Prepare export
RUN \
    rm -rf /build && \
    mkdir -p /build/libs-to-export && \
    mkdir -p /build/bins-to-export && \
    ldd /usr/local/bin/ffmpeg | grep -Eo '/[^ ]+' | grep -Ev 'libdl.so|librt.so|libpthread.so|libstdc\\+\\+.so|libm.so|libgcc_s.so|libc.so|ld-linux-x86-64.so' | sort -u | xargs cp -p -t /build/libs-to-export/  && \
    ldd /build/libs-to-export/* | grep -Eo '/[^ ]+' | grep -Ev '/build/libs-to-export/|libdl.so|librt.so|libpthread.so|libstdc\\+\\+.so|libm.so|libgcc_s.so|libc.so|ld-linux-x86-64.so' | sort -u | xargs cp -p -t /build/libs-to-export/ && \
    strip /build/libs-to-export/* && \
    cp /usr/local/bin/ffmpeg /usr/local/bin/ffprobe /build/bins-to-export && \
    strip /build/bins-to-export/*

# Final image
FROM debian:buster-slim

COPY --from=builder /build/libs-to-export /opt/ffmpeg/lib
COPY --from=builder /build/bins-to-export /opt/ffmpeg/bin

RUN \
    for lib in /opt/ffmpeg/lib/*.so.*; do ln -s "${lib##*/}" "${lib%%.so.*}".so; done

ENV LD_LIBRARY_PATH=/opt/ffmpeg/lib

ENTRYPOINT ["/opt/ffmpeg/bin/ffmpeg"]
