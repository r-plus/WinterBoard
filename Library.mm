/* WinterBoard - Theme Manager for the iPhone
 * Copyright (C) 2008  Jay Freeman (saurik)
*/

/*
 *        Redistribution and use in source and binary
 * forms, with or without modification, are permitted
 * provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the
 *    above copyright notice, this list of conditions
 *    and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the
 *    above copyright notice, this list of conditions
 *    and the following disclaimer in the documentation
 *    and/or other materials provided with the
 *    distribution.
 * 3. The name of the author may not be used to endorse
 *    or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
 * BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 * TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#define _trace() NSLog(@"WB:_trace(%u)", __LINE__);

#include <objc/runtime.h>
#include <objc/message.h>

extern "C" {
    #include <mach-o/nlist.h>
}

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIImageView.h>
#import <UIKit/UINavigationBarBackground.h>

#import <UIKit/NSString-UIStringDrawing.h>
#import <UIKit/NSString-UIStringDrawingDeprecated.h>

#import <UIKit/UIImage-UIImageDeprecated.h>

#import <UIKit/UIView-Geometry.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIView-Rendering.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBAppWindow.h>
#import <SpringBoard/SBButtonBar.h>
#import <SpringBoard/SBContentLayer.h>
#import <SpringBoard/SBIconLabel.h>
#import <SpringBoard/SBStatusBarContentsView.h>
#import <SpringBoard/SBStatusBarTimeView.h>
#import <SpringBoard/SBUIController.h>

#import <CoreGraphics/CGGeometry.h>

@interface NSDictionary (WinterBoard)
- (UIColor *) colorForKey:(NSString *)key;
- (BOOL) boolForKey:(NSString *)key;
@end

@implementation NSDictionary (WinterBoard)

- (UIColor *) colorForKey:(NSString *)key {
    NSString *value = [self objectForKey:key];
    if (value == nil)
        return nil;
    /* XXX: incorrect */
    return nil;
}

- (BOOL) boolForKey:(NSString *)key {
    if (NSString *value = [self objectForKey:key])
        return [value boolValue];
    return NO;
}

@end

bool Debug_ = false;

/* WinterBoard Backend {{{ */
#define WBPrefix "wb_"

void WBInject(const char *classname, const char *oldname, IMP newimp, const char *type) {
    Class _class = objc_getClass(classname);
    if (_class == nil)
        return;
    if (!class_addMethod(_class, sel_registerName(oldname), newimp, type))
        NSLog(@"WB:Error: failed to inject [%s %s]", classname, oldname);
}

void WBRename(bool instance, const char *classname, const char *oldname, IMP newimp) {
    Class _class = objc_getClass(classname);
    if (_class == nil) {
        if (Debug_)
            NSLog(@"WB:Warning: cannot find class [%s]", classname);
        return;
    }
    if (!instance)
        _class = object_getClass(_class);
    Method method = class_getInstanceMethod(_class, sel_getUid(oldname));
    if (method == nil) {
        if (Debug_)
            NSLog(@"WB:Warning: cannot find method [%s %s]", classname, oldname);
        return;
    }
    size_t namelen = strlen(oldname);
    char newname[sizeof(WBPrefix) + namelen];
    memcpy(newname, WBPrefix, sizeof(WBPrefix) - 1);
    memcpy(newname + sizeof(WBPrefix) - 1, oldname, namelen + 1);
    const char *type = method_getTypeEncoding(method);
    if (!class_addMethod(_class, sel_registerName(newname), method_getImplementation(method), type))
        NSLog(@"WB:Error: failed to rename [%s %s]", classname, oldname);
    unsigned int count;
    Method *methods = class_copyMethodList(_class, &count);
    for (unsigned int index(0); index != count; ++index)
        if (methods[index] == method)
            goto found;
    if (newimp != NULL)
        if (!class_addMethod(_class, sel_getUid(oldname), newimp, type))
            NSLog(@"WB:Error: failed to rename [%s %s]", classname, oldname);
    goto done;
  found:
    if (newimp != NULL)
        method_setImplementation(method, newimp);
  done:
    free(methods);
}
/* }}} */

@protocol WinterBoard
- (NSString *) wb_pathForIcon;
- (NSString *) wb_pathForResource:(NSString *)resource ofType:(NSString *)type;
- (id) wb_init;
- (id) wb_layer;
- (id) wb_initWithSize:(CGSize)size;
- (id) wb_initWithSize:(CGSize)size label:(NSString *)label;
- (id) wb_initWithFrame:(CGRect)frame;
- (id) wb_initWithCoder:(NSCoder *)coder;
- (void) wb_setFrame:(CGRect)frame;
- (void) wb_setBackgroundColor:(id)color;
- (void) wb_setAlpha:(float)value;
- (void) wb_setBarStyle:(int)style;
- (id) wb_initWithFrame:(CGRect)frame withBarStyle:(int)style withTintColor:(UIColor *)color;
- (void) wb_setOpaque:(BOOL)opaque;
- (void) wb_setInDock:(BOOL)docked;
- (void) wb_didMoveToSuperview;
+ (UIImage *) wb_imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
@end

NSMutableDictionary **ImageMap_;

NSFileManager *Manager_;
NSDictionary *English_;
NSDictionary *Info_;
NSString *theme_;
NSString *Wallpaper_;

NSString *SBApplication$pathForIcon(SBApplication<WinterBoard> *self, SEL sel) {
    if (theme_ != nil) {
        NSString *identifier = [self bundleIdentifier];

        #define testForIcon(Name) \
            if (NSString *name = Name) { \
                NSString *path = [NSString stringWithFormat:@"%@/Icons/%@.png", theme_, name]; \
                if ([Manager_ fileExistsAtPath:path]) \
                    return path; \
            }

        if (identifier != nil) {
            NSString *path = [NSString stringWithFormat:@"%@/Bundles/%@/icon.png", theme_, identifier];
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }

        testForIcon(identifier);
        testForIcon([self displayName]);

        if (NSString *display = [self displayIdentifier])
            testForIcon([English_ objectForKey:display]);

        /*if (NSDictionary *strings = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/English.lproj/InfoPlist.strings", [self path]]]) {
            testForIcon([strings objectForKey:@"UISettingsDisplayName"]);

            _trace();
            if (NSString *bundle = [strings objectForKey:@"CFBundleName"]) {
                if ([bundle hasPrefix:@"Mobile"]) {
                    NSLog(@"bd:%@:%@", bundle, [bundle substringFromIndex:6]);
                    testForIcon([bundle substringFromIndex:6]);
                }
                testForIcon(bundle);
            }
        }*/
    }

    return [self wb_pathForIcon];
}

NSString *$pathForFileInBundle$(NSString *file) {
    if (theme_ != nil) {
        NSString *path = [NSString stringWithFormat:@"%@/Bundles/%@", theme_, file];
        if ([Manager_ fileExistsAtPath:path])
            return path;

        #define remapResourceName(oldname, newname) \
            else if ([file isEqualToString:oldname]) { \
                NSString *path = [NSString stringWithFormat:@"%@/%@.png", theme_, newname]; \
                if ([Manager_ fileExistsAtPath:path]) \
                    return path; \
            }

        if (false);
            remapResourceName(@"com.apple.springboard/FSO_BG.png", @"StatusBar")
            remapResourceName(@"com.apple.springboard/SBDockBG.png", @"Dock")
            remapResourceName(@"com.apple.springboard/SBWeatherCelsius.png", @"Icons/Weather")
    }

    return nil;
}

UIImage *UIImage$imageNamed$inBundle$(Class<WinterBoard> self, SEL sel, NSString *name, NSBundle *bundle) {
    if (Debug_)
        NSLog(@"WB:Debug: [UIImage(%@) imageNamed:\"%@\"]", [bundle bundleIdentifier], name);
    if (NSString *identifier = [bundle bundleIdentifier])
        if (NSString *path = $pathForFileInBundle$([NSString stringWithFormat:@"%@/%@", identifier, name]))
            return [UIImage imageWithContentsOfFile:path];
    return [self wb_imageNamed:name inBundle:bundle];
}

UIImage *UIImage$imageNamed$(Class<WinterBoard> self, SEL sel, NSString *name) {
    return UIImage$imageNamed$inBundle$(self, sel, name, [NSBundle mainBundle]);
}

NSString *NSBundle$pathForResource$ofType$(NSBundle<WinterBoard> *self, SEL sel, NSString *resource, NSString *type) {
    NSString *file = type == nil ? resource : [NSString stringWithFormat:@"%@.%@", resource, type];
    if (Debug_)
        NSLog(@"WB:Debug: [NSBundle(%@) pathForResource:\"%@\"]", [self bundleIdentifier], file);
    if (NSString *identifier = [self bundleIdentifier])
        if (NSString *path = $pathForFileInBundle$([NSString stringWithFormat:@"%@/%@", identifier, file]))
            return path;
    return [self wb_pathForResource:resource ofType:type];
}

void $setBackgroundColor$(id<WinterBoard> self, SEL sel, UIColor *color) {
    if (Wallpaper_ != nil)
        return [self wb_setBackgroundColor:[UIColor clearColor]];
    return [self wb_setBackgroundColor:color];
}

/*id SBStatusBarContentsView$initWithFrame$(SBStatusBarContentsView<WinterBoard> *self, SEL sel, CGRect frame) {
    self = [self wb_initWithFrame:frame];
    if (self == nil)
        return nil;

    NSString *path = [NSString stringWithFormat:@"%@/StatusBar.png", theme_];
    if ([Manager_ fileExistsAtPath:path])
        [self addSubview:[[[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:path]] autorelease]];
    //[self setBackgroundColor:[UIColor clearColor]];

    return self;
}*/

bool UINavigationBar$setBarStyle$_(SBAppWindow<WinterBoard> *self) {
    if (Info_ != nil) {
        NSNumber *number = [Info_ objectForKey:@"NavigationBarStyle"];
        if (number != nil) {
            [self wb_setBarStyle:[number intValue]];
            return true;
        }
    }

    return false;
}

/*id UINavigationBarBackground$initWithFrame$withBarStyle$withTintColor$(UINavigationBarBackground<WinterBoard> *self, SEL sel, CGRect frame, int style, UIColor *tint) {
    _trace();

    if (Info_ != nil) {
        NSNumber *number = [Info_ objectForKey:@"NavigationBarStyle"];
        if (number != nil)
            style = [number intValue];

        UIColor *color = [Info_ colorForKey:@"NavigationBarTint"];
        if (color != nil)
            tint = color;
    }

    return [self wb_initWithFrame:frame withBarStyle:style withTintColor:tint];
}*/

/*id UINavigationBar$initWithCoder$(SBAppWindow<WinterBoard> *self, SEL sel, CGRect frame, NSCoder *coder) {
    self = [self wb_initWithCoder:coder];
    if (self == nil)
        return nil;
    UINavigationBar$setBarStyle$_(self);
    return self;
}

id UINavigationBar$initWithFrame$(SBAppWindow<WinterBoard> *self, SEL sel, CGRect frame) {
    self = [self wb_initWithFrame:frame];
    if (self == nil)
        return nil;
    UINavigationBar$setBarStyle$_(self);
    return self;
}*/

void UINavigationBar$setBarStyle$(SBAppWindow<WinterBoard> *self, SEL sel, int style) {
    if (UINavigationBar$setBarStyle$_(self))
        return;
    return [self wb_setBarStyle:style];
}

void $didMoveToSuperview(SBButtonBar<WinterBoard> *self, SEL sel) {
    [[self superview] setBackgroundColor:[UIColor clearColor]];
    [self wb_didMoveToSuperview];
}

id SBContentLayer$initWithSize$(SBContentLayer<WinterBoard> *self, SEL sel, CGSize size) {
    self = [self wb_initWithSize:size];
    if (self == nil)
        return nil;

    if (Wallpaper_ != nil) {
        if (UIImage *image = [[UIImage alloc] initWithContentsOfFile:Wallpaper_])
            [self addSubview:[[[UIImageView alloc] initWithImage:image] autorelease]];
        [self setBackgroundColor:[UIColor redColor]];
    }

    return self;
}

@interface WBIconLabel : NSProxy {
    NSString *label_;
    BOOL docked_;
}

- (id) initWithLabel:(NSString *)label;
- (void) setInDock:(BOOL)docked;

@end

@implementation WBIconLabel

- (void) dealloc {
    [label_ release];
    [super dealloc];
}

- (id) initWithLabel:(NSString *)label {
    label_ = [label retain];
    return self;
}

- (BOOL) respondsToSelector:(SEL)sel {
    return
        sel == @selector(setInDock:)
    ? YES : [super respondsToSelector:sel];
}

- (NSMethodSignature*) methodSignatureForSelector:(SEL)sel {
    if (NSMethodSignature *sig = [label_ methodSignatureForSelector:sel])
        return sig;
    NSLog(@"WB:Error: [WBIconLabel methodSignatureForSelector:(%s)]", sel_getName(sel));
    return nil;
}

- (void) forwardInvocation:(NSInvocation*)inv {
    SEL sel = [inv selector];
    if ([label_ respondsToSelector:sel])
        [inv invokeWithTarget:label_];
    else
        NSLog(@"WB:Error: [WBIconLabel forwardInvocation:(%s)]", sel_getName(sel));
}

- (NSString *) _iconLabelStyle {
    return Info_ == nil ? nil : [Info_ objectForKey:(docked_ ? @"DockIconLabelStyle" : @"IconLabelStyle")];
}

- (CGSize) drawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(int)mode alignment:(int)alignment {
    if (NSString *custom = [self _iconLabelStyle]) {
        [label_ drawInRect:rect withStyle:[NSString stringWithFormat:@"font-family: Helvetica; font-weight: bold; font-size: 11px; text-align: center; %@", custom]];
        return CGSizeZero;
    }

    return [label_ drawInRect:rect withFont:font lineBreakMode:mode alignment:alignment];
}

- (void) drawInRect:(CGRect)rect withStyle:(NSString *)style {
    if (NSString *custom = [self _iconLabelStyle])
        return [label_ drawInRect:rect withStyle:[NSString stringWithFormat:@"%@; %@", style, custom]];
    return [label_ drawInRect:rect withStyle:style];
}

- (void) setInDock:(BOOL)docked {
    docked_ = docked;
}

@end

void SBIconLabel$setInDock$(SBIconLabel<WinterBoard> *self, SEL sel, BOOL docked) {
    id label;
    object_getInstanceVariable(self, "_label", (void **) &label);
    if (Info_ == nil || [Info_ boolForKey:@"IconLabelInDock"])
        docked = YES;
    if (label != nil && [label respondsToSelector:@selector(setInDock:)])
        [label setInDock:docked];
    return [self wb_setInDock:docked];
}

id SBIconLabel$initWithSize$label$(SBIconLabel<WinterBoard> *self, SEL sel, CGSize size, NSString *label) {
    return [self wb_initWithSize:size label:[[[WBIconLabel alloc] initWithLabel:label] autorelease]];
}

extern "C" void FindMappedImages(void);
extern "C" NSData *UIImagePNGRepresentation(UIImage *);

extern "C" void WBInitialize() {
    NSLog(@"WB:Notice: Installing WinterBoard...");

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    struct nlist nl[3];
    memset(nl, 0, sizeof(nl));
    nl[0].n_un.n_name = (char *) "___mappedImages";
    nl[1].n_un.n_name = (char *) "__UISharedImageInitialize";
    nlist("/System/Library/Frameworks/UIKit.framework/UIKit", nl);
    ImageMap_ = (id *) nl[0].n_value;
    void (*__UISharedImageInitialize)(bool) = (void (*)(bool)) nl[1].n_value;

    __UISharedImageInitialize(false);

    /*NSArray *keys = [*ImageMap_ allKeys];
    for (int i(0), e([keys count]); i != e; ++i) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSString *key = [keys objectAtIndex:i];
        CGImageRef ref = (CGImageRef) [*ImageMap_ objectForKey:key];
        UIImage *image = [UIImage imageWithCGImage:ref];
        NSData *data = UIImagePNGRepresentation(image);
        [data writeToFile:[NSString stringWithFormat:@"/tmp/pwnr/%@", key] atomically:YES];
        [pool release];
    }*/

    English_ = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/English.lproj/LocalizedApplicationNames.strings"];
    if (English_ != nil)
        English_ = [English_ retain];

    Manager_ = [[NSFileManager defaultManager] retain];

    //WBRename("SBStatusBarContentsView", "setBackgroundColor:", (IMP) &$setBackgroundColor$);
    //WBRename("UINavigationBar", "initWithFrame:", (IMP) &UINavigationBar$initWithFrame$);
    //WBRename("UINavigationBar", "initWithCoder:", (IMP) &UINavigationBar$initWithCoder$);
    WBRename(true, "UINavigationBar", "setBarStyle:", (IMP) &UINavigationBar$setBarStyle$);
    //WBRename("UINavigationBarBackground", "initWithFrame:withBarStyle:withTintColor:", (IMP) &UINavigationBarBackground$initWithFrame$withBarStyle$withTintColor$);
    //WBRename("SBStatusBarContentsView", "initWithFrame:", (IMP) &SBStatusBarContentsView$initWithFrame$);

    WBRename(false, "UIImage", "imageNamed:inBundle:", (IMP) &UIImage$imageNamed$inBundle$);
    WBRename(false, "UIImage", "imageNamed:", (IMP) &UIImage$imageNamed$);
    WBRename(true, "SBApplication", "pathForIcon", (IMP) &SBApplication$pathForIcon);
    WBRename(true, "NSBundle", "pathForResource:ofType:", (IMP) &NSBundle$pathForResource$ofType$);
    WBRename(true, "SBContentLayer", "initWithSize:", (IMP) &SBContentLayer$initWithSize$);
    WBRename(true, "SBStatusBarContentsView", "didMoveToSuperview", (IMP) &$didMoveToSuperview);
    WBRename(true, "SBButtonBar", "didMoveToSuperview", (IMP) &$didMoveToSuperview);
    WBRename(true, "SBIconLabel", "setInDock:", (IMP) &SBIconLabel$setInDock$);
    WBRename(true, "SBIconLabel", "initWithSize:label:", (IMP) &SBIconLabel$initWithSize$label$);

    if (NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Library/Preferences/com.saurik.WinterBoard.plist", NSHomeDirectory()]]) {
        [settings autorelease];
        NSString *name = [settings objectForKey:@"Theme"];
        NSString *path;

        if (theme_ == nil) {
            path = [NSString stringWithFormat:@"%@/Library/SummerBoard/Themes/%@", NSHomeDirectory(), name];
            if ([Manager_ fileExistsAtPath:path])
                theme_ = [path retain];
        }

        if (theme_ == nil) {
            path = [NSString stringWithFormat:@"/Library/Themes/%@", name];
            if ([Manager_ fileExistsAtPath:path])
                theme_ = [path retain];
        }
    }

    if (theme_ != nil) {
        NSString *path = [NSString stringWithFormat:@"%@/Wallpaper.png", theme_];
        if ([Manager_ fileExistsAtPath:path])
            Wallpaper_ = [path retain];

        NSString *folder = [NSString stringWithFormat:@"%@/UIImages", theme_];
        if (NSArray *images = [Manager_ contentsOfDirectoryAtPath:folder error:NULL])
            for (int i(0), e = [images count]; i != e; ++i) {
                NSString *name = [images objectAtIndex:i];
                if (![name hasSuffix:@".png"])
                    continue;
                NSString *path = [NSString stringWithFormat:@"%@/%@", folder, name];
                UIImage *image = [UIImage imageWithContentsOfFile:path];
                [*ImageMap_ setObject:(id)[image imageRef] forKey:name];
            }

        Info_ = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Info.plist", theme_]];
        if (Info_ == nil) {
            //LabelColor_ = [UIColor whiteColor];
        } else {
            //LabelColor_ = [Info_ colorForKey:@"LabelColor"];
        }
    }

    [pool release];
}
