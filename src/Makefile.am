bin_PROGRAMS = \
	zoom
pkgdata_DATA = zoomrc

EXTRA_DIST = zcode.ops zoomrc zoom.rc.in zoom.ico

zoom_SOURCES = \
	main.c interp.c file.c options.c zmachine.c zscii.c xdisplay.c \
	hash.c tokenise.c stream.c font3.c state.c pix.c rc.c rc_parse.y \
	rc_lex.l menu.c xfont.c windisplay.c winfont.c \
	\
	file.h zmachine.h options.h interp.h zscii.h display.h hash.h \
	tokenise.h stream.h font3.h state.h pix.h rc.h rcp.h rc_parse.h \
	menu.h xdisplay.h xfont.h zoomres.h windisplay.h

$(srcdir)/interp.c: interp_gen.h interp_z3.h interp_z4.h interp_z5.h interp_z6.h varop.h

WINDRES = @WINDRES@

if WINDOWS_VERSION
if BORLAND_VERSION
zoom: zoom.res $(zoom_OBJECTS)
	$(LINK) -aa c0w32 $(zoom_OBJECTS),zoom,,import32 cw32,,zoom.res
LDFLAGS=@LDFLAGS@ -link
else
LDFLAGS=@LDFLAGS@
zoom: zoom.o $(zoom_OBJECTS) $(zoom_DEPENDENCIES)
	@rm -f zoom
	$(LINK) $(zoom_LDFLAGS) $(zoom_OBJECTS) zoom.o $(zoom_LDADD) $(LIBS)
endif

%.o: %.rc
	$(WINDRES) -i $< -o $@

%.res: %.rc
	$(WINDRES) -fo$@ $<
else
LDFLAGS=@LDFLAGS@

zoom: $(zoom_OBJECTS) $(zoom_DEPENDENCIES)
	@rm -f zoom
	$(LINK) $(zoom_LDFLAGS) $(zoom_OBJECTS) $(zoom_LDADD) $(LIBS)
endif

CFLAGS = @CFLAGS@ @X_CFLAGS@ -DDATADIR="\"${pkgdatadir}\""
LIBS = @LIBS@ @X_PRE_LIBS@ @X_LIBS@ @X_EXTRA_LIBS@
YFLAGS = -d

varop.h: $(top_srcdir)/builder/varopdecode.pl
	 @PERL@ $(top_srcdir)/builder/varopdecode.pl 4 varop >varop.h
doubleop.h: $(top_srcdir)/builder/varopdecode.pl
	 @PERL@ $(top_srcdir)/builder/varopdecode.pl 8 doubleop >doubleop.h

interp_gen.h: zcode.ops $(top_builddir)/builder/builder
	     $(top_builddir)/builder/builder interp_gen.h -1 $(top_srcdir)/src/zcode.ops
interp_z3.h: zcode.ops $(top_builddir)/builder/builder
	     $(top_builddir)/builder/builder interp_z3.h 3 $(top_srcdir)/src/zcode.ops
interp_z4.h: zcode.ops $(top_builddir)/builder/builder
	     $(top_builddir)/builder/builder interp_z4.h 4 $(top_srcdir)/src/zcode.ops
interp_z5.h: zcode.ops $(top_builddir)/builder/builder
	     $(top_builddir)/builder/builder interp_z5.h 5 $(top_srcdir)/src/zcode.ops
interp_z6.h: zcode.ops $(top_builddir)/builder/builder
	     $(top_builddir)/builder/builder interp_z6.h 6 $(top_srcdir)/src/zcode.ops
