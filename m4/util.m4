AC_DEFUN(UTIL_CHECK_CFLAG,
  [
    AC_MSG_CHECKING([if the C compiler ($CC) supports -$1])
    ac_OLD_CFLAGS="$CFLAGS"
    CFLAGS="$CFLAGS -$1"
    AC_TRY_LINK([], [ { int x; x = 1; } ],
      AC_MSG_RESULT(yes),
      AC_MSG_RESULT(no)
      CFLAGS="$ac_OLD_CFLAGS")
  ])
