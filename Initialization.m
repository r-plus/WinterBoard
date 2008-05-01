#import <Foundation/Foundation.h>
#include <objc/runtime.h>

#define WBPrefix "wb_"

void WBRename(const char *classname, const char *oldname) {
    Class class = objc_getClass(classname);
    size_t namelen = strlen(oldname);
    char newname[sizeof(WBPrefix) + namelen];
    memcpy(newname, WBPrefix, sizeof(WBPrefix) - 1);
    memcpy(newname + sizeof(WBPrefix) - 1, oldname, namelen + 1);
    Method method = class_getInstanceMethod(class, sel_getUid(oldname));
    if (!class_addMethod(class, sel_registerName(newname), method->method_imp, method->method_types))
        NSLog(@"WB: failed to rename %s::%s", classname, oldname);
}

void WBInitialize() {
    if (NSClassFromString(@"SpringBoard") == nil)
        return;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSLog(@"WB: changing season");

    WBRename("SBBluetoothController", "noteDevicesChanged");

    NSBundle *bundle = [NSBundle bundleWithPath:@"/System/Library/Frameworks/WinterBoard.framework"];
    if (bundle == nil)
        NSLog(@"WB: there is no Santa :(");
    else if (![bundle load])
        NSLog(@"WB: sleigh was too heavy");

    [pool release];
}
