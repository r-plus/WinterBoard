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
#define _transient

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
#import <UIKit/UIWebDocumentView.h>

#import <UIKit/NSString-UIStringDrawing.h>
#import <UIKit/NSString-UIStringDrawingDeprecated.h>

#import <UIKit/UIImage-UIImageDeprecated.h>

#import <UIKit/UIView-Geometry.h>
#import <UIKit/UIView-Hierarchy.h>
#import <UIKit/UIView-Rendering.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBAppWindow.h>
#import <SpringBoard/SBButtonBar.h>
#import <SpringBoard/SBContentLayer.h>
#import <SpringBoard/SBIconLabel.h>
#import <SpringBoard/SBStatusBarContentsView.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBStatusBarTimeView.h>
#import <SpringBoard/SBUIController.h>

#import <MediaPlayer/MPVideoView.h>
#import <MediaPlayer/MPVideoView-PlaybackControl.h>

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
bool Engineer_ = false;

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
- (void) wb_drawRect:(CGRect)rect;
- (void) wb_setBackgroundColor:(id)color;
- (void) wb_setAlpha:(float)value;
- (void) wb_setBarStyle:(int)style;
- (id) wb_initWithFrame:(CGRect)frame withBarStyle:(int)style withTintColor:(UIColor *)color;
- (void) wb_setOpaque:(BOOL)opaque;
- (void) wb_setInDock:(BOOL)docked;
- (void) wb_didMoveToSuperview;
+ (UIImage *) wb_imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
+ (UIImage *) wb_applicationImageNamed:(NSString *)name;
- (NSDictionary *) wb_infoDictionary;
- (UIImage *) wb_icon;
- (id) wb_initWithStatusBar:(id)bar mode:(int)mode;
- (id) wb_initWithMode:(int)mode orientation:(int)orientation;
- (void) wb_setStatusBarMode:(int)mode orientation:(int)orientation duration:(float)duration fenceID:(int)id animation:(int)animation;
@end

NSMutableDictionary **ImageMap_;
NSMutableSet *UIImages_;

NSFileManager *Manager_;
NSDictionary *English_;
NSMutableDictionary *Info_;
NSMutableArray *themes_;

NSString *$pathForIcon$(SBApplication<WinterBoard> *self) {
    for (NSString *theme in themes_) {
        NSString *identifier = [self bundleIdentifier];
        NSString *folder = [[self path] lastPathComponent];
        NSString *dname = [self displayName];
        NSString *didentifier = [self displayIdentifier];

        if (Debug_) {
            NSLog(@"WB:Debug: [SBApplication(%@:%@:%@:%@) pathForIcon]", identifier, folder, dname, didentifier);
        }

        #define testForIcon(Name) \
            if (NSString *name = Name) { \
                NSString *path = [NSString stringWithFormat:@"%@/Icons/%@.png", theme, name]; \
                if ([Manager_ fileExistsAtPath:path]) \
                    return path; \
            }

        if (identifier != nil) {
            NSString *path = [NSString stringWithFormat:@"%@/Bundles/%@/icon.png", theme, identifier];
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }

        if (folder != nil) {
            NSString *path = [NSString stringWithFormat:@"%@/Folders/%@/icon.png", theme, folder];
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }

        testForIcon(identifier);
        testForIcon(dname);

        if (didentifier != nil) {
            testForIcon([English_ objectForKey:didentifier]);

            NSArray *parts = [didentifier componentsSeparatedByString:@"-"];
            if ([parts count] != 1)
                if (NSDictionary *english = [[[NSDictionary alloc] initWithContentsOfFile:[[self path] stringByAppendingString:@"/English.lproj/UIRoleDisplayNames.strings"]] autorelease])
                    testForIcon([english objectForKey:[parts lastObject]]);
        }
    }

    return nil;
}

static UIImage *SBApplicationIcon$icon(SBApplicationIcon<WinterBoard> *self, SEL sel) {
    if (![Info_ boolForKey:@"ComposeStoreIcons"])
        if (NSString *path = $pathForIcon$([self application]))
            return [UIImage imageWithContentsOfFile:path];
    return [self wb_icon];
}

static NSString *SBApplication$pathForIcon(SBApplication<WinterBoard> *self, SEL sel) {
    if (NSString *path = $pathForIcon$(self))
        return path;
    return [self wb_pathForIcon];
}

static NSString *$pathForFile$inBundle$(NSString *file, NSBundle *bundle) {
    for (NSString *theme in themes_) {
        NSString *identifier = [bundle bundleIdentifier];

        if (identifier != nil) {
            NSString *path = [NSString stringWithFormat:@"%@/Bundles/%@/%@", theme, identifier, file];
            if (Debug_)
                NSLog(@"WB:Debug:%@", path);
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }

        if (NSString *folder = [[bundle bundlePath] lastPathComponent]) {
            NSString *path = [NSString stringWithFormat:@"%@/Folders/%@/%@", theme, folder, file];
            if (Debug_)
                NSLog(@"WB:Debug:%@", path);
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }

        #define remapResourceName(oldname, newname) \
            else if ([file isEqualToString:oldname]) { \
                NSString *path = [NSString stringWithFormat:@"%@/%@.png", theme, newname]; \
                if (Debug_) \
                    NSLog(@"WB:Debug:%@", path); \
                if ([Manager_ fileExistsAtPath:path]) \
                    return path; \
            }

        if (identifier == nil || ![identifier isEqualToString:@"com.apple.springboard"]);
            remapResourceName(@"FSO_BG.png", @"StatusBar")
            remapResourceName(@"SBDockBG.png", @"Dock")
            remapResourceName(@"SBWeatherCelsius.png", @"Icons/Weather")
    }

    return nil;
}

static UIImage *UIImage$imageNamed$inBundle$(Class<WinterBoard> self, SEL sel, NSString *name, NSBundle *bundle) {
    if (Debug_)
        NSLog(@"WB:Debug: [UIImage(%@) imageNamed:\"%@\"]", [bundle bundleIdentifier], name);
    if (NSString *path = $pathForFile$inBundle$(name, bundle))
        return [UIImage imageWithContentsOfFile:path];
    return [self wb_imageNamed:name inBundle:bundle];
}

static UIImage *UIImage$imageNamed$(Class<WinterBoard> self, SEL sel, NSString *name) {
    return UIImage$imageNamed$inBundle$(self, sel, name, [NSBundle mainBundle]);
}

static UIImage *UIImage$applicationImageNamed$(Class<WinterBoard> self, SEL sel, NSString *name) {
    NSBundle *bundle = [NSBundle mainBundle];
    if (Debug_)
        NSLog(@"WB:Debug: [UIImage(%@) applicationImageNamed:\"%@\"]", [bundle bundleIdentifier], name);
    if (NSString *path = $pathForFile$inBundle$(name, bundle))
        return [UIImage imageWithContentsOfFile:path];
    return [self wb_applicationImageNamed:name];
}

static NSString *NSBundle$pathForResource$ofType$(NSBundle<WinterBoard> *self, SEL sel, NSString *resource, NSString *type) {
    NSString *file = type == nil ? resource : [NSString stringWithFormat:@"%@.%@", resource, type];
    if (Debug_)
        NSLog(@"WB:Debug: [NSBundle(%@) pathForResource:\"%@\"]", [self bundleIdentifier], file);
    if (NSString *path = $pathForFile$inBundle$(file, self))
        return path;
    return [self wb_pathForResource:resource ofType:type];
}

bool UINavigationBar$setBarStyle$_(SBAppWindow<WinterBoard> *self) {
    if (NSNumber *number = [Info_ objectForKey:@"NavigationBarStyle"]) {
        [self wb_setBarStyle:[number intValue]];
        return true;
    }

    return false;
}

/*id UINavigationBarBackground$initWithFrame$withBarStyle$withTintColor$(UINavigationBarBackground<WinterBoard> *self, SEL sel, CGRect frame, int style, UIColor *tint) {
    _trace();

    if (NSNumber *number = [Info_ objectForKey:@"NavigationBarStyle"])
        style = [number intValue];

    if (UIColor *color = [Info_ colorForKey:@"NavigationBarTint"])
        tint = color;

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

static void UINavigationBar$setBarStyle$(SBAppWindow<WinterBoard> *self, SEL sel, int style) {
    if (UINavigationBar$setBarStyle$_(self))
        return;
    return [self wb_setBarStyle:style];
}

static void $didMoveToSuperview(SBButtonBar<WinterBoard> *self, SEL sel) {
    [[self superview] setBackgroundColor:[UIColor clearColor]];
    [self wb_didMoveToSuperview];
}

static NSString *$getTheme$(NSArray *files) {
    for (NSString *theme in themes_)
        for (NSString *file in files) {
            NSString *path([NSString stringWithFormat:@"%@/%@", theme, file]);
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }

    return nil;
}

static id SBContentLayer$initWithSize$(SBContentLayer<WinterBoard> *self, SEL sel, CGSize size) {
    self = [self wb_initWithSize:size];
    if (self == nil)
        return nil;

    if (NSString *path = $getTheme$([NSArray arrayWithObject:@"Wallpaper.mp4"])) {
        MPVideoView *video = [[[MPVideoView alloc] initWithFrame:[self bounds]] autorelease];
        [video setMovieWithPath:path];
        [video setRepeatMode:1];
        [video setRepeatGap:0];
        [self addSubview:video];
        [video playFromBeginning];;
    }

    if (NSString *path = $getTheme$([NSArray arrayWithObjects:@"Wallpaper.png", @"Wallpaper.jpg", nil]))
        if (UIImage *image = [[[UIImage alloc] initWithContentsOfFile:path] autorelease])
            [self addSubview:[[[UIImageView alloc] initWithImage:image] autorelease]];

    if (NSString *path = $getTheme$([NSArray arrayWithObject:@"Wallpaper.html"])) {
        CGRect bounds = [self bounds];

        UIWebDocumentView *view([[[UIWebDocumentView alloc] initWithFrame:bounds] autorelease]);
        [view setAutoresizes:YES];

        [view loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]]];

        [[view webView] setDrawsBackground:NO];
        [view setBackgroundColor:[UIColor clearColor]];

        [self addSubview:view];
    }

    return self;
}

#define WBDelegate(delegate) \
    - (NSMethodSignature*) methodSignatureForSelector:(SEL)sel { \
        if (Engineer_) \
            NSLog(@"WB:MS:%s:(%s)", class_getName([self class]), sel_getName(sel)); \
        if (NSMethodSignature *sig = [delegate methodSignatureForSelector:sel]) \
            return sig; \
        NSLog(@"WB:Error: [%s methodSignatureForSelector:(%s)]", class_getName([self class]), sel_getName(sel)); \
        return nil; \
    } \
\
    - (void) forwardInvocation:(NSInvocation*)inv { \
        SEL sel = [inv selector]; \
        if ([delegate respondsToSelector:sel]) \
            [inv invokeWithTarget:delegate]; \
        else \
            NSLog(@"WB:Error: [%s forwardInvocation:(%s)]", class_getName([self class]), sel_getName(sel)); \
    }

static unsigned *ContextCount_;
static void ***ContextStack_;

extern "C" CGColorRef CGGStateGetSystemColor(void *);
extern "C" CGColorRef CGGStateGetFillColor(void *);
extern "C" CGColorRef CGGStateGetStrokeColor(void *);
extern "C" NSString *UIStyleStringFromColor(CGColorRef);

@interface WBTime : NSProxy {
    NSString *time_;
    _transient SBStatusBarTimeView *view_;
}

- (id) initWithTime:(NSString *)time view:(SBStatusBarTimeView *)view;

@end

@implementation WBTime

- (void) dealloc {
    [time_ release];
    [super dealloc];
}

- (id) initWithTime:(NSString *)time view:(SBStatusBarTimeView *)view {
    time_ = [time retain];
    view_ = view;
    return self;
}

WBDelegate(time_)

- (CGSize) drawAtPoint:(CGPoint)point forWidth:(float)width withFont:(UIFont *)font lineBreakMode:(int)mode {
    if (NSString *custom = [Info_ objectForKey:@"TimeStyle"]) {
        BOOL mode;
        object_getInstanceVariable(view_, "_mode", (void **) &mode);

        [time_ drawAtPoint:point withStyle:[NSString stringWithFormat:@""
            "font-family: Helvetica; "
            "font-weight: bold; "
            "font-size: 14px; "
            "color: %@; "
        "%@", mode ? @"white" : @"black", custom]];

        return CGSizeZero;
    }

    return [time_ drawAtPoint:point forWidth:width withFont:font lineBreakMode:mode];
}

@end

@interface WBIconLabel : NSProxy {
    NSString *string_;
    BOOL docked_;
}

- (id) initWithString:(NSString *)string;

@end

@implementation WBIconLabel

- (void) dealloc {
    [string_ release];
    [super dealloc];
}

- (id) initWithString:(NSString *)string {
    string_ = [string retain];
    return self;
}

WBDelegate(string_)

- (NSString *) _iconLabelStyle {
    NSString *key = docked_ ? @"DockedIconLabelStyle" : @"UndockedIconLabelStyle";
    NSString *style = [Info_ objectForKey:key];
    return style;
}

- (CGSize) drawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(int)mode alignment:(int)alignment {
    if (NSString *custom = [self _iconLabelStyle]) {
        NSString *style = [NSString stringWithFormat:@""
            "font-family: Helvetica; "
            "font-weight: bold; "
            "font-size: 11px; "
            "text-align: center; "
            "color: %@; "
        "%@", docked_ ? @"white" : @"#b3b3b3", custom];

        if (Debug_)
            NSLog(@"WB:Debug:style = %@", style);
        [string_ drawInRect:rect withStyle:style];
        return CGSizeZero;
    }

    return [string_ drawInRect:rect withFont:font lineBreakMode:mode alignment:alignment];
}

- (void) drawInRect:(CGRect)rect withStyle:(NSString *)style {
    if (NSString *custom = [self _iconLabelStyle]) {
        NSString *combined = [NSString stringWithFormat:@"%@; %@", style, custom];
        if (Debug_)
            NSLog(@"WB:Debug:combined = %@", combined);
        return [string_ drawInRect:rect withStyle:combined];
    }
    return [string_ drawInRect:rect withStyle:style];
}

- (BOOL) respondsToSelector:(SEL)sel {
    return
        sel == @selector(setInDock:)
    ? YES : [super respondsToSelector:sel];
}

- (void) setInDock:(BOOL)docked {
    docked_ = docked;
}

@end

static void SBStatusBarController$setStatusBarMode$orientation$duration$fenceID$animation$(SBStatusBarController<WinterBoard> *self, SEL sel, int mode, int orientation, float duration, int id, int animation) {
    if (NSNumber *number = [Info_ objectForKey:@"StatusBarMode"])
        mode = [number intValue];
    return [self wb_setStatusBarMode:mode orientation:orientation duration:duration fenceID:id animation:animation];
}

/*static id SBStatusBar$initWithMode$orientation$(SBStatusBar<WinterBoard> *self, SEL sel, int mode, int orientation) {
    return [self wb_initWithMode:mode orientation:orientation];
}*/

static id SBStatusBarContentsView$initWithStatusBar$mode$(SBStatusBarContentsView<WinterBoard> *self, SEL sel, id bar, int mode) {
    if (NSNumber *number = [Info_ objectForKey:@"StatusBarContentsMode"])
        mode = [number intValue];
    return [self wb_initWithStatusBar:bar mode:mode];
}

static void SBStatusBarTimeView$drawRect$(SBStatusBarTimeView<WinterBoard> *self, SEL sel, CGRect rect) {
    id time;
    object_getInstanceVariable(self, "_time", (void **) &time);
    if (time != nil && [time class] != [WBTime class])
        object_setInstanceVariable(self, "_time", (void *) [[WBTime alloc] initWithTime:[time autorelease] view:self]);
    return [self wb_drawRect:rect];
}

static void SBIconLabel$setInDock$(SBIconLabel<WinterBoard> *self, SEL sel, BOOL docked) {
    id label;
    object_getInstanceVariable(self, "_label", (void **) &label);
    if (![Info_ boolForKey:@"UndockedIconLabels"])
        docked = YES;
    if (label != nil && [label respondsToSelector:@selector(setInDock:)])
        [label setInDock:docked];
    return [self wb_setInDock:docked];
}

static id SBIconLabel$initWithSize$label$(SBIconLabel<WinterBoard> *self, SEL sel, CGSize size, NSString *label) {
    // XXX: technically I'm misusing self here
    return [self wb_initWithSize:size label:[[[WBIconLabel alloc] initWithString:label] autorelease]];
    //return [self wb_initWithSize:size label:label];
}

extern "C" void FindMappedImages(void);
extern "C" NSData *UIImagePNGRepresentation(UIImage *);

static void (*__UISharedImageInitialize)(bool);

extern "C" void WBInitialize() {
    NSLog(@"WB:Notice: Installing WinterBoard...");

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    struct nlist nl[5];
    memset(nl, 0, sizeof(nl));

    nl[0].n_un.n_name = (char *) "___mappedImages";
    nl[1].n_un.n_name = (char *) "__UISharedImageInitialize";
    nl[2].n_un.n_name = (char *) "___currentContextCount";
    nl[3].n_un.n_name = (char *) "___currentContextStack";

    nlist("/System/Library/Frameworks/UIKit.framework/UIKit", nl);

    ImageMap_ = (id *) nl[0].n_value;
    __UISharedImageInitialize = (void (*)(bool)) nl[1].n_value;
    ContextCount_ = (unsigned *) nl[2].n_value;
    ContextStack_ = (void ***) nl[3].n_value;

    __UISharedImageInitialize(false);

    English_ = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/English.lproj/LocalizedApplicationNames.strings"];
    if (English_ != nil)
        English_ = [English_ retain];

    Manager_ = [[NSFileManager defaultManager] retain];
    UIImages_ = [[NSMutableSet alloc] initWithCapacity:16];

    //WBRename("UINavigationBar", "initWithCoder:", (IMP) &UINavigationBar$initWithCoder$);
    WBRename(true, "UINavigationBar", "setBarStyle:", (IMP) &UINavigationBar$setBarStyle$);
    //WBRename("UINavigationBarBackground", "initWithFrame:withBarStyle:withTintColor:", (IMP) &UINavigationBarBackground$initWithFrame$withBarStyle$withTintColor$);

    WBRename(false, "UIImage", "imageNamed:inBundle:", (IMP) &UIImage$imageNamed$inBundle$);
    WBRename(false, "UIImage", "imageNamed:", (IMP) &UIImage$imageNamed$);
    WBRename(false, "UIImage", "applicationImageNamed:", (IMP) &UIImage$applicationImageNamed$);
    WBRename(true, "SBApplicationIcon", "icon", (IMP) &SBApplicationIcon$icon);
    WBRename(true, "SBApplication", "pathForIcon", (IMP) &SBApplication$pathForIcon);
    WBRename(true, "NSBundle", "pathForResource:ofType:", (IMP) &NSBundle$pathForResource$ofType$);
    WBRename(true, "SBContentLayer", "initWithSize:", (IMP) &SBContentLayer$initWithSize$);
    WBRename(true, "SBStatusBarContentsView", "initWithStatusBar:mode:", (IMP) &SBStatusBarContentsView$initWithStatusBar$mode$);
    //WBRename(true, "SBStatusBar", "initWithMode:orientation:", (IMP) &SBStatusBar$initWithMode$orientation$);
    WBRename(true, "SBStatusBarContentsView", "didMoveToSuperview", (IMP) &$didMoveToSuperview);
    WBRename(true, "SBButtonBar", "didMoveToSuperview", (IMP) &$didMoveToSuperview);
    WBRename(true, "SBIconLabel", "setInDock:", (IMP) &SBIconLabel$setInDock$);
    WBRename(true, "SBIconLabel", "initWithSize:label:", (IMP) &SBIconLabel$initWithSize$label$);
    WBRename(true, "SBStatusBarTimeView", "drawRect:", (IMP) &SBStatusBarTimeView$drawRect$);
    WBRename(true, "SBStatusBarController", "setStatusBarMode:orientation:duration:fenceID:animation:", (IMP) &SBStatusBarController$setStatusBarMode$orientation$duration$fenceID$animation$);

    themes_ = [[NSMutableArray alloc] initWithCapacity:8];

    if (NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"/User/Library/Preferences/com.saurik.WinterBoard.plist"]]) {
        [settings autorelease];

        NSArray *themes = [settings objectForKey:@"Themes"];
        if (themes == nil)
            if (NSString *theme = [settings objectForKey:@"Theme"])
                themes = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
                    theme, @"Name",
                    [NSNumber numberWithBool:YES], @"Active",
                nil]];
        if (themes != nil)
            for (NSDictionary *theme in themes) {
                NSNumber *active = [theme objectForKey:@"Active"];
                if (![active boolValue])
                    continue;

                NSString *name = [theme objectForKey:@"Name"];
                if (name == nil)
                    continue;

                NSString *theme = nil;

                if (theme == nil) {
                    NSString *path = [NSString stringWithFormat:@"/Library/Themes/%@.theme", name];
                    if ([Manager_ fileExistsAtPath:path]) {
                        [themes_ addObject:path];
                        continue;
                    }
                }

                if (theme == nil) {
                    NSString *path = [NSString stringWithFormat:@"/Library/Themes/%@", name];
                    if ([Manager_ fileExistsAtPath:path]) {
                        [themes_ addObject:path];
                        continue;
                    }
                }

                if (theme == nil) {
                    NSString *path = [NSString stringWithFormat:@"%@/Library/SummerBoard/Themes/%@", NSHomeDirectory(), name];
                    if ([Manager_ fileExistsAtPath:path]) {
                        [themes_ addObject:path];
                        continue;
                    }
                }
            }
    }

    Info_ = [[NSMutableDictionary dictionaryWithCapacity:16] retain];

    for (NSString *theme in themes_) {
        NSString *folder = [NSString stringWithFormat:@"%@/UIImages", theme];
        if (NSArray *images = [Manager_ contentsOfDirectoryAtPath:folder error:NULL])
            for (int i(0), e = [images count]; i != e; ++i) {
                NSString *name = [images objectAtIndex:i];
                if (![name hasSuffix:@".png"])
                    continue;
                if ([UIImages_ containsObject:name])
                    continue;
                NSString *path = [NSString stringWithFormat:@"%@/%@", folder, name];
                UIImage *image = [UIImage imageWithContentsOfFile:path];
                [*ImageMap_ setObject:(id)[image imageRef] forKey:name];
                [UIImages_ addObject:name];
            }

        if (NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Info.plist", theme]])
            for (NSString *key in [info allKeys])
                if ([Info_ objectForKey:key] == nil)
                    [Info_ setObject:[info objectForKey:key] forKey:key];
    }

    if ([Info_ objectForKey:@"UndockedIconLabels"] == nil)
        [Info_ setObject:[NSNumber numberWithBool:(
            [Info_ objectForKey:@"DockedIconLabelStyle"] != nil ||
            [Info_ objectForKey:@"UndockedIconLabelStyle"] != nil
        )] forKey:@"UndockedIconLabels"];

    if (![Info_ boolForKey:@"UndockedIconLabels"])
    if (Debug_)
        NSLog(@"WB:Debug:Info = %@", [Info_ description]);

    [pool release];
}
