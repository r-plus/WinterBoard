ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

all: WinterBoard WinterBoard.dylib UIImages

clean:
	rm -f WinterBoard WinterBoard.dylib UIImages

WinterBoard.dylib: Library.mm makefile
	$(target)g++ -dynamiclib -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework UIKit -framework CoreFoundation -framework Foundation -lobjc -init _WBInitialize -I/apl/inc/iPhoneOS-2.0 -framework CoreGraphics

UIImages: UIImages.mm makefile
	$(target)g++ -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework UIKit -framework Foundation -framework CoreFoundation -lobjc

WinterBoard: Application.mm makefile
	$(target)g++ -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework UIKit -framework Foundation -framework CoreFoundation -lobjc -framework CoreGraphics

package:
	rm -rf winterboard
	mkdir -p winterboard/DEBIAN
	mkdir -p winterboard/Applications/WinterBoard.app
	mkdir -p winterboard/Library/Themes
	cp -a Saurik winterboard/Library/Themes
	find winterboard/Library/Themes/Saurik -name .svn | while read -r line; do rm -rf "$${line}"; done
	cp -a control preinst postinst prerm winterboard/DEBIAN
	cp -a Test.sh icon.png WinterBoard.dylib WinterBoard UIImages Info.plist ../pledit/pledit winterboard/Applications/WinterBoard.app
	dpkg-deb -b winterboard winterboard_0.9.2506-1_iphoneos-arm.deb

.PHONY: all clean package
