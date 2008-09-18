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

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#include <substrate.h>

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

@protocol WinterBoard
- (NSString *) wb$localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)table;
- (id) wb$initWithBadge:(id)badge;
- (void) wb$cacheImageForIcon:(SBIcon *)icon;
- (UIImage *) wb$getCachedImagedForIcon:(SBIcon *)icon;
- (CGSize) wb$renderedSizeOfNode:(id)node constrainedToWidth:(float)width;
- (void *) _node;
- (void) wb$updateDesktopImage:(UIImage *)image;
- (UIImage *) wb$defaultDesktopImage;
- (NSString *) wb$pathForIcon;
- (NSString *) wb$pathForResource:(NSString *)resource ofType:(NSString *)type;
- (id) wb$init;
- (id) wb$layer;
- (id) wb$initWithSize:(CGSize)size;
- (id) wb$initWithSize:(CGSize)size label:(NSString *)label;
- (id) wb$initWithFrame:(CGRect)frame;
- (id) wb$initWithCoder:(NSCoder *)coder;
- (void) wb$setFrame:(CGRect)frame;
- (void) wb$drawRect:(CGRect)rect;
- (void) wb$setBackgroundColor:(id)color;
- (void) wb$setAlpha:(float)value;
- (void) wb$setBarStyle:(int)style;
- (id) wb$initWithFrame:(CGRect)frame withBarStyle:(int)style withTintColor:(UIColor *)color;
- (void) wb$setOpaque:(BOOL)opaque;
- (void) wb$setInDock:(BOOL)docked;
- (void) wb$didMoveToSuperview;
+ (UIImage *) wb$imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
+ (UIImage *) wb$applicationImageNamed:(NSString *)name;
- (NSDictionary *) wb$infoDictionary;
- (UIImage *) wb$icon;
- (void) wb$appendIconList:(SBIconList *)list;
- (id) wb$initWithStatusBar:(id)bar mode:(int)mode;
- (id) wb$initWithMode:(int)mode orientation:(int)orientation;
- (id) wb$imageAtPath:(NSString *)path;
- (id) wb$initWithContentsOfFile:(NSString *)file;
- (id) wb$initWithContentsOfFile:(NSString *)file cache:(BOOL)cache;
- (void) wb$setStatusBarMode:(int)mode orientation:(int)orientation duration:(float)duration fenceID:(int)id animation:(int)animation;
@end

static NSMutableDictionary *UIImages_;
static NSMutableDictionary *PathImages_;

static NSFileManager *Manager_;
static NSDictionary *English_;
static NSMutableDictionary *Info_;
static NSMutableArray *themes_;

static NSString *$getTheme$(NSArray *files) {
    if (Debug_)
        NSLog(@"WB:Debug: %@", [files description]);

    for (NSString *theme in themes_)
        for (NSString *file in files) {
            NSString *path([NSString stringWithFormat:@"%@/%@", theme, file]);
            if ([Manager_ fileExistsAtPath:path])
                return path;
        }

    return nil;
}

static NSString *$pathForIcon$(SBApplication<WinterBoard> *self) {
    NSString *identifier = [self bundleIdentifier];
    NSString *path = [self path];
    NSString *folder = [path lastPathComponent];
    NSString *dname = [self displayName];
    NSString *didentifier = [self displayIdentifier];

    if (Debug_)
        NSLog(@"WB:Debug: [SBApplication(%@:%@:%@:%@) pathForIcon]", identifier, folder, dname, didentifier);

    NSMutableArray *names = [NSMutableArray arrayWithCapacity:8];

    if (identifier != nil)
        [names addObject:[NSString stringWithFormat:@"Bundles/%@/icon.png", identifier]];
    if (folder != nil)
        [names addObject:[NSString stringWithFormat:@"Folders/%@/icon.png", folder]];

    #define testForIcon(Name) \
        if (NSString *name = Name) \
            [names addObject:[NSString stringWithFormat:@"Icons/%@.png", name]];

    testForIcon(identifier);
    testForIcon(dname);

    if (didentifier != nil) {
        testForIcon([English_ objectForKey:didentifier]);

        NSArray *parts = [didentifier componentsSeparatedByString:@"-"];
        if ([parts count] != 1)
            if (NSDictionary *english = [[[NSDictionary alloc] initWithContentsOfFile:[path stringByAppendingString:@"/English.lproj/UIRoleDisplayNames.strings"]] autorelease])
                testForIcon([english objectForKey:[parts lastObject]]);
    }

    if (NSString *path = $getTheme$(names))
        return path;
    return nil;
}

static NSMutableDictionary *Cache_;

static void SBIconModel$cacheImageForIcon$(SBIconModel<WinterBoard> *self, SEL sel, SBIcon *icon) {
    [self wb$cacheImageForIcon:icon];
    NSString *key([icon displayIdentifier]);

    if (UIImage *image = [icon icon]) {
        CGColorSpaceRef space(CGColorSpaceCreateDeviceRGB());
        CGRect rect = {CGPointMake(1, 1), [image size]};
        CGSize size = {rect.size.width + 2, rect.size.height + 2};

        CGContextRef context(CGBitmapContextCreate(NULL, size.width, size.height, 8, 4 * size.width, space, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst));
        CGColorSpaceRelease(space);

        CGContextDrawImage(context, rect, [image CGImage]);
        CGImageRef ref(CGBitmapContextCreateImage(context));
        CGContextRelease(context);

        UIImage *image([UIImage imageWithCGImage:ref]);
        CGImageRelease(ref);

        [Cache_ setObject:image forKey:key];
    }
}

static UIImage *SBIconModel$getCachedImagedForIcon$(SBIconModel<WinterBoard> *self, SEL sel, SBIcon *icon) {
    NSString *key([icon displayIdentifier]);
    if (UIImage *image = [Cache_ objectForKey:key])
        return image;
    else
        return [self wb$getCachedImagedForIcon:icon];
}

static UIImage *SBApplicationIcon$icon(SBApplicationIcon<WinterBoard> *self, SEL sel) {
    if (![Info_ boolForKey:@"ComposeStoreIcons"])
        if (NSString *path = $pathForIcon$([self application]))
            return [UIImage imageWithContentsOfFile:path];
    return [self wb$icon];
}

static UIImage *SBBookmarkIcon$icon(SBBookmarkIcon<WinterBoard> *self, SEL sel) {
    if (Debug_)
        NSLog(@"WB:Debug:Bookmark(%@:%@)", [self displayIdentifier], [self displayName]);
    if (NSString *path = $getTheme$([NSArray arrayWithObject:[NSString stringWithFormat:@"Icons/%@.png", [self displayName]]]))
        return [UIImage imageWithContentsOfFile:path];
    return [self wb$icon];
}

static NSString *SBApplication$pathForIcon(SBApplication<WinterBoard> *self, SEL sel) {
    if (NSString *path = $pathForIcon$(self))
        return path;
    return [self wb$pathForIcon];
}

static NSString *$pathForFile$inBundle$(NSString *file, NSBundle<WinterBoard> *bundle, bool ui) {
    NSString *identifier = [bundle bundleIdentifier];
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:8];

    if (identifier != nil)
        [names addObject:[NSString stringWithFormat:@"Bundles/%@/%@", identifier, file]];
    if (NSString *folder = [[bundle bundlePath] lastPathComponent])
        [names addObject:[NSString stringWithFormat:@"Folders/%@/%@", folder, file]];
    if (ui)
        [names addObject:[NSString stringWithFormat:@"UIImages/%@", file]];

    #define remapResourceName(oldname, newname) \
        else if ([file isEqualToString:oldname]) \
            [names addObject:[NSString stringWithFormat:@"%@.png", newname]]; \

    if (identifier == nil);
    else if ([identifier isEqualToString:@"com.apple.calculator"])
        [names addObject:[NSString stringWithFormat:@"Files/Applications/Calculator.app/%@", file]];
    else if (![identifier isEqualToString:@"com.apple.springboard"]);
        remapResourceName(@"FSO_BG.png", @"StatusBar")
        remapResourceName(@"SBDockBG.png", @"Dock")
        remapResourceName(@"SBWeatherCelsius.png", @"Icons/Weather")

    if (NSString *path = $getTheme$(names))
        return path;
    return nil;
}

static UIImage *CachedImageAtPath(NSString *path) {
    UIImage *image = [PathImages_ objectForKey:path];
    if (image != nil)
        return reinterpret_cast<id>(image) == [NSNull null] ? nil : image;
    image = [[UIImage alloc] wb$initWithContentsOfFile:path cache:true];
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
        image = [self wb$imageNamed:name inBundle:bundle];
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
    return [self wb$applicationImageNamed:name];
}

@interface NSString (WinterBoard)
- (NSString *) wb$themedPath;
@end

@implementation NSString (WinterBoard)

- (NSString *) wb$themedPath {
    if (Debug_)
        NSLog(@"WB:Debug:Bypass(\"%@\")", self);

    if (NSBundle *bundle = [NSBundle mainBundle]) {
        NSString *prefix([bundle bundlePath]);
        if ([self hasPrefix:prefix]) {
            NSUInteger length([prefix length]);
            if (length != [self length])
                if (NSString *path = $pathForFile$inBundle$([self substringFromIndex:(length + 1)], bundle, false))
                    return path;
        }
    }

    return self;
}

@end

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

static NSString *NSBundle$pathForResource$ofType$(NSBundle<WinterBoard> *self, SEL sel, NSString *resource, NSString *type) {
    NSString *file = type == nil ? resource : [NSString stringWithFormat:@"%@.%@", resource, type];
    if (Debug_)
        NSLog(@"WB:Debug: [NSBundle(%@) pathForResource:\"%@\"]", [self bundleIdentifier], file);
    if (NSString *path = $pathForFile$inBundle$(file, self, false))
        return path;
    return [self wb$pathForResource:resource ofType:type];
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
        [self wb$setBarStyle:style];
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
        (width - datesize.width) / 2, (71 - datesize.height) / 2
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

    return [self wb$initWithFrame:frame withBarStyle:style withTintColor:tint];
}*/

/*static id UINavigationBar$initWithCoder$(SBAppWindow<WinterBoard> *self, SEL sel, CGRect frame, NSCoder *coder) {
    self = [self wb$initWithCoder:coder];
    if (self == nil)
        return nil;
    UINavigationBar$setBarStyle$_(self);
    return self;
}

static id UINavigationBar$initWithFrame$(SBAppWindow<WinterBoard> *self, SEL sel, CGRect frame) {
    self = [self wb$initWithFrame:frame];
    if (self == nil)
        return nil;
    UINavigationBar$setBarStyle$_(self);
    return self;
}*/

static void UIToolbar$setBarStyle$(UIToolbar<WinterBoard> *self, SEL sel, int style) {
    if ($setBarStyle$_(@"Toolbar", self, style))
        return;
    return [self wb$setBarStyle:style];
}

static void UINavigationBar$setBarStyle$(UINavigationBar<WinterBoard> *self, SEL sel, int style) {
    if ($setBarStyle$_(@"NavigationBar", self, style))
        return;
    return [self wb$setBarStyle:style];
}

static void $didMoveToSuperview(SBButtonBar<WinterBoard> *self, SEL sel) {
    [[self superview] setBackgroundColor:[UIColor clearColor]];
    [self wb$didMoveToSuperview];
}

static id UIImage$imageAtPath$(NSObject<WinterBoard> *self, SEL sel, NSString *path) {
    return [self wb$imageAtPath:[path wb$themedPath]];
}

static id $initWithContentsOfFile$(NSObject<WinterBoard> *self, SEL sel, NSString *file) {
    return [self wb$initWithContentsOfFile:[file wb$themedPath]];
}

static id UIImage$initWithContentsOfFile$cache$(UIImage<WinterBoard> *self, SEL sel, NSString *file, BOOL cache) {
    return [self wb$initWithContentsOfFile:[file wb$themedPath] cache:cache];
}

static UIImage *UIImage$defaultDesktopImage$(UIImage<WinterBoard> *self, SEL sel) {
    if (Debug_)
        NSLog(@"WB:Debug:DefaultDesktopImage");
    if (NSString *path = $getTheme$([NSArray arrayWithObjects:@"LockBackground.png", @"LockBackground.jpg", nil]))
        return [UIImage imageWithContentsOfFile:path];
    return [self wb$defaultDesktopImage];
}

static UIImageView *WallpaperImage_;
static UIWebDocumentView *WallpaperPage_;
static NSURL *WallpaperURL_;

static id SBContentLayer$initWithSize$(SBContentLayer<WinterBoard> *self, SEL sel, CGSize size) {
    self = [self wb$initWithSize:size];
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
        image = [[UIImage alloc] wb$initWithContentsOfFile:path];
        if (image != nil)
            image = [image autorelease];
    } else image = nil;

    if (WallpaperImage_ != nil)
        [WallpaperImage_ release];
    WallpaperImage_ = [[UIImageView alloc] initWithImage:image];
    [self addSubview:WallpaperImage_];

    if (NSString *path = $getTheme$([NSArray arrayWithObject:@"Wallpaper.html"])) {
        CGRect bounds = [self bounds];

        UIWebDocumentView *view([[[UIWebDocumentView alloc] initWithFrame:bounds] autorelease]);
        [view setAutoresizes:true];

        if (WallpaperPage_ != nil)
            [WallpaperPage_ release];
        WallpaperPage_ = [view retain];

        if (WallpaperURL_ != nil)
            [WallpaperURL_ release];
        WallpaperURL_ = [[NSURL fileURLWithPath:path] retain];

        [WallpaperPage_ loadRequest:[NSURLRequest requestWithURL:WallpaperURL_]];

        [[view webView] setDrawsBackground:false];
        [view setBackgroundColor:[UIColor clearColor]];

        [self addSubview:view];
    }

    return self;
}

static void SBSlidingAlertDisplay$updateDesktopImage$(SBSlidingAlertDisplay<WinterBoard> *self, SEL sel, UIImage *image) {
    NSString *path = $getTheme$([NSArray arrayWithObject:@"LockBackground.html"]);
    UIView *&_backgroundView(MSHookIvar<UIView *>(self, "_backgroundView"));

    if (path != nil && _backgroundView != nil)
        path = nil;

    [self wb$updateDesktopImage:image];

    if (path != nil) {
        CGRect bounds = [self bounds];

        UIWebDocumentView *view([[[UIWebDocumentView alloc] initWithFrame:bounds] autorelease]);
        [view setAutoresizes:true];

        if (WallpaperPage_ != nil)
            [WallpaperPage_ release];
        WallpaperPage_ = [view retain];

        if (WallpaperURL_ != nil)
            [WallpaperURL_ release];
        WallpaperURL_ = [[NSURL fileURLWithPath:path] retain];

        [WallpaperPage_ loadRequest:[NSURLRequest requestWithURL:WallpaperURL_]];

        [[view webView] setDrawsBackground:false];
        [view setBackgroundColor:[UIColor clearColor]];

        [self insertSubview:view aboveSubview:_backgroundView];
    }
}

/*extern "C" CGColorRef CGGStateGetSystemColor(void *);
extern "C" CGColorRef CGGStateGetFillColor(void *);
extern "C" CGColorRef CGGStateGetStrokeColor(void *);
extern "C" NSString *UIStyleStringFromColor(CGColorRef);*/

/* WBTimeLabel {{{ */
@interface WBTimeLabel : NSProxy {
    NSString *time_;
    _transient SBStatusBarTimeView *view_;
}

- (id) initWithTime:(NSString *)time view:(SBStatusBarTimeView *)view;

@end

@implementation WBTimeLabel

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
        BOOL &_mode(MSHookIvar<BOOL>(view_, "_mode"));;

        [time_ drawAtPoint:point withStyle:[NSString stringWithFormat:@""
            "font-family: Helvetica; "
            "font-weight: bold; "
            "font-size: 14px; "
            "color: %@; "
        "%@", _mode ? @"white" : @"black", custom]];

        return CGSizeZero;
    }

    return [time_ drawAtPoint:point forWidth:width withFont:font lineBreakMode:mode];
}

@end
/* }}} */
/* WBBadgeLabel {{{ */
@interface WBBadgeLabel : NSProxy {
    NSString *badge_;
}

- (id) initWithBadge:(NSString *)badge;

@end

@implementation WBBadgeLabel

- (void) dealloc {
    [badge_ release];
    [super dealloc];
}

- (id) initWithBadge:(NSString *)badge {
    badge_ = [badge retain];
    return self;
}

WBDelegate(badge_)

- (CGSize) drawAtPoint:(CGPoint)point forWidth:(float)width withFont:(UIFont *)font lineBreakMode:(int)mode {
    if (NSString *custom = [Info_ objectForKey:@"BadgeStyle"]) {
        [badge_ drawAtPoint:point withStyle:[NSString stringWithFormat:@""
            "font-family: Helvetica; "
            "font-weight: bold; "
            "font-size: 17px; "
            "color: white; "
        "%@", custom]];

        return CGSizeZero;
    }

    return [badge_ drawAtPoint:point forWidth:width withFont:font lineBreakMode:mode];
}

@end
/* }}} */

static id SBIconBadge$initWithBadge$(SBIconBadge<WinterBoard> *self, SEL sel, NSString *badge) {
    if ((self = [self wb$initWithBadge:badge]) != nil) {
        id &_badge(MSHookIvar<id>(self, "_badge"));
        if (_badge != nil)
            if (id label = [[WBBadgeLabel alloc] initWithBadge:[_badge autorelease]])
                _badge = label;
    } return self;
}

static void SBStatusBarController$setStatusBarMode$orientation$duration$fenceID$animation$(SBStatusBarController<WinterBoard> *self, SEL sel, int mode, int orientation, float duration, int id, int animation) {
    if (Debug_)
        NSLog(@"WB:Debug:setStatusBarMode:%d", mode);
    if (mode < 100) // 104:hidden 105:glowing
        if (NSNumber *number = [Info_ objectForKey:@"StatusBarMode"])
            mode = [number intValue];
    return [self wb$setStatusBarMode:mode orientation:orientation duration:duration fenceID:id animation:animation];
}

static id SBStatusBarContentsView$initWithStatusBar$mode$(SBStatusBarContentsView<WinterBoard> *self, SEL sel, id bar, int mode) {
    if (NSNumber *number = [Info_ objectForKey:@"StatusBarContentsMode"])
        mode = [number intValue];
    return [self wb$initWithStatusBar:bar mode:mode];
}

static void SBStatusBarTimeView$drawRect$(SBStatusBarTimeView<WinterBoard> *self, SEL sel, CGRect rect) {
    id &_time(MSHookIvar<id>(self, "_time"));
    if (_time != nil && [_time class] != [WBTimeLabel class])
        object_setInstanceVariable(self, "_time", reinterpret_cast<void *>([[WBTimeLabel alloc] initWithTime:[_time autorelease] view:self]));
    return [self wb$drawRect:rect];
}

static void SBIconController$appendIconList$(SBIconController<WinterBoard> *self, SEL sel, SBIconList *list) {
    if (Debug_)
        NSLog(@"appendIconList:%@", list);
    return [self wb$appendIconList:list];
}

static id SBIconLabel$initWithSize$label$(SBIconLabel<WinterBoard> *self, SEL sel, CGSize size, NSString *label) {
    self = [self wb$initWithSize:size label:label];
    if (self != nil)
        [self setClipsToBounds:NO];
    return self;
}

static void SBIconLabel$setInDock$(SBIconLabel<WinterBoard> *self, SEL sel, BOOL docked) {
    id &_label(MSHookIvar<id>(self, "_label"));
    if (![Info_ boolForKey:@"UndockedIconLabels"])
        docked = true;
    if (_label != nil && [_label respondsToSelector:@selector(setInDock:)])
        [_label setInDock:docked];
    return [self wb$setInDock:docked];
}

static NSMutableDictionary *Strings_;

static NSString *NSBundle$localizedStringForKey$value$table$(NSBundle<WinterBoard> *self, SEL sel, NSString *key, NSString *value, NSString *table) {
    NSString *identifier = [self bundleIdentifier];
    NSLocale *locale = [NSLocale currentLocale];
    NSString *language = [locale objectForKey:NSLocaleLanguageCode];
    if (Debug_)
        NSLog(@"WB:Debug:[NSBundle(%@) localizedStringForKey:\"%@\" value:\"%@\" table:\"%@\"] (%@)", identifier, key, value, table, language);
    NSString *file = table == nil ? @"Localizable" : table;
    NSString *name = [NSString stringWithFormat:@"%@:%@", identifier, file];
    NSDictionary *strings;
    if ((strings = [Strings_ objectForKey:name]) != nil) {
        if (static_cast<id>(strings) != [NSNull null]) strings:
            if (NSString *value = [strings objectForKey:key])
                return value;
    } else if (NSString *path = $pathForFile$inBundle$([NSString stringWithFormat:@"%@.lproj/%@.strings",
        language, file
    ], self, false)) {
        if ((strings = [[NSDictionary alloc] initWithContentsOfFile:path]) != nil) {
            [Strings_ setObject:[strings autorelease] forKey:name];
            goto strings;
        } else goto null;
    } else null:
        [Strings_ setObject:[NSNull null] forKey:name];
    return [self wb$localizedStringForKey:key value:value table:table];
}

@class WebCoreFrameBridge;
static CGSize WebCoreFrameBridge$renderedSizeOfNode$constrainedToWidth$(WebCoreFrameBridge<WinterBoard> *self, SEL sel, id node, float width) {
    if (node == nil)
        return CGSizeZero;
    void **core(reinterpret_cast<void **>([node _node]));
    if (core == NULL || core[6] == NULL)
        return CGSizeZero;
    return [self wb$renderedSizeOfNode:node constrainedToWidth:width];
}

static void SBIconLabel$drawRect$(SBIconLabel<WinterBoard> *self, SEL sel, CGRect rect) {
    CGRect bounds = [self bounds];

    static Ivar drawMoreLegibly = object_getInstanceVariable(self, "_drawMoreLegibly", NULL);

    BOOL docked;
    Ivar ivar = object_getInstanceVariable(self, "_inDock", reinterpret_cast<void **>(&docked));
    docked = (docked & (ivar_getOffset(ivar) == ivar_getOffset(drawMoreLegibly) ? 0x2 : 0x1)) != 0;

    NSString *&label(MSHookIvar<NSString *>(self, "_label"));

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

//static CGImageRef *(*_UIImageRefAtPath)(NSString *path, bool cache, UIImageOrientation *orientation);
//_UIImageRefAtPath = (CGImageRef *(*)(NSString *, bool, UIImageOrientation *)) nl[3].n_value;

static UIImage *(*_UIImageAtPath)(NSString *name, NSBundle *path);
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
            image = [[UIImage alloc] wb$initWithContentsOfFile:path];
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
        image = [[UIImage alloc] wb$initWithContentsOfFile:path];
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
        image = [[UIImage alloc] wb$initWithContentsOfFile:path];
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
    MSHookMessage(_class, sel, imp, "wb$");
}

extern "C" void WBInitialize() {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *identifier([[NSBundle mainBundle] bundleIdentifier]);

    NSLog(@"WB:Notice: WinterBoard");

    struct nlist nl[8];
    memset(nl, 0, sizeof(nl));

    nl[0].n_un.n_name = (char *) "__UIImageAtPath";
    nl[1].n_un.n_name = (char *) "__UIImageWithName";
    nl[2].n_un.n_name = (char *) "__UIImageWithNameInDomain";
    nl[3].n_un.n_name = (char *) "__UIKitBundle";
    nl[4].n_un.n_name = (char *) "__UISharedImageInitialize";
    nl[5].n_un.n_name = (char *) "__UISharedImageNameGetIdentifier";
    nl[6].n_un.n_name = (char *) "__UISharedImageWithIdentifier";

    nlist(UIKit, nl);

    _UIImageAtPath = (UIImage *(*)(NSString *, NSBundle *)) nl[0].n_value;
    _UIImageWithName = (UIImage *(*)(NSString *)) nl[1].n_value;
    _UIImageWithNameInDomain = (UIImage *(*)(NSString *, NSString *)) nl[2].n_value;
    _UIKitBundle = (NSBundle *(*)()) nl[3].n_value;
    _UISharedImageInitialize = (void (*)(bool)) nl[4].n_value;
    _UISharedImageNameGetIdentifier = (int (*)(NSString *)) nl[5].n_value;
    _UISharedImageWithIdentifier = (UIImage *(*)(int)) nl[6].n_value;

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

    WBRename(true, "NSBundle", @selector(localizedStringForKey:value:table:), (IMP) &NSBundle$localizedStringForKey$value$table$);
    WBRename(true, "NSBundle", @selector(pathForResource:ofType:), (IMP) &NSBundle$pathForResource$ofType$);

    WBRename(true, "UIImage", @selector(initWithContentsOfFile:), (IMP) &$initWithContentsOfFile$);
    WBRename(true, "UIImage", @selector(initWithContentsOfFile:cache:), (IMP) &UIImage$initWithContentsOfFile$cache$);
    WBRename(true, "UINavigationBar", @selector(setBarStyle:), (IMP) &UINavigationBar$setBarStyle$);
    WBRename(true, "UIToolbar", @selector(setBarStyle:), (IMP) &UIToolbar$setBarStyle$);

    _UISharedImageInitialize(false);

    Manager_ = [[NSFileManager defaultManager] retain];
    UIImages_ = [[NSMutableDictionary alloc] initWithCapacity:16];
    PathImages_ = [[NSMutableDictionary alloc] initWithCapacity:16];
    Strings_ = [[NSMutableDictionary alloc] initWithCapacity:0];

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

    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, &ChangeWallpaper, (CFStringRef) @"com.saurik.winterboard.lockbackground", NULL, 0
        );

        NSBundle *MediaPlayer = [NSBundle bundleWithPath:@"/System/Library/Frameworks/MediaPlayer.framework"];
        if (MediaPlayer != nil)
            [MediaPlayer load];

        $MPVideoView = objc_getClass("MPVideoView");

        WBRename(true, "WebCoreFrameBridge", @selector(renderedSizeOfNode:constrainedToWidth:), (IMP) &WebCoreFrameBridge$renderedSizeOfNode$constrainedToWidth$);

        WBRename(true, "SBApplication", @selector(pathForIcon), (IMP) &SBApplication$pathForIcon);
        WBRename(true, "SBApplicationIcon", @selector(icon), (IMP) &SBApplicationIcon$icon);
        WBRename(true, "SBBookmarkIcon", @selector(icon), (IMP) &SBBookmarkIcon$icon);
        WBRename(true, "SBButtonBar", @selector(didMoveToSuperview), (IMP) &$didMoveToSuperview);
        WBRename(true, "SBCalendarIconContentsView", @selector(drawRect:), (IMP) &SBCalendarIconContentsView$drawRect$);
        WBRename(true, "SBContentLayer", @selector(initWithSize:), (IMP) &SBContentLayer$initWithSize$);
        WBRename(true, "SBIconBadge", @selector(initWithBadge:), (IMP) &SBIconBadge$initWithBadge$);
        WBRename(true, "SBIconController", @selector(appendIconList:), (IMP) &SBIconController$appendIconList$);
        WBRename(true, "SBIconLabel", @selector(drawRect:), (IMP) &SBIconLabel$drawRect$);
        WBRename(true, "SBIconLabel", @selector(initWithSize:label:), (IMP) &SBIconLabel$initWithSize$label$);
        WBRename(true, "SBIconLabel", @selector(setInDock:), (IMP) &SBIconLabel$setInDock$);
        WBRename(true, "SBIconModel", @selector(cacheImageForIcon:), (IMP) &SBIconModel$cacheImageForIcon$);
        WBRename(true, "SBIconModel", @selector(getCachedImagedForIcon:), (IMP) &SBIconModel$getCachedImagedForIcon$);

        WBRename(true, "SBSlidingAlertDisplay", @selector(updateDesktopImage:), (IMP) &SBSlidingAlertDisplay$updateDesktopImage$);
        WBRename(true, "SBStatusBarContentsView", @selector(didMoveToSuperview), (IMP) &$didMoveToSuperview);
        WBRename(true, "SBStatusBarContentsView", @selector(initWithStatusBar:mode:), (IMP) &SBStatusBarContentsView$initWithStatusBar$mode$);
        WBRename(true, "SBStatusBarController", @selector(setStatusBarMode:orientation:duration:fenceID:animation:), (IMP) &SBStatusBarController$setStatusBarMode$orientation$duration$fenceID$animation$);
        WBRename(true, "SBStatusBarTimeView", @selector(drawRect:), (IMP) &SBStatusBarTimeView$drawRect$);

        English_ = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/English.lproj/LocalizedApplicationNames.strings"];
        if (English_ != nil)
            English_ = [English_ retain];

        Cache_ = [[NSMutableDictionary alloc] initWithCapacity:64];
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
