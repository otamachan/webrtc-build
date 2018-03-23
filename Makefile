WEBRTCDIR:=webrtc
FETCH_OPTION:=
TYPE:=Debug
VERSION:=66
TAGET_CPU:=x86_64
SRCDIR:=$(WEBRTCDIR)/src
TARGET:=out/$(TAGET_CPU)/$(TYPE)
OUTDIR:=$(SRCDIR)/$(TARGET)
OBJDIR:=$(SRCDIR)/$(TARGET)/obj
DESTDIR:=/usr

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

GNARGSCOMMON:=is_clang=false rtc_include_tests=false use_custom_libcxx=false treat_warnings_as_errors=false rtc_use_h264=true ffmpeg_branding="Chrome"

all: libwebrtc

depot_tools/gclient:
	git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git

$(SRCDIR)/DEPS: depot_tools/gclient
	mkdir -p $(WEBRTCDIR)
	cd $(WEBRTCDIR) && fetch --nohooks webrtc
	cd $(SRCDIR) && git checkout branch-heads/$(VERSION)
	sed -i -e "s|'src/resources'],|'src/resources'],'condition':'rtc_include_tests==true',|" $(SRCDIR)/DEPS
	cd $(SRCDIR) && gclient sync --with_branch_heads

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
addlib $(OBJDIR)/libwebrtc_common.a
save
end
endef
export AR_SCRIPT

$(OBJDIR)/$(LIBNAME).a: $(OUTDIR)/build.ninja
	cd $(SRCDIR) && ninja -C $(TARGET) webrtc rtc_json jsoncpp
	echo "$$AR_SCRIPT" > /tmp/$(LIBNAME).mri
	ar -M < /tmp/$(LIBNAME).mri
	rm /tmp/$(LIBNAME).mri
	ar rcs $@ $(addprefix $(OBJDIR)/,$(addsuffix .o,$(OBJS)))
	ranlib $@

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
	    grep -E 'third_party/(boringssl|expat/files|jsoncpp|libjpeg|libjpeg_turbo|libsrtp|libyuv|libvpx|opus|protobuf|usrsctp/usrsctpout/usrsctpout)' | \
	    grep -v /third_party | \
	    xargs -I '{}' install -D '{}' '$(DESTDIR)/include/webrtc$(INSTALL_SUFFIX)/{}'
