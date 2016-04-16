# Don't edit Makefile! Use conf-* for configuration.

SHELL=/bin/sh

default: it

clean:
	rm -f *.a *.o cdbgetall cdbgetall.exe

buffer.a: \
makelib strerr_sys.o buffer.o buffer_put.o buffer_2.o strerr_die.o \
buffer_get.o buffer_copy.o buffer_1.o buffer_0.o buffer_1s.o
	./makelib buffer.a strerr_sys.o buffer.o buffer_put.o \
	buffer_2.o strerr_die.o buffer_get.o buffer_copy.o \
	buffer_1.o buffer_0.o buffer_1s.o

buffer.o: \
compile buffer.c buffer.h
	./compile buffer.c

buffer_0.o: \
compile buffer_0.c readwrite.h buffer.h
	./compile buffer_0.c

buffer_1.o: \
compile buffer_1.c readwrite.h buffer.h
	./compile buffer_1.c

buffer_1s.o: \
compile buffer_1s.c readwrite.h buffer.h
	./compile buffer_1s.c

buffer_2.o: \
compile buffer_2.c readwrite.h buffer.h
	./compile buffer_2.c

buffer_copy.o: \
compile buffer_copy.c buffer.h
	./compile buffer_copy.c

buffer_get.o: \
compile buffer_get.c buffer.h byte.h error.h
	./compile buffer_get.c

buffer_put.o: \
compile buffer_put.c buffer.h str.h byte.h error.h
	./compile buffer_put.c

byte.a: \
makelib byte_copy.o byte_cr.o str_len.o fmt_ulong.o uint32_unpack.o \
byte_diff.o uint32_pack.o
	./makelib byte.a byte_copy.o byte_cr.o str_len.o \
	fmt_ulong.o uint32_unpack.o byte_diff.o uint32_pack.o \

byte_copy.o: \
compile byte_copy.c byte.h
	./compile byte_copy.c

byte_cr.o: \
compile byte_cr.c byte.h
	./compile byte_cr.c

byte_diff.o: \
compile byte_diff.c byte.h
	./compile byte_diff.c

cdb.a: \
makelib cdb.o cdb_hash.o cdb_make.o
	./makelib cdb.a cdb.o cdb_hash.o cdb_make.o

cdb.o: \
compile cdb.c readwrite.h error.h seek.h byte.h cdb.h uint32.h
	./compile cdb.c

cdb_hash.o: \
compile cdb_hash.c cdb.h uint32.h
	./compile cdb_hash.c

cdb_make.o: \
compile cdb_make.c readwrite.h seek.h error.h cdb.h uint32.h \
cdb_make.h buffer.h uint32.h
	./compile cdb_make.c

cdbgetall: \
load cdbgetall.o cdb.a buffer.a unix.a byte.a
	./load cdbgetall cdb.a buffer.a unix.a byte.a

cdbgetall.o: \
compile cdbgetall.c exit.h str.h buffer.h strerr.h cdb.h uint32.h
	./compile cdbgetall.c

compile: \
warn-auto.sh conf-cc
	( cat warn-auto.sh; \
	echo exec "`head -1 conf-cc`" '-c $${1+"$$@"}' \
	) > compile
	chmod 755 compile

error.o: \
compile error.c error.h
	./compile error.c

error_str.o: \
compile error_str.c error.h
	./compile error_str.c

fmt_ulong.o: \
compile fmt_ulong.c fmt.h
	./compile fmt_ulong.c

it: prog

load: \
warn-auto.sh conf-ld
	( cat warn-auto.sh; \
	echo 'main="$$1"; shift'; \
	echo exec "`head -1 conf-ld`" \
	'-o "$$main" "$$main".o $${1+"$$@"}' \
	) > load
	chmod 755 load

makelib: \
warn-auto.sh systype
	( cat warn-auto.sh; \
	echo 'main="$$1"; shift'; \
	echo 'rm -f "$$main"'; \
	echo 'ar cr "$$main" $${1+"$$@"}'; \
	case "`cat systype`" in \
	sunos-5.*) ;; \
	unix_sv*) ;; \
	irix64-*) ;; \
	irix-*) ;; \
	dgux-*) ;; \
	hp-ux-*) ;; \
	sco*) ;; \
	*) echo 'ranlib "$$main"' ;; \
	esac \
	) > makelib
	chmod 755 makelib

open_read.o: \
compile open_read.c open.h
	./compile open_read.c

open_trunc.o: \
compile open_trunc.c open.h
	./compile open_trunc.c

prog: cdbgetall

seek_cur.o: \
compile seek_cur.c seek.h
	./compile seek_cur.c

seek_set.o: \
compile seek_set.c seek.h
	./compile seek_set.c

str_len.o: \
compile str_len.c str.h
	./compile str_len.c

strerr_die.o: \
compile strerr_die.c buffer.h exit.h strerr.h
	./compile strerr_die.c

strerr_sys.o: \
compile strerr_sys.c error.h strerr.h
	./compile strerr_sys.c

systype: \
find-systype.sh conf-cc conf-ld trycpp.c x86cpuid.c
	( cat warn-auto.sh; \
	echo CC=\'`head -1 conf-cc`\'; \
	echo LD=\'`head -1 conf-ld`\'; \
	cat find-systype.sh; \
	) | sh > systype

uint32.h: \
tryulong32.c compile load uint32.h1 uint32.h2
	( ( ./compile tryulong32.c && ./load tryulong32 && \
	./tryulong32 ) >/dev/null 2>&1 \
	&& cat uint32.h2 || cat uint32.h1 ) > uint32.h
	rm -f tryulong32.o tryulong32

uint32_pack.o: \
compile uint32_pack.c uint32.h
	./compile uint32_pack.c

uint32_unpack.o: \
compile uint32_unpack.c uint32.h
	./compile uint32_unpack.c

unix.a: \
makelib error.o open_read.o open_trunc.o error_str.o seek_set.o \
seek_cur.o
	./makelib unix.a error.o open_read.o open_trunc.o \
	error_str.o seek_set.o seek_cur.o
