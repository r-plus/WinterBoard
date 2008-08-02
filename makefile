ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

all: WinterBoard.dylib

clean:
	rm -f WinterBoard.dylib

WinterBoard.dylib: WinterBoard.mm makefile
	$(target)g++ -dynamiclib -g3 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework CoreFoundation -framework Foundation -lobjc -init _WBInitialize -I/apl/inc/iPhoneOS-2.0 -framework UIKit

.PHONY: all clean
