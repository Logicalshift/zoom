#!/bin/bash

echo $0 $1 $2 Building interpreter...

if [ "x$1" = "xclean" ]; then
    if [ -e build/interp_gen.h ]; then
        rm build/interp_gen.h
    fi
    
    for i in {3,4,5,6}; do
        if [ -e build/interp_z${i}.h ]; then
            rm build/interp_z${i}.h
        fi
    done
    
    if [ -e build/varop.h ]; then
        rm build/varop.h
    fi
else
    if [ ./src/zcode.ops -nt build/interp_gen.h ]; then
        echo interp_gen.h
        ./build/builder build/interp_gen.h -1 ./src/zcode.ops
    fi
    
    for i in {3,4,5,6}; do
        if [ ./src/zcode.ops -nt build/interp_z${i}.h ]; then
            echo interp_z${i}.h
            ./build/builder build/interp_z${i}.h $i ./src/zcode.ops
        fi
    done
    
    if [ ./builder/varopdecode.pl -nt build/varop.h ]; then
        echo varop.h
        perl ./builder/varopdecode.pl 4 varop >build/varop.h
    fi
fi