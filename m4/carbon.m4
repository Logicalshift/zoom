dnl Detect the presence of Apple's Carbon API

AC_DEFUN(CARBON_DETECT, [
   AC_CACHE_CHECK([for Carbon], carbon_present, [
     AC_TRY_COMPILE([
	#include <Carbon/Carbon.h>
	], [ WindowRef w; SetWTitle(0, ""); ],
	[
	  carbon_old_LDFLAGS="$LDFLAGS"
	  LDFLAGS="$LDFLAGS -framework Carbon"
	  AC_TRY_LINK([
	    #include <Carbon/Carbon.h>
	    ], [  WindowRef w; SetWTitle(0, ""); ],
	    [ carbon_present=yes ],
	    [ carbon_present=no
	      LDFLAGS="$carbon_old_LD_FLAGS" ])
	],
	carbon_present=no)
     ])

   if test "x$carbon_present" = "xyes"; then
     LDFLAGS="$LDFLAGS -framework Carbon"
   fi
])
