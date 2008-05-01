ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

all: WinterBoard WinterBoard.dylib

clean:
	rm -f WinterBoard.dylib

WinterBoard: *.mm makefile
	$(target)gcc -fobjc-call-cxx-cdtors -bundle -g3 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework CoreFoundation -framework Foundation -framework UIKit -lobjc -fobjc-exceptions -flat_namespace -undefined suppress -I../uicaboodle.m

WinterBoard.dylib: Initialization.m makefile
	$(target)gcc -dynamiclib -g3 -O2 -Wall -Werror -o $@ $(filter %.m,$^) -framework CoreFoundation -framework Foundation -lobjc -init _WBInitialize

.PHONY: all clean
