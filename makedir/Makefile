EXE=ios-deploy
OBJS=common.o errors.o ios-deploy.o script.o checksign.o
INC+=-I../ios-deploy  -I../ios-deploy
LIBS=-lc++  -lz -framework Foundation -F/System/Library/PrivateFrameworks -framework MobileDevice
CM_FLAGS=-ffunction-sections -fdata-sections -g -fno-rtti -DVERSIONSTR=\"$(shell git describe --all --long  --abbrev=12 --dirty)\"
CC=xcrun --sdk macosx clang

vpath %.mm ../ios-deploy
vpath %.m  ../ios-deploy

CFLAGS+=$(MACROS) $(INC) $(CM_FLAGS)
CXXFLAGS+=$(MACROS) $(INC) $(CM_FLAGS) -std=c++11
LDFLAGS+=$(LIBS)

all:$(EXE)

../ios-deploy/lldb.py.h : ../scripts/ios_lldb.py
	echo "const unsigned char script_py[] = {" > $@
	cat $^ | gzip -9  | xxd -i  >> $@
	echo "};" >> $@

script.o:../ios-deploy/lldb.py.h

%.o:%.mm
	$(CC) $(CXXFLAGS) -c $<

$(EXE):$(OBJS)
	$(CC) -g -o $@.dbg $^ $(LDFLAGS)
	cp $@.dbg $@
	strip $@

clean:
	rm -f *.o .*.un~ $(EXE) $(EXE).dbg

install:$(EXE)
	cp $(EXE) ~/bin/
