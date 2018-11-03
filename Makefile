WEBRTCDIR:=webrtc
FETCH_OPTION:=
TARGET_CPU:=x64
TYPE:=Debug
VERSION:=69
SRCDIR:=$(WEBRTCDIR)/src
TARGET:=out/$(TARGET_CPU)/$(TYPE)
OUTDIR:=$(SRCDIR)/$(TARGET)
OBJDIR:=$(SRCDIR)/$(TARGET)/obj
DESTDIR:=/usr
# https://bugs.chromium.org/p/webrtc/issues/detail?id=9528
PATCHES_FOR_69=06f66c72600e58438ba9caf9f523e00a519ef3c0 12912255424a293397270c7b50fb56e82ecad4ea

LIBNAME=libwebrtc_full$(INSTALL_SUFFIX)

export PATH:=$(PATH):$(shell pwd)/depot_tools

ifeq ($(TYPE),Debug)
GNARGS:=is_debug=true
INSTALL_SUFFIX:=_debug
DEBUG_OPT:=-D_GLIBCXX_DEBUG=1
else
GNARGS:=is_debug=false
INSTALL_SUFFIX:=
DEBUG_OPT:=
endif

ifeq ($(TARGET_CPU),x64)
AR=ar
RANLIB=ranlib
NM=nm
OBJCOPY=objcopy
else ifeq ($(TARGET_CPU),arm64)
AR=aarch64-linux-gnu-ar
RANLIB=aarch64-linux-gnu-ranlib
NM=aarch64-linux-gnu-nm
OBJCOPY=aarch64-linux-gnu-objcopy
endif

GNARGSCOMMON:=target_cpu="$(TARGET_CPU)" use_custom_libcxx=false rtc_include_tests=false treat_warnings_as_errors=false rtc_use_h264=true ffmpeg_branding="Chrome"

all: libwebrtc

depot_tools/gclient:
	git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git

$(SRCDIR)/DEPS: depot_tools/gclient
	mkdir -p $(WEBRTCDIR)
	cd $(WEBRTCDIR) && fetch --nohooks webrtc
	cd $(SRCDIR) && git checkout branch-heads/$(VERSION)
	git -C $(SRCDIR) config user.email "you@example.com"; git -C $(SRCDIR) config user.name "Your Name"
	PATCHES="$(PATCHES_FOR_$(VERSION))"; for p in $$PATCHES; do git -C $(SRCDIR) cherry-pick "$$p"; done  # apply patches
	sed -i -e "s|'src/resources'],|'src/resources'],'condition':'rtc_include_tests==true',|" $(SRCDIR)/DEPS
	cd $(SRCDIR) && gclient sync --with_branch_heads
	if [ "$(TARGET_CPU)" = "arm64" ]; then cd $(SRCDIR) && build/linux/sysroot_scripts/install-sysroot.py --arch=arm64 ;fi

$(OUTDIR)/build.ninja: $(SRCDIR)/DEPS
	cd $(SRCDIR) && gn gen $(TARGET) --args='$(GNARGSCOMMON) $(GNARGS)'

sync:
	sed -i -e "s|'src/resources'],|'src/resources'],'condition':'rtc_include_tests==true',|" $(SRCDIR)/DEPS
	cd $(SRCDIR) && gclient sync --with_branch_heads

gn:
	cd $(SRCDIR) && gn gen $(TARGET) --args='$(GNARGSCOMMON) $(GNARGS)'

dstclean:
	cd $(SRCDIR) && gn clean $(TARGET)

clean:
	rm -f $(OBJDIR)/$(LIBNAME).a

OBJS:=rtc_base/rtc_json/json third_party/jsoncpp/jsoncpp/json_reader third_party/jsoncpp/jsoncpp/json_writer third_party/jsoncpp/jsoncpp/json_value

libwebrtc: $(OBJDIR)/$(LIBNAME).a

define AR_SCRIPT
create $(OBJDIR)/$(LIBNAME).a
addlib $(OBJDIR)/libwebrtc.a
addlib $(OBJDIR)/api/video_codecs/libbuiltin_video_decoder_factory.a
addlib $(OBJDIR)/api/video_codecs/libbuiltin_video_encoder_factory.a
addlib $(OBJDIR)/pc/libpeerconnection.a
addlib $(OBJDIR)/pc/libcreate_pc_factory.a
addlib $(OBJDIR)/modules/congestion_controller/bbr/libbbr.a
save
end
endef
export AR_SCRIPT

$(OBJDIR)/$(LIBNAME).a: $(OUTDIR)/build.ninja
	cd $(SRCDIR) && ninja -C $(TARGET) webrtc rtc_json jsoncpp builtin_video_decoder_factory builtin_video_encoder_factory create_pc_factory peerconnection bbr
	echo "$$AR_SCRIPT" > /tmp/$(LIBNAME).mri
	$(AR) -M < /tmp/$(LIBNAME).mri
	rm /tmp/$(LIBNAME).mri
	$(AR) rcs $@ $(addprefix $(OBJDIR)/,$(addsuffix .o,$(OBJS)))
	$(RANLIB) $@
	$(NM) $@ | grep -E " [Td] av" | awk '{print $$3 " _" $$3}' > /tmp/ffmpeg.syms  # rename ffmpeg symbols to strip those symbols
	$(OBJCOPY) --redefine-syms /tmp/ffmpeg.syms $@

example: $(OUTDIR)/.dirstamp
	cd $(SRCDIR) && ninja -C $(TARGET) examples

install: $(OBJDIR)/$(LIBNAME).a
	install -d $(DESTDIR)/lib $(DESTDIR)/include $(DESTDIR)/include/webrtc$(INSTALL_SUFFIX)
	install $(OUTDIR)/obj/$(LIBNAME).a $(DESTDIR)/lib
	INSTALL_SUFFIX=$(INSTALL_SUFFIX) VERSION=$(VERSION) DEBUG_OPT=$(DEBUG_OPT) envsubst '$${INSTALL_SUFFIX} $${VERSION} $${DEBUG_OPT}' < libwebrtc.pc.in > $(DESTDIR)/lib/pkgconfig/libwebrtc$(INSTALL_SUFFIX).pc
	install -D $(SRCDIR)/*.h $(DESTDIR)/include/webrtc$(INSTALL_SUFFIX)
	cd $(SRCDIR) && for base in api call common_video logging rtc_base media modules p2p system_wrappers; do \
		find $$base -name '*.h' -exec install -D '{}' '$(DESTDIR)/include/webrtc$(INSTALL_SUFFIX)/{}' ';'; \
	done
	cd $(SRCDIR) && find third_party -name '*.h' -o -name README -o -name LICENSE -o -name COPYING | \
	    grep -E 'third_party/(abseil-cpp|boringssl|expat/files|jsoncpp|libjpeg|libjpeg_turbo|libsrtp|libyuv|libvpx|opus|protobuf|usrsctp/usrsctpout/usrsctpout)' | \
	    grep -v /third_party | \
	    xargs -I '{}' install -D '{}' '$(DESTDIR)/include/webrtc$(INSTALL_SUFFIX)/{}'
