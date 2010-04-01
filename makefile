ifndef PKG_TARG
target :=
else
target := $(PKG_TARG)-
endif

substrate := -I../mobilesubstrate -L../mobilesubstrate -lsubstrate

all: WinterBoard WinterBoard.dylib UIImages WinterBoardSettings Optimize

clean:
	rm -f WinterBoard WinterBoard.dylib UIImages

WinterBoardSettings: Settings.mm makefile
	$(target)g++ -dynamiclib -g0 -O2 -Wall -o $@ $(filter %.mm,$^) -framework UIKit -framework CoreFoundation -framework Foundation -lobjc -framework CoreGraphics -framework Preferences -F$(PKG_ROOT)/System/Library/PrivateFrameworks
	ldid -S $@

WinterBoard.dylib: Library.mm makefile ../mobilesubstrate/substrate.h
	$(target)g++ -dynamiclib -g0 -O2 -Wall -o $@ $(filter %.mm,$^) -framework CoreFoundation -framework Foundation -lobjc -init _WBInitialize -I/apl/inc/iPhoneOS-2.0 -framework CoreGraphics -framework GraphicsServices -framework Celestial $(substrate) -framework UIKit -F$(PKG_ROOT)/System/Library/PrivateFrameworks
	ldid -S $@

UIImages: UIImages.mm makefile
	$(target)g++ -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework UIKit -framework Foundation -framework CoreFoundation -lobjc -I/apl/inc/iPhoneOS-2.0 $(substrate)
	ldid -S $@

WinterBoard: Application.mm makefile
	$(target)g++ -g0 -O2 -Wall -Werror -o $@ $(filter %.mm,$^) -framework UIKit -framework Foundation -framework CoreFoundation -lobjc -framework CoreGraphics -I/apl/sdk -framework Preferences -F$(PKG_ROOT)/System/Library/PrivateFrameworks
	ldid -S $@

Optimize: Optimize.cpp makefile
	$(target)g++ -g0 -O2 -Wall -Werror -o $@ $(filter %.cpp,$^)
	ldid -S $@

package: all
	rm -rf winterboard
	mkdir -p winterboard/DEBIAN
	mkdir -p winterboard/Applications/WinterBoard.app
	mkdir -p winterboard/Library/Themes
	mkdir -p winterboard/Library/MobileSubstrate/DynamicLibraries
	mkdir -p winterboard/Library/PreferenceLoader/Preferences
	mkdir -p winterboard/System/Library/PreferenceBundles
	mkdir -p winterboard/usr/libexec/winterboard
	cp -a Optimize winterboard/usr/libexec/winterboard
	chmod 6755 winterboard/usr/libexec/winterboard/Optimize
	cp -a WinterBoardSettings.plist winterboard/Library/PreferenceLoader/Preferences
	cp -a WinterBoardSettings.bundle winterboard/System/Library/PreferenceBundles
	cp -a Icon-Small.png winterboard/System/Library/PreferenceBundles/WinterBoardSettings.bundle/icon.png
	cp -a SearchResultsCheckmarkClear.png WinterBoardSettings winterboard/System/Library/PreferenceBundles/WinterBoardSettings.bundle
	ln -s /Applications/WinterBoard.app/WinterBoard.dylib winterboard/Library/MobileSubstrate/DynamicLibraries
	cp -a WinterBoard.plist winterboard/Library/MobileSubstrate/DynamicLibraries
	cp -a *.theme winterboard/Library/Themes
	find winterboard -name .svn | while read -r line; do rm -rf "$${line}"; done
	cp -a control preinst prerm winterboard/DEBIAN
	cp -a Test.sh Icon-Small.png icon.png WinterBoard.dylib WinterBoard UIImages Info.plist winterboard/Applications/WinterBoard.app
	dpkg-deb -b winterboard winterboard_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb

.PHONY: all clean package
