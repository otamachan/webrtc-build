WEBRTCDIR:=webrtc
FETCH_OPTION:=
TARGET_CPU:=x64
TYPE:=Release
VERSION:=4147
SRCDIR:=$(WEBRTCDIR)/src
TARGET:=out/$(TARGET_CPU)/$(TYPE)
OUTDIR:=$(SRCDIR)/$(TARGET)
OBJDIR:=$(SRCDIR)/$(TARGET)/obj
DESTDIR:=/usr
# https://bugs.chromium.org/p/webrtc/issues/detail?id=9528
PATCHES_FOR_69=06f66c72600e58438ba9caf9f523e00a519ef3c0 12912255424a293397270c7b50fb56e82ecad4ea
PATCHES_FOR_71=patches/support_more_formats.patch

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

ifeq ($(TARGET_CPU),arm64)
PREFIX=aarch64-linux-gnu-
else ifeq ($(TARGET_CPU),arm)
PREFIX=arm-linux-gnueabihf-
else ifeq ($(TARGET_CPU),x64)
PREFIX=
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
	PATCHES="$(PATCHES_FOR_$(VERSION))"; for p in $$PATCHES; do if expr "$$p" : ".*\.patch$$"; then patch -d $(SRCDIR) -p1 < $$p; else git -C $(SRCDIR) cherry-pick "$$p"; fi; done  # apply patches
	sed -i -e "s|'src/resources'],|'src/resources'],'condition':'rtc_include_tests==true',|" $(SRCDIR)/DEPS
	cd $(SRCDIR) && gclient sync --with_branch_heads
	if [ ! "$(TARGET_CPU)" = "x64" ]; then cd $(SRCDIR) && build/linux/sysroot_scripts/install-sysroot.py --arch=$(TARGET_CPU) ;fi

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

OBJS:=test/platform_video_capturer/vcm_capturer \
      test/video_test_common/test_video_capturer

define AR_SCRIPT
create $(OBJDIR)/$(LIBNAME).a
addmod $(addprefix $(OBJDIR)/,$(addsuffix .o,$(OBJS)))
addlib $(OBJDIR)/libwebrtc.a
save
end
endef
export AR_SCRIPT

libwebrtc: $(OBJDIR)/$(LIBNAME).a

lib: $(OBJDIR)/$(LIBNAME).a

$(OBJDIR)/$(LIBNAME).a: $(OUTDIR)/build.ninja
	cd $(SRCDIR) && ninja -C $(TARGET) webrtc examples
	echo "$$AR_SCRIPT" > /tmp/$(LIBNAME).mri
	$(PREFIX)ar -M < /tmp/$(LIBNAME).mri
	rm /tmp/$(LIBNAME).mri
#	$(PREFIX)nm $@ | grep -E " [Td] av" | awk '{print $$3 " _" $$3}' > /tmp/ffmpeg.syms  # rename ffmpeg symbols to strip those symbols
#	$(PREFIX)objcopy --redefine-syms /tmp/ffmpeg.syms $@

example: $(OUTDIR)/.dirstamp
	cd $(SRCDIR) && ninja -C $(TARGET) examples

install: lib
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
