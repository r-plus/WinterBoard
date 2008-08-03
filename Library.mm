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

#define _trace() NSLog(@"_trace(%u)", __LINE__);

#include <objc/runtime.h>
#include <objc/message.h>

#import <Foundation/Foundation.h>

#import <UIKit/UIColor.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIImageView.h>
#import <UIKit/UINavigationBarBackground.h>

#import <UIKit/UIView-Geometry.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIView-Rendering.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBAppWindow.h>
#import <SpringBoard/SBButtonBar.h>
#import <SpringBoard/SBContentLayer.h>
#import <SpringBoard/SBUIController.h>

#import <CoreGraphics/CGGeometry.h>

@interface NSDictionary (WinterBoard)
- (UIColor *) colorForKey:(NSString *)key;
@end

@implementation NSDictionary (WinterBoard)

- (UIColor *) colorForKey:(NSString *)key {
    NSString *value = [self objectForKey:key];
    if (value == nil)
        return nil;
    /* XXX: incorrect */
    return nil;
}

@end

/* WinterBoard Backend {{{ */
#define WBPrefix "wb_"

void WBInject(const char *classname, const char *oldname, IMP newimp, const char *type) {
    Class _class = objc_getClass(classname);
    if (_class == nil)
        return;
    if (!class_addMethod(_class, sel_registerName(oldname), newimp, type))
        NSLog(@"WB: failed to inject [%s %s]", classname, oldname);
}

void WBRename(const char *classname, const char *oldname, IMP newimp) {
    Class _class = objc_getClass(classname);
    if (_class == nil) {
        NSLog(@"WB: cannot find class [%s]", classname);
        return;
    }
    Method method = class_getInstanceMethod(_class, sel_getUid(oldname));
    if (method == nil) {
        NSLog(@"WB: cannot find method [%s %s]", classname, oldname);
        return;
    }
    size_t namelen = strlen(oldname);
    char newname[sizeof(WBPrefix) + namelen];
    memcpy(newname, WBPrefix, sizeof(WBPrefix) - 1);
    memcpy(newname + sizeof(WBPrefix) - 1, oldname, namelen + 1);
    const char *type = method_getTypeEncoding(method);
    if (!class_addMethod(_class, sel_registerName(newname), method_getImplementation(method), type))
        NSLog(@"WB: failed to rename [%s %s]", classname, oldname);
    unsigned int count;
    Method *methods = class_copyMethodList(_class, &count);
    for (unsigned int index(0); index != count; ++index)
        if (methods[index] == method)
            goto found;
    if (newimp != NULL)
        if (!class_addMethod(_class, sel_getUid(oldname), newimp, type))
            NSLog(@"WB: failed to rename [%s %s]", classname, oldname);
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
- (id) wb_initWithSize:(CGSize)size;
- (id) wb_initWithFrame:(CGRect)frame;
- (id) wb_initWithCoder:(NSCoder *)coder;
- (void) wb_setFrame:(CGRect)frame;
- (void) wb_setBackgroundColor:(id)color;
- (void) wb_setAlpha:(float)value;
- (void) wb_setBarStyle:(int)style;
- (id) wb_initWithFrame:(CGRect)frame withBarStyle:(int)style withTintColor:(UIColor *)color;
@end

NSFileManager *Manager_;
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

        testForIcon([self displayName]);
        testForIcon(identifier);

        if (identifier != nil) {
            NSString *path = [NSString stringWithFormat:@"%@/Bundles/%@/icon.png", theme_, identifier];
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }
    }

    return [self wb_pathForIcon];
}

NSString *NSBundle$pathForResource$ofType$(NSBundle<WinterBoard> *self, SEL sel, NSString *resource, NSString *type) {
    NSLog(@"WB: NSBundle(%@) pathForResource:%@ ofType:%@", [self bundleIdentifier], resource, type);

    if (theme_ != nil) {
        NSString *identifier = [self bundleIdentifier];

        if (identifier != nil) {
            NSString *path = [NSString stringWithFormat:@"%@/Bundles/%@/%@.%@", theme_, identifier, resource, type];
            if ([Manager_ fileExistsAtPath:path])
                return path;
            NSLog(@"p...%@ (%u)", path, [Manager_ fileExistsAtPath:path]);
        }

        if ([resource isEqualToString:@"SBDockBG"] && [type isEqualToString:@"png"]) {
            NSString *path = [NSString stringWithFormat:@"%@/Dock.png", theme_];
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }
    }

    return [self wb_pathForResource:resource ofType:type];
}

void SBAppWindow$setBackgroundColor$(SBAppWindow<WinterBoard> *self, SEL sel, UIColor *color) {
    if (Wallpaper_ != nil)
        return [self wb_setBackgroundColor:[UIColor clearColor]];
    return [self wb_setBackgroundColor:color];
}

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

/*id SBButtonBar$initWithFrame$(SBButtonBar<WinterBoard> *self, SEL sel, CGRect frame) {
    self = [self wb_initWithFrame:frame];
    if (self == nil)
        return nil;
    if (Wallpaper_ != nil)
        [self setBackgroundColor:[UIColor clearColor]];
    return self;
}*/

id SBContentLayer$initWithSize$(SBContentLayer<WinterBoard> *self, SEL sel, CGSize size) {
    self = [self wb_initWithSize:size];
    if (self == nil)
        return nil;

    if (Wallpaper_ != nil)
        if (UIImage *image = [[UIImage alloc] initWithContentsOfFile:Wallpaper_])
            [self addSubview:[[[UIImageView alloc] initWithImage:image] autorelease]];

    return self;
}

extern "C" void WBInitialize() {
    NSLog(@"WB: installing WinterBoard...");

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    WBRename("SBApplication", "pathForIcon", (IMP) &SBApplication$pathForIcon);
    WBRename("NSBundle", "pathForResource:ofType:", (IMP) &NSBundle$pathForResource$ofType$);
    WBRename("SBAppWindow", "setBackgroundColor:", (IMP) &SBAppWindow$setBackgroundColor$);
    WBRename("SBContentLayer", "initWithSize:", (IMP) &SBContentLayer$initWithSize$);
    //WBRename("UINavigationBar", "initWithFrame:", (IMP) &UINavigationBar$initWithFrame$);
    //WBRename("UINavigationBar", "initWithCoder:", (IMP) &UINavigationBar$initWithCoder$);
    WBRename("UINavigationBar", "setBarStyle:", (IMP) &UINavigationBar$setBarStyle$);
    //WBRename("UINavigationBarBackground", "initWithFrame:withBarStyle:withTintColor:", (IMP) &UINavigationBarBackground$initWithFrame$withBarStyle$withTintColor$);

    Manager_ = [[NSFileManager defaultManager] retain];

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

        Info_ = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Info.plist", theme_]];
        if (Info_ == nil) {
            //LabelColor_ = [UIColor whiteColor];
        } else {
            //LabelColor_ = [Info_ colorForKey:@"LabelColor"];
        }
    }

    [pool release];
}
