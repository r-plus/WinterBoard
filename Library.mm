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

#include <substrate.h>

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIImageView.h>
#import <UIKit/UINavigationBar.h>
#import <UIKit/UINavigationBarBackground.h>
#import <UIKit/UIToolbar.h>
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
#import <SpringBoard/SBBookmarkIcon.h>
#import <SpringBoard/SBButtonBar.h>
#import <SpringBoard/SBCalendarIconContentsView.h>
#import <SpringBoard/SBContentLayer.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconLabel.h>
#import <SpringBoard/SBSlidingAlertDisplay.h>
#import <SpringBoard/SBStatusBarContentsView.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBStatusBarTimeView.h>
#import <SpringBoard/SBUIController.h>

#import <MediaPlayer/MPVideoView.h>
#import <MediaPlayer/MPVideoView-PlaybackControl.h>

#import <CoreGraphics/CGGeometry.h>

extern "C" void __clear_cache (char *beg, char *end);

Class $MPVideoView;

Class $UIColor;
Class $UIImage;
Class $UIImageView;
Class $UIWebDocumentView;

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
    return false;
}

@end

bool Debug_ = false;
bool Engineer_ = false;

/* WinterBoard Backend {{{ */
void WBInject(const char *classname, const char *oldname, IMP newimp, const char *type) {
    Class _class = objc_getClass(classname);
    if (_class == nil)
        return;
    if (!class_addMethod(_class, sel_registerName(oldname), newimp, type))
        NSLog(@"WB:Error: failed to inject [%s %s]", classname, oldname);
}

/* }}} */

@protocol WinterBoard
- (CGSize) wb_renderedSizeOfNode:(id)node constrainedToWidth:(float)width;
- (void *) _node;
- (void) wb_updateDesktopImage:(UIImage *)image;
- (UIImage *) wb_defaultDesktopImage;
- (NSString *) wb_bundlePath;
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
- (void) wb_appendIconList:(SBIconList *)list;
- (id) wb_initWithStatusBar:(id)bar mode:(int)mode;
- (id) wb_initWithMode:(int)mode orientation:(int)orientation;
- (id) wb_imageAtPath:(NSString *)path;
- (id) wb_initWithContentsOfFile:(NSString *)file;
- (id) wb_initWithContentsOfFile:(NSString *)file cache:(BOOL)cache;
- (void) wb_setStatusBarMode:(int)mode orientation:(int)orientation duration:(float)duration fenceID:(int)id animation:(int)animation;
@end

static NSMutableDictionary **__mappedImages;
static NSMutableDictionary *UIImages_;
static NSMutableDictionary *PathImages_;

static NSFileManager *Manager_;
static NSDictionary *English_;
static NSMutableDictionary *Info_;
static NSMutableArray *themes_;

static NSString *$getTheme$(NSArray *files) {
    for (NSString *theme in themes_)
        for (NSString *file in files) {
            NSString *path([NSString stringWithFormat:@"%@/%@", theme, file]);
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }

    return nil;
}

static NSString *$pathForIcon$(SBApplication<WinterBoard> *self) {
    for (NSString *theme in themes_) {
        NSString *identifier = [self bundleIdentifier];
        NSString *folder = [[self path] lastPathComponent];
        NSString *dname = [self displayName];
        NSString *didentifier = [self displayIdentifier];

        if (Debug_)
            NSLog(@"WB:Debug: [SBApplication(%@:%@:%@:%@) pathForIcon]", identifier, folder, dname, didentifier);

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
            return [$UIImage imageWithContentsOfFile:path];
    return [self wb_icon];
}

static UIImage *SBBookmarkIcon$icon(SBBookmarkIcon<WinterBoard> *self, SEL sel) {
    if (Debug_)
        NSLog(@"WB:Debug:Bookmark(%@:%@)", [self displayIdentifier], [self displayName]);
    if (NSString *path = $getTheme$([NSArray arrayWithObject:[NSString stringWithFormat:@"Icons/%@.png", [self displayName]]]))
        return [$UIImage imageWithContentsOfFile:path];
    return [self wb_icon];
}

static NSString *SBApplication$pathForIcon(SBApplication<WinterBoard> *self, SEL sel) {
    if (NSString *path = $pathForIcon$(self))
        return path;
    return [self wb_pathForIcon];
}

static NSString *$pathForFile$inBundle$(NSString *file, NSBundle<WinterBoard> *bundle, bool ui) {
    for (NSString *theme in themes_) {
        NSString *identifier = [bundle bundleIdentifier];

        if (identifier != nil) {
            NSString *path = [NSString stringWithFormat:@"%@/Bundles/%@/%@", theme, identifier, file];
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }

        if (NSString *folder = [[bundle wb_bundlePath] lastPathComponent]) {
            NSString *path = [NSString stringWithFormat:@"%@/Folders/%@/%@", theme, folder, file];
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }

        #define remapResourceName(oldname, newname) \
            else if ([file isEqualToString:oldname]) { \
                NSString *path = [NSString stringWithFormat:@"%@/%@.png", theme, newname]; \
                if ([Manager_ fileExistsAtPath:path]) \
                    return path; \
            }

        if (identifier == nil || ![identifier isEqualToString:@"com.apple.springboard"]);
            remapResourceName(@"FSO_BG.png", @"StatusBar")
            remapResourceName(@"SBDockBG.png", @"Dock")
            remapResourceName(@"SBWeatherCelsius.png", @"Icons/Weather")

        if (ui) {
            NSString *path = [NSString stringWithFormat:@"%@/UIImages/%@", theme, file];
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }
    }

    return nil;
}

static UIImage *CachedImageAtPath(NSString *path) {
    UIImage *image = [PathImages_ objectForKey:path];
    if (image != nil)
        return reinterpret_cast<id>(image) == [NSNull null] ? nil : image;
    image = [[$UIImage alloc] wb_initWithContentsOfFile:path cache:true];
    if (image != nil)
        image = [image autorelease];
    [PathImages_ setObject:(image == nil ? [NSNull null] : reinterpret_cast<id>(image)) forKey:path];
    return image;
}

static UIImage *UIImage$imageNamed$inBundle$(Class<WinterBoard> self, SEL sel, NSString *name, NSBundle *bundle) {
    NSString *key = [NSString stringWithFormat:@"B:%@/%@", [bundle bundleIdentifier], name];
    UIImage *image = [PathImages_ objectForKey:key];
    if (image != nil)
        return reinterpret_cast<id>(image) == [NSNull null] ? nil : image;
    if (Debug_)
        NSLog(@"WB:Debug: [UIImage(%@) imageNamed:\"%@\"]", [bundle bundleIdentifier], name);
    if (NSString *path = $pathForFile$inBundle$(name, bundle, false))
        image = CachedImageAtPath(path);
    if (image == nil)
        image = [self wb_imageNamed:name inBundle:bundle];
    [PathImages_ setObject:(image == nil ? [NSNull null] : reinterpret_cast<id>(image)) forKey:key];
    return image;
}

static UIImage *UIImage$imageNamed$(Class<WinterBoard> self, SEL sel, NSString *name) {
    return UIImage$imageNamed$inBundle$(self, sel, name, [NSBundle mainBundle]);
}

static UIImage *UIImage$applicationImageNamed$(Class<WinterBoard> self, SEL sel, NSString *name) {
    NSBundle *bundle = [NSBundle mainBundle];
    if (Debug_)
        NSLog(@"WB:Debug: [UIImage(%@) applicationImageNamed:\"%@\"]", [bundle bundleIdentifier], name);
    if (NSString *path = $pathForFile$inBundle$(name, bundle, false))
        return CachedImageAtPath(path);
    return [self wb_applicationImageNamed:name];
}

@interface NSString (WinterBoard)
- (NSString *) wb_themedPath;
@end

@implementation NSString (WinterBoard)

- (NSString *) wb_themedPath {
    if (Debug_)
        NSLog(@"WB:Debug:Bypass(\"%@\")", self);
    return self;
}

@end

static NSMutableDictionary *Files_;

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

/*@interface WBBundlePath : NSProxy {
    NSBundle<WinterBoard> *bundle_;
    NSString *path_;
}

- (id) initWithBundle:(NSBundle *)bundle path:(NSString *)path;

- (NSString *) wb_themedPath;

@end

@implementation WBBundlePath

- (void) dealloc {
    [bundle_ release];
    [path_ release];
    [super dealloc];
}

- (id) initWithBundle:(NSBundle *)bundle path:(NSString *)path {
    bundle_ = [bundle retain];
    path_ = [path retain];
    return self;
}

WBDelegate(path_)

- (NSString *) stringByAppendingPathComponent:(NSString *)component {
    NSLog(@"WB:Debug:app:%@:%@", path_, component);
    return [[[WBBundlePath alloc] initWithBundle:bundle_ path:[path_ stringByAppendingPathComponent:component]] autorelease];
}

- (NSString *) stringByAppendingPathExtension:(NSString *)extension {
    return [[[WBBundlePath alloc] initWithBundle:bundle_ path:[path_ stringByAppendingPathExtension:extension]] autorelease];
}

- (const char *) UTF8String {
    const char *string = [path_ UTF8String];
    NSLog(@"WB:Debug:UTF=%s", string);
    return string;
}

- (NSString *) description {
    return [path_ description];
}

- (NSString *) wb_themedPath {
    return path_;
    NSString *path = [Files_ objectForKey:path_];
    if (path == nil) {
        NSString *path = [bundle_ wb_bundlePath];
        if (![path_ hasPrefix:path]) {
            NSLog(@"WB:Error:![@\"%@\" hasPrefix:@\"%@\"]", path_, path);
            return path_;
        }
        path = [path_ substringFromIndex:([path length] + 1)];
        path = $pathForFile$inBundle$(path, bundle_, false);
        if (path == nil)
            path = reinterpret_cast<NSString *>([NSNull null]);
        [Files_ setObject:path forKey:path_];
        if (Debug_)
            NSLog(@"WB:Debug:ThemePath(\"%@\")->\"%@\"", path_, path);
    }
    if (reinterpret_cast<id>(path) == [NSNull null])
        path = path_;
    NSLog(@"WB:Debug:ThemePath=%@", path);
    return path;
}

@end*/

static NSString *NSBundle$bundlePath$(NSBundle<WinterBoard> *self, SEL sel) {
    //return [[WBBundlePath alloc] initWithBundle:self path:[self wb_bundlePath]];
    return [self wb_bundlePath];
}

static NSString *NSBundle$pathForResource$ofType$(NSBundle<WinterBoard> *self, SEL sel, NSString *resource, NSString *type) {
    NSString *file = type == nil ? resource : [NSString stringWithFormat:@"%@.%@", resource, type];
    if (Debug_)
        NSLog(@"WB:Debug: [NSBundle(%@) pathForResource:\"%@\"]", [self bundleIdentifier], file);
    if (NSString *path = $pathForFile$inBundle$(file, self, false))
        return path;
    return [self wb_pathForResource:resource ofType:type];
}

static bool $setBarStyle$_(NSString *name, UIView<WinterBoard> *self, int style) {
    if (Debug_)
        NSLog(@"WB:Debug:%@Style:%d", name, style);
    NSNumber *number = nil;
    if (number == nil)
        number = [Info_ objectForKey:[NSString stringWithFormat:@"%@Style-%d", name, style]];
    if (number == nil)
        number = [Info_ objectForKey:[NSString stringWithFormat:@"%@Style", name]];
    if (number == nil)
        return false;
    else {
        style = [number intValue];
        if (Debug_)
            NSLog(@"WB:Debug:%@Style=%d", name, style);
        [self wb_setBarStyle:style];
        return true;
    }
}

static void SBCalendarIconContentsView$drawRect$(SBCalendarIconContentsView<WinterBoard> *self, SEL sel, CGRect rect) {
    CFLocaleRef locale(CFLocaleCopyCurrent());
    CFDateFormatterRef formatter(CFDateFormatterCreate(NULL, locale, kCFDateFormatterNoStyle, kCFDateFormatterNoStyle));
    CFRelease(locale);

    CFDateRef now(CFDateCreate(NULL, CFAbsoluteTimeGetCurrent()));

    CFDateFormatterSetFormat(formatter, CFSTR("d"));
    CFStringRef date(CFDateFormatterCreateStringWithDate(NULL, formatter, now));
    CFDateFormatterSetFormat(formatter, CFSTR("EEEE"));
    CFStringRef day(CFDateFormatterCreateStringWithDate(NULL, formatter, now));

    CFRelease(now);

    CFRelease(formatter);

    NSString *datestyle(@""
        "font-family: Helvetica; "
        "font-weight: bold; "
        "font-size: 39px; "
        "color: #333333; "
        "alpha: 1.0; "
    "");

    NSString *daystyle(@""
        "font-family: Helvetica; "
        "font-weight: bold; "
        "font-size: 9px; "
        "color: white; "
        "text-shadow: rgba(0, 0, 0, 0.2) -1px -1px 2px; "
    "");

    if (NSString *style = [Info_ objectForKey:@"CalendarIconDateStyle"])
        datestyle = [datestyle stringByAppendingString:style];
    if (NSString *style = [Info_ objectForKey:@"CalendarIconDayStyle"])
        daystyle = [daystyle stringByAppendingString:style];

    float width([self bounds].size.width);
    CGSize datesize = [(NSString *)date sizeWithStyle:datestyle forWidth:width];
    CGSize daysize = [(NSString *)day sizeWithStyle:daystyle forWidth:width];

    [(NSString *)date drawAtPoint:CGPointMake(
        (width + 4 - datesize.width) / 2, (71 - datesize.height) / 2
    ) withStyle:datestyle];

    [(NSString *)day drawAtPoint:CGPointMake(
        (width - daysize.width) / 2, (16 - daysize.height) / 2
    ) withStyle:daystyle];

    CFRelease(date);
    CFRelease(day);
}

/*static id UINavigationBarBackground$initWithFrame$withBarStyle$withTintColor$(UINavigationBarBackground<WinterBoard> *self, SEL sel, CGRect frame, int style, UIColor *tint) {
    _trace();

    if (NSNumber *number = [Info_ objectForKey:@"NavigationBarStyle"])
        style = [number intValue];

    if (UIColor *color = [Info_ colorForKey:@"NavigationBarTint"])
        tint = color;

    return [self wb_initWithFrame:frame withBarStyle:style withTintColor:tint];
}*/

/*static id UINavigationBar$initWithCoder$(SBAppWindow<WinterBoard> *self, SEL sel, CGRect frame, NSCoder *coder) {
    self = [self wb_initWithCoder:coder];
    if (self == nil)
        return nil;
    UINavigationBar$setBarStyle$_(self);
    return self;
}

static id UINavigationBar$initWithFrame$(SBAppWindow<WinterBoard> *self, SEL sel, CGRect frame) {
    self = [self wb_initWithFrame:frame];
    if (self == nil)
        return nil;
    UINavigationBar$setBarStyle$_(self);
    return self;
}*/

static void UIToolbar$setBarStyle$(UIToolbar<WinterBoard> *self, SEL sel, int style) {
    if ($setBarStyle$_(@"Toolbar", self, style))
        return;
    return [self wb_setBarStyle:style];
}

static void UINavigationBar$setBarStyle$(UINavigationBar<WinterBoard> *self, SEL sel, int style) {
    if ($setBarStyle$_(@"NavigationBar", self, style))
        return;
    return [self wb_setBarStyle:style];
}

static void $didMoveToSuperview(SBButtonBar<WinterBoard> *self, SEL sel) {
    [[self superview] setBackgroundColor:[$UIColor clearColor]];
    [self wb_didMoveToSuperview];
}

static id UIImage$imageAtPath$(NSObject<WinterBoard> *self, SEL sel, NSString *path) {
    return [self wb_imageAtPath:[path wb_themedPath]];
}

static id $initWithContentsOfFile$(NSObject<WinterBoard> *self, SEL sel, NSString *file) {
    return [self wb_initWithContentsOfFile:[file wb_themedPath]];
}

static id UIImage$initWithContentsOfFile$cache$(UIImage<WinterBoard> *self, SEL sel, NSString *file, BOOL cache) {
    return [self wb_initWithContentsOfFile:[file wb_themedPath] cache:cache];
}

static UIImage *UIImage$defaultDesktopImage$(UIImage<WinterBoard> *self, SEL sel) {
    if (Debug_)
        NSLog(@"WB:Debug:DefaultDesktopImage");
    if (NSString *path = $getTheme$([NSArray arrayWithObjects:@"LockBackground.png", @"LockBackground.jpg", nil]))
        return [$UIImage imageWithContentsOfFile:path];
    return [self wb_defaultDesktopImage];
}

static UIImageView *WallpaperImage_;
static UIWebDocumentView *WallpaperPage_;
static NSURL *WallpaperURL_;

static id SBContentLayer$initWithSize$(SBContentLayer<WinterBoard> *self, SEL sel, CGSize size) {
    self = [self wb_initWithSize:size];
    if (self == nil)
        return nil;

    if (NSString *path = $getTheme$([NSArray arrayWithObject:@"Wallpaper.mp4"])) {
        MPVideoView *video = [[[$MPVideoView alloc] initWithFrame:[self bounds]] autorelease];
        [video setMovieWithPath:path];
        [video setRepeatMode:1];
        [video setRepeatGap:0];
        [self addSubview:video];
        [video playFromBeginning];;
    }

    UIImage *image;
    if (NSString *path = $getTheme$([NSArray arrayWithObjects:@"Wallpaper.png", @"Wallpaper.jpg", nil])) {
        image = [[$UIImage alloc] wb_initWithContentsOfFile:path];
        if (image != nil)
            image = [image autorelease];
    } else image = nil;

    if (WallpaperImage_ != nil)
        [WallpaperImage_ release];
    WallpaperImage_ = [[$UIImageView alloc] initWithImage:image];
    [self addSubview:WallpaperImage_];

    if (NSString *path = $getTheme$([NSArray arrayWithObject:@"Wallpaper.html"])) {
        CGRect bounds = [self bounds];

        UIWebDocumentView *view([[[$UIWebDocumentView alloc] initWithFrame:bounds] autorelease]);
        [view setAutoresizes:true];

        if (WallpaperPage_ != nil)
            [WallpaperPage_ release];
        WallpaperPage_ = [view retain];

        if (WallpaperURL_ != nil)
            [WallpaperURL_ release];
        WallpaperURL_ = [[NSURL fileURLWithPath:path] retain];

        [WallpaperPage_ loadRequest:[NSURLRequest requestWithURL:WallpaperURL_]];

        [[view webView] setDrawsBackground:false];
        [view setBackgroundColor:[$UIColor clearColor]];

        [self addSubview:view];
    }

    return self;
}

static void SBSlidingAlertDisplay$updateDesktopImage$(SBSlidingAlertDisplay<WinterBoard> *self, SEL sel, UIImage *image) {
    NSString *path = $getTheme$([NSArray arrayWithObject:@"LockBackground.html"]);

    if (path) {
        UIView *background;
        object_getInstanceVariable(self, "_backgroundView", reinterpret_cast<void **>(&background));
        if (background != nil)
            path = nil;
    }

    [self wb_updateDesktopImage:image];

    if (path != nil) {
        CGRect bounds = [self bounds];

        UIWebDocumentView *view([[[$UIWebDocumentView alloc] initWithFrame:bounds] autorelease]);
        [view setAutoresizes:true];

        if (WallpaperPage_ != nil)
            [WallpaperPage_ release];
        WallpaperPage_ = [view retain];

        if (WallpaperURL_ != nil)
            [WallpaperURL_ release];
        WallpaperURL_ = [[NSURL fileURLWithPath:path] retain];

        [WallpaperPage_ loadRequest:[NSURLRequest requestWithURL:WallpaperURL_]];

        [[view webView] setDrawsBackground:false];
        [view setBackgroundColor:[$UIColor clearColor]];

        UIView *background;
        object_getInstanceVariable(self, "_backgroundView", reinterpret_cast<void **>(&background));
        NSLog(@"back:%@", background);

        [self insertSubview:view aboveSubview:background];
    }
}

static unsigned *__currentContextCount;
static void ***__currentContextStack;

/*extern "C" CGColorRef CGGStateGetSystemColor(void *);
extern "C" CGColorRef CGGStateGetFillColor(void *);
extern "C" CGColorRef CGGStateGetStrokeColor(void *);
extern "C" NSString *UIStyleStringFromColor(CGColorRef);*/

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
        object_getInstanceVariable(view_, "_mode", reinterpret_cast<void **>(&mode));

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

static void SBStatusBarController$setStatusBarMode$orientation$duration$fenceID$animation$(SBStatusBarController<WinterBoard> *self, SEL sel, int mode, int orientation, float duration, int id, int animation) {
    if (Debug_)
        NSLog(@"WB:Debug:setStatusBarMode:%d", mode);
    if (mode < 100) // 104:hidden 105:glowing
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
    object_getInstanceVariable(self, "_time", reinterpret_cast<void **>(&time));
    if (time != nil && [time class] != [WBTime class])
        object_setInstanceVariable(self, "_time", reinterpret_cast<void *>([[WBTime alloc] initWithTime:[time autorelease] view:self]));
    return [self wb_drawRect:rect];
}

static void SBIconController$appendIconList$(SBIconController<WinterBoard> *self, SEL sel, SBIconList *list) {
    if (Debug_)
        NSLog(@"appendIconList:%@", list);
    return [self wb_appendIconList:list];
}

static id SBIconLabel$initWithSize$label$(SBIconLabel<WinterBoard> *self, SEL sel, CGSize size, NSString *label) {
    self = [self wb_initWithSize:size label:label];
    if (self != nil)
        [self setClipsToBounds:NO];
    return self;
}

static void SBIconLabel$setInDock$(SBIconLabel<WinterBoard> *self, SEL sel, BOOL docked) {
    id label;
    object_getInstanceVariable(self, "_label", reinterpret_cast<void **>(&label));
    if (![Info_ boolForKey:@"UndockedIconLabels"])
        docked = true;
    if (label != nil && [label respondsToSelector:@selector(setInDock:)])
        [label setInDock:docked];
    return [self wb_setInDock:docked];
}

@class WebCoreFrameBridge;
static CGSize WebCoreFrameBridge$renderedSizeOfNode$constrainedToWidth$(WebCoreFrameBridge<WinterBoard> *self, SEL sel, id node, float width) {
    if (node == nil)
        return CGSizeZero;
    void **core(reinterpret_cast<void **>([node _node]));
    if (core == NULL || core[6] == NULL)
        return CGSizeZero;
    return [self wb_renderedSizeOfNode:node constrainedToWidth:width];
}

static void SBIconLabel$drawRect$(SBIconLabel<WinterBoard> *self, SEL sel, CGRect rect) {
    CGRect bounds = [self bounds];

    BOOL docked;
    object_getInstanceVariable(self, "_inDock", reinterpret_cast<void **>(&docked));
    docked = (docked & 0x1) != 0;

    NSString *label;
    object_getInstanceVariable(self, "_label", reinterpret_cast<void **>(&label));

    NSString *style = [NSString stringWithFormat:@""
        "font-family: Helvetica; "
        "font-weight: bold; "
        "font-size: 11px; "
        "color: %@; "
    "", docked ? @"white" : @"#b3b3b3"];

    if (docked)
        style = [style stringByAppendingString:@"text-shadow: rgba(0, 0, 0, 0.5) 0px -1px 0px; "];
    float max = 75, width = [label sizeWithStyle:style forWidth:320].width;
    if (width > max)
        style = [style stringByAppendingString:[NSString stringWithFormat:@"letter-spacing: -%f; ", ((width - max) / ([label length] - 1))]];
    if (NSString *custom = [Info_ objectForKey:(docked ? @"DockedIconLabelStyle" : @"UndockedIconLabelStyle")])
        style = [style stringByAppendingString:custom];

    CGSize size = [label sizeWithStyle:style forWidth:bounds.size.width];
    [label drawAtPoint:CGPointMake((bounds.size.width - size.width) / 2, 0) withStyle:style];
}

extern "C" void FindMappedImages(void);
extern "C" NSData *UIImagePNGRepresentation(UIImage *);

static UIImage *(*_UIImageAtPath)(NSString *name, NSBundle *path);
static CGImageRef *(*_UIImageRefAtPath)(NSString *path, bool cache, UIImageOrientation *orientation);
static UIImage *(*_UIImageWithName)(NSString *name);
static UIImage *(*_UIImageWithNameInDomain)(NSString *name, NSString *domain);
static NSBundle *(*_UIKitBundle)();
static void (*_UISharedImageInitialize)(bool);
static int (*_UISharedImageNameGetIdentifier)(NSString *);
static UIImage *(*_UISharedImageWithIdentifier)(int);

static UIImage *$_UIImageWithName(NSString *name) {
    int id(_UISharedImageNameGetIdentifier(name));
    if (Debug_)
        NSLog(@"WB:Debug: UIImageWithName(\"%@\", %d)", name, id);

    if (id == -1)
        return _UIImageAtPath(name, _UIKitBundle());
    else {
        NSNumber *key([NSNumber numberWithInt:id]);
        UIImage *image = [UIImages_ objectForKey:key];
        if (image != nil)
            return reinterpret_cast<id>(image) == [NSNull null] ? nil : image;
        if (NSString *path = $pathForFile$inBundle$(name, _UIKitBundle(), true)) {
            image = [[$UIImage alloc] wb_initWithContentsOfFile:path];
            if (image != nil)
                [image autorelease];
        }
        if (image == nil)
            image = _UISharedImageWithIdentifier(id);
        [UIImages_ setObject:(image == nil ? [NSNull null] : reinterpret_cast<id>(image)) forKey:key];
        return image;
    }
}

static UIImage *$_UIImageWithNameInDomain(NSString *name, NSString *domain) {
    NSString *key = [NSString stringWithFormat:@"D:%zu%@%@", [domain length], domain, name];
    UIImage *image = [PathImages_ objectForKey:key];
    if (image != nil)
        return reinterpret_cast<id>(image) == [NSNull null] ? nil : image;
    if (Debug_)
        NSLog(@"WB:Debug: UIImageWithNameInDomain(\"%@\", \"%@\")", name, domain);
    if (NSString *path = $getTheme$([NSArray arrayWithObject:[NSString stringWithFormat:@"Domains/%@/%@", domain, name]])) {
        image = [[$UIImage alloc] wb_initWithContentsOfFile:path];
        if (image != nil)
            [image autorelease];
    }
    if (image == nil)
        image = _UIImageWithNameInDomain(name, domain);
    [PathImages_ setObject:(image == nil ? [NSNull null] : reinterpret_cast<id>(image)) forKey:key];
    return image;
}

template <typename Type_>
static void WBReplace(Type_ *symbol, Type_ *replace) {
    return WBReplace(symbol, replace, static_cast<Type_ **>(NULL));
}

#define AudioToolbox "/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox"
#define UIKit "/System/Library/Frameworks/UIKit.framework/UIKit"

/*static void UIWebDocumentView$setViewportSize$forDocumentTypes$(UIWebDocumentView *self, SEL sel, CGSize size, int type) {
    NSLog(@"WB:Examine: %f:%f:%u", size.width, size.height, type);
}*/

static bool (*_Z24GetFileNameForThisActionmPcRb)(unsigned long, char *, bool &);

static bool $_Z24GetFileNameForThisActionmPcRb(unsigned long a0, char *a1, bool &a2) {
    bool value = _Z24GetFileNameForThisActionmPcRb(a0, a1, a2);
    if (Debug_)
        NSLog(@"WB:Debug:GetFileNameForThisAction(%u, %s, %u) = %u", a0, value ? a1 : NULL, a2, value);

    if (value) {
        NSString *path = [NSString stringWithUTF8String:a1];
        if ([path hasPrefix:@"/System/Library/Audio/UISounds/"]) {
            NSString *file = [path substringFromIndex:31];
            NSLog(@"%@", file);
            for (NSString *theme in themes_) {
                NSString *path([NSString stringWithFormat:@"%@/UISounds/%@", theme, file]);
                if ([Manager_ fileExistsAtPath:path]) {
                    strcpy(a1, [path UTF8String]);
                    continue;
                }
            }
        }
    }
    return value;
}

static void ChangeWallpaper(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef info
) {
    if (Debug_)
        NSLog(@"WB:Debug:ChangeWallpaper!");

    UIImage *image;
    if (NSString *path = $getTheme$([NSArray arrayWithObjects:@"Wallpaper.png", @"Wallpaper.jpg", nil])) {
        image = [[$UIImage alloc] wb_initWithContentsOfFile:path];
        if (image != nil)
            image = [image autorelease];
    } else image = nil;

    if (WallpaperImage_ != nil)
        [WallpaperImage_ setImage:image];
    if (WallpaperPage_ != nil)
        [WallpaperPage_ loadRequest:[NSURLRequest requestWithURL:WallpaperURL_]];

}

void WBRename(bool instance, const char *name, SEL sel, IMP imp) {
    Class _class = objc_getClass(name);
    if (_class == nil) {
        if (Debug_)
            NSLog(@"WB:Warning: cannot find class [%s]", name);
        return;
    }
    if (!instance)
        _class = object_getClass(_class);
    MSHookMessage(_class, sel, imp, "wb_");
}

extern "C" void WBInitialize() {
    if (dlopen(UIKit, RTLD_LAZY | RTLD_NOLOAD) == NULL)
        return;
    NSLog(@"WB:Notice: Installing WinterBoard...");

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSBundle *MediaPlayer = [NSBundle bundleWithPath:@"/System/Library/Frameworks/MediaPlayer.framework"];
    if (MediaPlayer != nil)
        [MediaPlayer load];

    $MPVideoView = objc_getClass("MPVideoView");

    $UIColor = objc_getClass("UIColor");
    $UIImage = objc_getClass("UIImage");
    $UIImageView = objc_getClass("UIImageView");
    $UIWebDocumentView = objc_getClass("UIWebDocumentView");

    struct nlist nl[12];
    memset(nl, 0, sizeof(nl));

    nl[0].n_un.n_name = (char *) "___currentContextCount";
    nl[1].n_un.n_name = (char *) "___currentContextStack";
    nl[2].n_un.n_name = (char *) "___mappedImages";
    nl[3].n_un.n_name = (char *) "__UIImageAtPath";
    nl[4].n_un.n_name = (char *) "__UIImageRefAtPath";
    nl[5].n_un.n_name = (char *) "__UIImageWithName";
    nl[6].n_un.n_name = (char *) "__UIImageWithNameInDomain";
    nl[7].n_un.n_name = (char *) "__UIKitBundle";
    nl[8].n_un.n_name = (char *) "__UISharedImageInitialize";
    nl[9].n_un.n_name = (char *) "__UISharedImageNameGetIdentifier";
    nl[10].n_un.n_name = (char *) "__UISharedImageWithIdentifier";

    nlist(UIKit, nl);

    __currentContextCount = (unsigned *) nl[0].n_value;
    __currentContextStack = (void ***) nl[1].n_value;
    __mappedImages = (id *) nl[2].n_value;
    _UIImageAtPath = (UIImage *(*)(NSString *, NSBundle *)) nl[3].n_value;
    _UIImageRefAtPath = (CGImageRef *(*)(NSString *, bool, UIImageOrientation *)) nl[4].n_value;
    _UIImageWithName = (UIImage *(*)(NSString *)) nl[5].n_value;
    _UIImageWithNameInDomain = (UIImage *(*)(NSString *, NSString *)) nl[6].n_value;
    _UIKitBundle = (NSBundle *(*)()) nl[7].n_value;
    _UISharedImageInitialize = (void (*)(bool)) nl[8].n_value;
    _UISharedImageNameGetIdentifier = (int (*)(NSString *)) nl[9].n_value;
    _UISharedImageWithIdentifier = (UIImage *(*)(int)) nl[10].n_value;

    MSHookFunction(_UIImageWithName, &$_UIImageWithName, &_UIImageWithName);
    MSHookFunction(_UIImageWithNameInDomain, &$_UIImageWithNameInDomain, &_UIImageWithNameInDomain);

    if (dlopen(AudioToolbox, RTLD_LAZY | RTLD_NOLOAD) != NULL) {
        struct nlist nl[2];
        memset(nl, 0, sizeof(nl));
        nl[0].n_un.n_name = (char *) "__Z24GetFileNameForThisActionmPcRb";
        nlist(AudioToolbox, nl);
        _Z24GetFileNameForThisActionmPcRb = (bool (*)(unsigned long, char *, bool &)) nl[0].n_value;
        MSHookFunction(_Z24GetFileNameForThisActionmPcRb, &$_Z24GetFileNameForThisActionmPcRb, &_Z24GetFileNameForThisActionmPcRb);
    }

    WBRename(false, "UIImage", @selector(applicationImageNamed:), (IMP) &UIImage$applicationImageNamed$);
    WBRename(false, "UIImage", @selector(defaultDesktopImage), (IMP) &UIImage$defaultDesktopImage$);
    WBRename(false, "UIImage", @selector(imageAtPath:), (IMP) &UIImage$imageAtPath$);
    WBRename(false, "UIImage", @selector(imageNamed:), (IMP) &UIImage$imageNamed$);
    WBRename(false, "UIImage", @selector(imageNamed:inBundle:), (IMP) &UIImage$imageNamed$inBundle$);

    //WBRename("UINavigationBar", @selector(initWithCoder:", (IMP) &UINavigationBar$initWithCoder$);
    //WBRename("UINavigationBarBackground", @selector(initWithFrame:withBarStyle:withTintColor:", (IMP) &UINavigationBarBackground$initWithFrame$withBarStyle$withTintColor$);
    //WBRename(true, "SBStatusBar", @selector(initWithMode:orientation:", (IMP) &SBStatusBar$initWithMode$orientation$);
    //WBRename(true, "UIWebDocumentView", @selector(setViewportSize:forDocumentTypes:", (IMP) &UIWebDocumentView$setViewportSize$forDocumentTypes$);

    WBRename(true, "NSBundle", @selector(bundlePath), (IMP) &NSBundle$bundlePath$);
    WBRename(true, "NSBundle", @selector(pathForResource:ofType:), (IMP) &NSBundle$pathForResource$ofType$);

    WBRename(true, "UIImage", @selector(initWithContentsOfFile:), (IMP) &$initWithContentsOfFile$);
    WBRename(true, "UIImage", @selector(initWithContentsOfFile:cache:), (IMP) &UIImage$initWithContentsOfFile$cache$);
    WBRename(true, "UINavigationBar", @selector(setBarStyle:), (IMP) &UINavigationBar$setBarStyle$);
    WBRename(true, "UIToolbar", @selector(setBarStyle:), (IMP) &UIToolbar$setBarStyle$);

    WBRename(true, "WebCoreFrameBridge", @selector(renderedSizeOfNode:constrainedToWidth:), (IMP) &WebCoreFrameBridge$renderedSizeOfNode$constrainedToWidth$);

    WBRename(true, "SBApplication", @selector(pathForIcon), (IMP) &SBApplication$pathForIcon);
    WBRename(true, "SBApplicationIcon", @selector(icon), (IMP) &SBApplicationIcon$icon);
    WBRename(true, "SBBookmarkIcon", @selector(icon), (IMP) &SBBookmarkIcon$icon);
    WBRename(true, "SBButtonBar", @selector(didMoveToSuperview), (IMP) &$didMoveToSuperview);
    WBRename(true, "SBCalendarIconContentsView", @selector(drawRect:), (IMP) &SBCalendarIconContentsView$drawRect$);
    WBRename(true, "SBContentLayer", @selector(initWithSize:), (IMP) &SBContentLayer$initWithSize$);
    WBRename(true, "SBIconLabel", @selector(initWithSize:label:), (IMP) &SBIconLabel$initWithSize$label$);
    WBRename(true, "SBIconLabel", @selector(setInDock:), (IMP) &SBIconLabel$setInDock$);
    WBRename(true, "SBIconLabel", @selector(drawRect:), (IMP) &SBIconLabel$drawRect$);
    WBRename(true, "SBSlidingAlertDisplay", @selector(updateDesktopImage:), (IMP) &SBSlidingAlertDisplay$updateDesktopImage$);
    WBRename(true, "SBStatusBarContentsView", @selector(didMoveToSuperview), (IMP) &$didMoveToSuperview);
    WBRename(true, "SBStatusBarContentsView", @selector(initWithStatusBar:mode:), (IMP) &SBStatusBarContentsView$initWithStatusBar$mode$);
    WBRename(true, "SBStatusBarController", @selector(setStatusBarMode:orientation:duration:fenceID:animation:), (IMP) &SBStatusBarController$setStatusBarMode$orientation$duration$fenceID$animation$);
    WBRename(true, "SBStatusBarTimeView", @selector(drawRect:), (IMP) &SBStatusBarTimeView$drawRect$);
    WBRename(true, "SBIconController", @selector(appendIconList:), (IMP) &SBIconController$appendIconList$);

    _UISharedImageInitialize(false);

    English_ = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/English.lproj/LocalizedApplicationNames.strings"];
    if (English_ != nil)
        English_ = [English_ retain];

    Manager_ = [[NSFileManager defaultManager] retain];
    UIImages_ = [[NSMutableDictionary alloc] initWithCapacity:16];
    PathImages_ = [[NSMutableDictionary alloc] initWithCapacity:16];
    Files_ = [[NSMutableDictionary alloc] initWithCapacity:16];

    themes_ = [[NSMutableArray alloc] initWithCapacity:8];

    if (NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"/User/Library/Preferences/com.saurik.WinterBoard.plist"]]) {
        [settings autorelease];

        if (NSNumber *debug = [settings objectForKey:@"Debug"])
            Debug_ = [debug boolValue];

        NSArray *themes = [settings objectForKey:@"Themes"];
        if (themes == nil)
            if (NSString *theme = [settings objectForKey:@"Theme"])
                themes = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
                    theme, @"Name",
                    [NSNumber numberWithBool:true], @"Active",
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

                #define testForTheme(format...) \
                    if (theme == nil) { \
                        NSString *path = [NSString stringWithFormat:format]; \
                        if ([Manager_ fileExistsAtPath:path]) { \
                            [themes_ addObject:path]; \
                            continue; \
                        } \
                    }

                testForTheme(@"/Library/Themes/%@.theme", name)
                testForTheme(@"/Library/Themes/%@", name)
                testForTheme(@"%@/Library/SummerBoard/Themes/%@", NSHomeDirectory(), name)
            }
    }

    Info_ = [[NSMutableDictionary dictionaryWithCapacity:16] retain];

    for (NSString *theme in themes_)
        if (NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Info.plist", theme]])
            for (NSString *key in [info allKeys])
                if ([Info_ objectForKey:key] == nil)
                    [Info_ setObject:[info objectForKey:key] forKey:key];

    if (objc_getClass("SpringBoard") != nil)
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, &ChangeWallpaper, (CFStringRef) @"com.saurik.winterboard.lockbackground", NULL, 0
        );

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
