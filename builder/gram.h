typedef union {
  int   number;
  char* string;
  enum optype optype;

  operation* op;
  opflags    flags;
} YYSTYPE;
#define	OPCODE	257
#define	NUMBER	258
#define	STRING	259
#define	OPTYPE	260
#define	VERSION	261
#define	BRANCH	262
#define	CANJUMP	263
#define	STORE	264
#define	STRINGFLAG	265
#define	LONG	266
#define	ARGS	267
#define	REALLYVAR	268
#define	ALL	269


extern YYSTYPE yylval;
