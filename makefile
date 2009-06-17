ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

all: WinterBoard WinterBoard.dylib UIImages

clean:
	rm -f WinterBoard WinterBoard.dylib UIImages

WinterBoard.dylib: Library.mm makefile ../mobilesubstrate/substrate.h
	$(target)g++ -dynamiclib -g0 -O2 -Wall -o $@ $(filter %.mm,$^) -framework CoreFoundation -framework Foundation -lobjc -init _WBInitialize -I/apl/inc/iPhoneOS-2.0 -framework CoreGraphics -framework GraphicsServices -framework Celestial -I../mobilesubstrate -L../mobilesubstrate -lsubstrate -framework UIKit -F$(PKG_ROOT)/System/Library/PrivateFrameworks

UIImages: UIImages.mm makefile
	$(target)g++ -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework UIKit -framework Foundation -framework CoreFoundation -lobjc -I/apl/inc/iPhoneOS-2.0

WinterBoard: Application.mm makefile
	$(target)g++ -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework UIKit -framework Foundation -framework CoreFoundation -lobjc -framework CoreGraphics -I/apl/sdk

package:
	rm -rf winterboard
	mkdir -p winterboard/DEBIAN
	mkdir -p winterboard/Applications/WinterBoard.app
	mkdir -p winterboard/Library/Themes
	mkdir -p winterboard/Library/MobileSubstrate/DynamicLibraries
	ln -s /Applications/WinterBoard.app/WinterBoard.dylib winterboard/Library/MobileSubstrate/DynamicLibraries
	cp -a WinterBoard.plist winterboard/Library/MobileSubstrate/DynamicLibraries
	cp -a *.theme winterboard/Library/Themes
	find winterboard/Library/Themes -name .svn | while read -r line; do rm -rf "$${line}"; done
	cp -a control preinst prerm winterboard/DEBIAN
	cp -a Test.sh icon.png WinterBoard.dylib WinterBoard UIImages Info.plist winterboard/Applications/WinterBoard.app
	dpkg-deb -b winterboard winterboard_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb

.PHONY: all clean package
