/* WinterBoard - Theme Manager for the iPhone
 * Copyright (C) 2008-2010  Jay Freeman (saurik)
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

#include <sys/time.h>

struct timeval _ltv;
bool _itv;

#define _trace() do { \
    struct timeval _ctv; \
    gettimeofday(&_ctv, NULL); \
    if (!_itv) { \
        _itv = true; \
        _ltv = _ctv; \
    } \
    fprintf(stderr, "%lu.%.6u[%f]:_trace()@%s:%u[%s]\n", \
        _ctv.tv_sec, _ctv.tv_usec, \
        (_ctv.tv_sec - _ltv.tv_sec) + (_ctv.tv_usec - _ltv.tv_usec) / 1000000.0, \
        __FILE__, __LINE__, __FUNCTION__\
    ); \
    _ltv = _ctv; \
} while (false)

#define _transient

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <Celestial/AVController.h>
#import <Celestial/AVItem.h>
#import <Celestial/AVQueue.h>

#include <substrate.h>

#import <UIKit/UIKit.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBAppWindow.h>
#import <SpringBoard/SBAwayView.h>
#import <SpringBoard/SBBookmarkIcon.h>
#import <SpringBoard/SBButtonBar.h>
#import <SpringBoard/SBCalendarIconContentsView.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconLabel.h>
#import <SpringBoard/SBIconList.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBImageCache.h>
// XXX: #import <SpringBoard/SBSearchView.h>
#import <SpringBoard/SBSearchTableViewCell.h>
#import <SpringBoard/SBStatusBarContentsView.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBStatusBarOperatorNameView.h>
#import <SpringBoard/SBStatusBarTimeView.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SBWidgetApplicationIcon.h>

#import <MobileSMS/mSMSMessageTranscriptController.h>

#import <MediaPlayer/MPMoviePlayerController.h>
#import <MediaPlayer/MPVideoView.h>
#import <MediaPlayer/MPVideoView-PlaybackControl.h>

#import <CoreGraphics/CGGeometry.h>

#import <ChatKit/CKMessageCell.h>

extern "C" void __clear_cache (char *beg, char *end);

@protocol WinterBoard
- (void *) _node;
@end

Class $MPMoviePlayerController;
Class $MPVideoView;
Class $WebCoreFrameBridge;

Class $NSBundle;

Class $UIImage;
Class $UINavigationBar;
Class $UIToolbar;

Class $CKMessageCell;
Class $CKTimestampView;
Class $CKTranscriptController;
Class $CKTranscriptTableView;

Class $SBApplication;
Class $SBApplicationIcon;
Class $SBAwayView;
Class $SBBookmarkIcon;
Class $SBButtonBar;
Class $SBCalendarIconContentsView;
Class $SBIcon;
Class $SBIconBadge;
Class $SBIconController;
Class $SBIconLabel;
Class $SBIconList;
Class $SBIconModel;
//Class $SBImageCache;
Class $SBSearchView;
Class $SBSearchTableViewCell;
Class $SBStatusBarContentsView;
Class $SBStatusBarController;
Class $SBStatusBarOperatorNameView;
Class $SBStatusBarTimeView;
Class $SBUIController;
Class $SBWidgetApplicationIcon;

@interface NSDictionary (WinterBoard)
- (UIColor *) wb$colorForKey:(NSString *)key;
- (BOOL) wb$boolForKey:(NSString *)key;
@end

@implementation NSDictionary (WinterBoard)

- (UIColor *) wb$colorForKey:(NSString *)key {
    NSString *value = [self objectForKey:key];
    if (value == nil)
        return nil;
    /* XXX: incorrect */
    return nil;
}

- (BOOL) wb$boolForKey:(NSString *)key {
    if (NSString *value = [self objectForKey:key])
        return [value boolValue];
    return false;
}

@end

static BOOL (*_GSFontGetUseLegacyFontMetrics)();
#define $GSFontGetUseLegacyFontMetrics() \
    (_GSFontGetUseLegacyFontMetrics == NULL ? YES : _GSFontGetUseLegacyFontMetrics())

bool Debug_ = false;
bool Engineer_ = false;
bool SummerBoard_ = true;

static UIImage *(*_UIApplicationImageWithName)(NSString *name);
static UIImage *(*_UIImageAtPath)(NSString *name, NSBundle *path);
static CGImageRef (*_UIImageRefAtPath)(NSString *name, bool cache, UIImageOrientation *orientation);
static UIImage *(*_UIImageWithNameInDomain)(NSString *name, NSString *domain);
static NSBundle *(*_UIKitBundle)();
static int (*_UISharedImageNameGetIdentifier)(NSString *);
static UIImage *(*_UISharedImageWithIdentifier)(int);

static NSMutableDictionary *UIImages_;
static NSMutableDictionary *PathImages_;
static NSMutableDictionary *Cache_;
static NSMutableDictionary *Strings_;
static NSMutableDictionary *Themed_;
static NSMutableDictionary *Bundles_;

static NSFileManager *Manager_;
static NSDictionary *English_;
static NSMutableDictionary *Info_;
static NSMutableArray *themes_;

static NSString *$getTheme$(NSArray *files, bool parent = false) {
    if (!parent)
        if (NSString *path = [Themed_ objectForKey:files])
            return reinterpret_cast<id>(path) == [NSNull null] ? nil : path;

    if (Debug_)
        NSLog(@"WB:Debug: %@", [files description]);

    NSString *path;

    for (NSString *theme in themes_)
        for (NSString *file in files) {
            path = [NSString stringWithFormat:@"%@/%@", theme, file];
            if ([Manager_ fileExistsAtPath:path]) {
                path = parent ? theme : path;
                goto set;
            }
        }

    path = nil;
  set:
    if (!parent)
        [Themed_ setObject:(path == nil ? [NSNull null] : reinterpret_cast<id>(path)) forKey:files];
    return path;
}

static NSString *$pathForFile$inBundle$(NSString *file, NSBundle *bundle, bool ui) {
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
    else if ([identifier isEqualToString:@"com.apple.chatkit"])
        [names addObject:[NSString stringWithFormat:@"Bundles/com.apple.MobileSMS/%@", file]];
    else if ([identifier isEqualToString:@"com.apple.calculator"])
        [names addObject:[NSString stringWithFormat:@"Files/Applications/Calculator.app/%@", file]];
    else if (![identifier isEqualToString:@"com.apple.springboard"] || !SummerBoard_);
        remapResourceName(@"FSO_BG.png", @"StatusBar")
        remapResourceName(@"SBDockBG.png", @"Dock")
        remapResourceName(@"SBWeatherCelsius.png", @"Icons/Weather")

    if (NSString *path = $getTheme$(names))
        return path;
    return nil;
}

static NSString *$pathForIcon$(SBApplication *self) {
    NSString *identifier = [self bundleIdentifier];
    NSString *path = [self path];
    NSString *folder = [path lastPathComponent];
    NSString *dname = [self displayName];
    NSString *didentifier = [self displayIdentifier];

    if (Debug_)
        NSLog(@"WB:Debug: [SBApplication(%@:%@:%@:%@) pathForIcon]", identifier, folder, dname, didentifier);

    NSMutableArray *names = [NSMutableArray arrayWithCapacity:8];

    /* XXX: I might need to keep this for backwards compatibility
    if (identifier != nil)
        [names addObject:[NSString stringWithFormat:@"Bundles/%@/icon.png", identifier]];
    if (folder != nil)
        [names addObject:[NSString stringWithFormat:@"Folders/%@/icon.png", folder]]; */

    #define testForIcon(Name) \
        if (NSString *name = Name) \
            [names addObject:[NSString stringWithFormat:@"Icons/%@.png", name]];

    if (![didentifier isEqualToString:identifier])
        testForIcon(didentifier);

    testForIcon(identifier);
    testForIcon(dname);

    if ([identifier isEqualToString:@"com.apple.MobileSMS"])
        testForIcon(@"SMS");

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

@interface NSBundle (WinterBoard)
+ (NSBundle *) wb$bundleWithFile:(NSString *)path;
@end

@implementation NSBundle (WinterBoard)

+ (NSBundle *) wb$bundleWithFile:(NSString *)path {
    path = [path stringByDeletingLastPathComponent];
    if (path == nil || [path length] == 0 || [path isEqualToString:@"/"])
        return nil;

    NSBundle *bundle([Bundles_ objectForKey:path]);
    if (reinterpret_cast<id>(bundle) == [NSNull null])
        return nil;
    else if (bundle == nil) {
        if ([Manager_ fileExistsAtPath:[path stringByAppendingPathComponent:@"Info.plist"]])
            bundle = [NSBundle bundleWithPath:path];
        if (bundle == nil)
            bundle = [NSBundle wb$bundleWithFile:path];
        if (Debug_)
            NSLog(@"WB:Debug:PathBundle(%@, %@)", path, bundle);
        [Bundles_ setObject:(bundle == nil ? [NSNull null] : reinterpret_cast<id>(bundle)) forKey:path];
    }

    return bundle;
}

@end

@interface NSString (WinterBoard)
- (NSString *) wb$themedPath;
@end

@implementation NSString (WinterBoard)

- (NSString *) wb$themedPath {
    if (Debug_)
        NSLog(@"WB:Debug:Bypass(\"%@\")", self);

    if (NSBundle *bundle = [NSBundle wb$bundleWithFile:self]) {
        NSString *file([self stringByResolvingSymlinksInPath]);
        NSString *prefix([[bundle bundlePath] stringByResolvingSymlinksInPath]);
        if ([file hasPrefix:prefix]) {
            NSUInteger length([prefix length]);
            if (length != [file length])
                if (NSString *path = $pathForFile$inBundle$([file substringFromIndex:(length + 1)], bundle, false))
                    return path;
        }
    }

    return self;
}

@end

void WBLogRect(const char *tag, struct CGRect rect) {
    NSLog(@"%s:{%f,%f+%f,%f}", tag, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

void WBLogHierarchy(UIView *view, unsigned index = 0, unsigned indent = 0) {
    CGRect frame([view frame]);
    NSLog(@"%*s|%2d:%p:%s : {%f,%f+%f,%f} (%@)", indent * 3, "", index, view, class_getName([view class]), frame.origin.x, frame.origin.y, frame.size.width, frame.size.height, [view backgroundColor]);
    index = 0;
    for (UIView *child in [view subviews])
        WBLogHierarchy(child, index++, indent + 1);
}

UIImage *$cacheForImage$(UIImage *image) {
    CGColorSpaceRef space(CGColorSpaceCreateDeviceRGB());
    CGRect rect = {CGPointMake(1, 1), [image size]};
    CGSize size = {rect.size.width + 2, rect.size.height + 2};

    CGContextRef context(CGBitmapContextCreate(NULL, size.width, size.height, 8, 4 * size.width, space, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst));
    CGColorSpaceRelease(space);

    CGContextDrawImage(context, rect, [image CGImage]);
    CGImageRef ref(CGBitmapContextCreateImage(context));
    CGContextRelease(context);

    UIImage *cache([UIImage imageWithCGImage:ref]);
    CGImageRelease(ref);

    return cache;
}

/*MSHook(id, SBImageCache$initWithName$forImageWidth$imageHeight$initialCapacity$, SBImageCache *self, SEL sel, NSString *name, unsigned width, unsigned height, unsigned capacity) {
    //if ([name isEqualToString:@"icons"]) return nil;
    return _SBImageCache$initWithName$forImageWidth$imageHeight$initialCapacity$(self, sel, name, width, height, capacity);
}*/

MSHook(void, SBIconModel$cacheImageForIcon$, SBIconModel *self, SEL sel, SBIcon *icon) {
    NSString *key([icon displayIdentifier]);

    if (UIImage *image = [icon icon]) {
        CGSize size = [image size];
        if (size.width != 59 || size.height != 60) {
            UIImage *cache($cacheForImage$(image));
            [Cache_ setObject:cache forKey:key];
            return;
        }
    }

    _SBIconModel$cacheImageForIcon$(self, sel, icon);
}

MSHook(void, SBIconModel$cacheImagesForIcon$, SBIconModel *self, SEL sel, SBIcon *icon) {
    /* XXX: do I /really/ have to do this? figure out how to cache the small icon! */
    _SBIconModel$cacheImagesForIcon$(self, sel, icon);

    NSString *key([icon displayIdentifier]);

    if (UIImage *image = [icon icon]) {
        CGSize size = [image size];
        if (size.width != 59 || size.height != 60) {
            UIImage *cache($cacheForImage$(image));
            [Cache_ setObject:cache forKey:key];
            return;
        }
    }
}

MSHook(UIImage *, SBIconModel$getCachedImagedForIcon$, SBIconModel *self, SEL sel, SBIcon *icon) {
    NSString *key([icon displayIdentifier]);
    if (UIImage *image = [Cache_ objectForKey:key])
        return image;
    else
        return _SBIconModel$getCachedImagedForIcon$(self, sel, icon);
}

MSHook(UIImage *, SBIconModel$getCachedImagedForIcon$smallIcon$, SBIconModel *self, SEL sel, SBIcon *icon, BOOL small) {
    if (small)
        return _SBIconModel$getCachedImagedForIcon$smallIcon$(self, sel, icon, small);
    NSString *key([icon displayIdentifier]);
    if (UIImage *image = [Cache_ objectForKey:key])
        return image;
    else
        return _SBIconModel$getCachedImagedForIcon$smallIcon$(self, sel, icon, small);
}

MSHook(id, SBSearchView$initWithFrame$, id /* XXX: SBSearchView */ self, SEL sel, struct CGRect frame) {
    if ((self = _SBSearchView$initWithFrame$(self, sel, frame)) != nil) {
        [self setBackgroundColor:[UIColor clearColor]];
        for (UIView *child in [self subviews])
            [child setBackgroundColor:[UIColor clearColor]];
    } return self;
}

MSHook(id, SBSearchTableViewCell$initWithStyle$reuseIdentifier$, SBSearchTableViewCell *self, SEL sel, int style, NSString *reuse) {
    if ((self = _SBSearchTableViewCell$initWithStyle$reuseIdentifier$(self, sel, style, reuse)) != nil) {
        [self setBackgroundColor:[UIColor clearColor]];
    } return self;
}

MSHook(void, SBSearchTableViewCell$drawRect$, SBSearchTableViewCell *self, SEL sel, struct CGRect rect, BOOL selected) {
    _SBSearchTableViewCell$drawRect$(self, sel, rect, selected);
    float inset([self edgeInset]);
    [[UIColor clearColor] set];
    UIRectFill(CGRectMake(0, 0, inset, rect.size.height));
    UIRectFill(CGRectMake(rect.size.width - inset, 0, inset, rect.size.height));
}

MSHook(UIImage *, SBApplicationIcon$icon, SBApplicationIcon *self, SEL sel) {
    if (![Info_ wb$boolForKey:@"ComposeStoreIcons"])
        if (NSString *path = $pathForIcon$([self application]))
            return [UIImage imageWithContentsOfFile:path];
    return _SBApplicationIcon$icon(self, sel);
}

MSHook(UIImage *, SBWidgetApplicationIcon$icon, SBWidgetApplicationIcon *self, SEL sel) {
    if (Debug_)
        NSLog(@"WB:Debug:Widget(%@:%@)", [self displayIdentifier], [self displayName]);
    if (NSString *path = $getTheme$([NSArray arrayWithObject:[NSString stringWithFormat:@"Icons/%@.png", [self displayName]]]))
        return [UIImage imageWithContentsOfFile:path];
    return _SBWidgetApplicationIcon$icon(self, sel);
}

MSHook(UIImage *, SBBookmarkIcon$icon, SBBookmarkIcon *self, SEL sel) {
    if (Debug_)
        NSLog(@"WB:Debug:Bookmark(%@:%@)", [self displayIdentifier], [self displayName]);
    if (NSString *path = $getTheme$([NSArray arrayWithObject:[NSString stringWithFormat:@"Icons/%@.png", [self displayName]]]))
        return [UIImage imageWithContentsOfFile:path];
    return _SBBookmarkIcon$icon(self, sel);
}

MSHook(NSString *, SBApplication$pathForIcon, SBApplication *self, SEL sel) {
    if (NSString *path = $pathForIcon$(self))
        return path;
    return _SBApplication$pathForIcon(self, sel);
}

static UIImage *CachedImageAtPath(NSString *path) {
    path = [path stringByResolvingSymlinksInPath];
    UIImage *image = [PathImages_ objectForKey:path];
    if (image != nil)
        return reinterpret_cast<id>(image) == [NSNull null] ? nil : image;
    image = [[UIImage alloc] initWithContentsOfFile:path cache:true];
    if (image != nil)
        image = [image autorelease];
    [PathImages_ setObject:(image == nil ? [NSNull null] : reinterpret_cast<id>(image)) forKey:path];
    return image;
}

MSHook(CGImageRef, _UIImageRefAtPath, NSString *name, bool cache, UIImageOrientation *orientation) {
    if (Debug_)
        NSLog(@"WB:Debug: _UIImageRefAtPath(\"%@\", %s)", name, cache ? "true" : "false");
    return __UIImageRefAtPath([name wb$themedPath], cache, orientation);
}

/*MSHook(UIImage *, _UIImageAtPath, NSString *name, NSBundle *bundle) {
    if (bundle == nil)
        return __UIImageAtPath(name, nil);
    else {
        NSString *key = [NSString stringWithFormat:@"B:%@/%@", [bundle bundleIdentifier], name];
        UIImage *image = [PathImages_ objectForKey:key];
        if (image != nil)
            return reinterpret_cast<id>(image) == [NSNull null] ? nil : image;
        if (Debug_)
            NSLog(@"WB:Debug: _UIImageAtPath(\"%@\", %@)", name, bundle);
        if (NSString *path = $pathForFile$inBundle$(name, bundle, false))
            image = CachedImageAtPath(path);
        if (image == nil)
            image = __UIImageAtPath(name, bundle);
        [PathImages_ setObject:(image == nil ? [NSNull null] : reinterpret_cast<id>(image)) forKey:key];
        return image;
    }
}*/

MSHook(UIImage *, _UIApplicationImageWithName, NSString *name) {
    NSBundle *bundle = [NSBundle mainBundle];
    if (Debug_)
        NSLog(@"WB:Debug: _UIApplicationImageWithName(\"%@\", %@)", name, bundle);
    if (NSString *path = $pathForFile$inBundle$(name, bundle, false))
        return CachedImageAtPath(path);
    return __UIApplicationImageWithName(name);
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

MSHook(NSString *, NSBundle$pathForResource$ofType$, NSBundle *self, SEL sel, NSString *resource, NSString *type) {
    NSString *file = type == nil ? resource : [NSString stringWithFormat:@"%@.%@", resource, type];
    if (Debug_)
        NSLog(@"WB:Debug: [NSBundle(%@) pathForResource:\"%@\"]", [self bundleIdentifier], file);
    if (NSString *path = $pathForFile$inBundle$(file, self, false))
        return path;
    return _NSBundle$pathForResource$ofType$(self, sel, resource, type);
}

void $setBarStyle$_(NSString *name, int &style) {
    if (Debug_)
        NSLog(@"WB:Debug:%@Style:%d", name, style);
    NSNumber *number = nil;
    if (number == nil)
        number = [Info_ objectForKey:[NSString stringWithFormat:@"%@Style-%d", name, style]];
    if (number == nil)
        number = [Info_ objectForKey:[NSString stringWithFormat:@"%@Style", name]];
    if (number != nil) {
        style = [number intValue];
        if (Debug_)
            NSLog(@"WB:Debug:%@Style=%d", name, style);
    }
}

MSHook(void, SBCalendarIconContentsView$drawRect$, SBCalendarIconContentsView *self, SEL sel, CGRect rect) {
    NSBundle *bundle([NSBundle mainBundle]);

    CFLocaleRef locale(CFLocaleCopyCurrent());
    CFDateFormatterRef formatter(CFDateFormatterCreate(NULL, locale, kCFDateFormatterNoStyle, kCFDateFormatterNoStyle));
    CFRelease(locale);

    CFDateRef now(CFDateCreate(NULL, CFAbsoluteTimeGetCurrent()));

    CFDateFormatterSetFormat(formatter, (CFStringRef) [bundle localizedStringForKey:@"CALENDAR_ICON_DAY_NUMBER_FORMAT" value:@"" table:@"SpringBoard"]);
    CFStringRef date(CFDateFormatterCreateStringWithDate(NULL, formatter, now));
    CFDateFormatterSetFormat(formatter, (CFStringRef) [bundle localizedStringForKey:@"CALENDAR_ICON_DAY_NAME_FORMAT" value:@"cccc" table:@"SpringBoard"]);
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
    float leeway(10);
    CGSize datesize = [(NSString *)date sizeWithStyle:datestyle forWidth:(width + leeway)];
    CGSize daysize = [(NSString *)day sizeWithStyle:daystyle forWidth:(width + leeway)];

    unsigned base($GSFontGetUseLegacyFontMetrics() ? 71 : 70);

    [(NSString *)date drawAtPoint:CGPointMake(
        (width + 1 - datesize.width) / 2, (base - datesize.height) / 2
    ) withStyle:datestyle];

    [(NSString *)day drawAtPoint:CGPointMake(
        (width + 1 - daysize.width) / 2, (16 - daysize.height) / 2
    ) withStyle:daystyle];

    CFRelease(date);
    CFRelease(day);
}

/*static id UINavigationBarBackground$initWithFrame$withBarStyle$withTintColor$(UINavigationBarBackground<WinterBoard> *self, SEL sel, CGRect frame, int style, UIColor *tint) {
_trace();

    if (NSNumber *number = [Info_ objectForKey:@"NavigationBarStyle"])
        style = [number intValue];

    if (UIColor *color = [Info_ wb$colorForKey:@"NavigationBarTint"])
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

MSHook(void, UIToolbar$setBarStyle$, UIToolbar *self, SEL sel, int style) {
    $setBarStyle$_(@"Toolbar", style);
    return _UIToolbar$setBarStyle$(self, sel, style);
}

MSHook(void, UINavigationBar$setBarStyle$, UINavigationBar *self, SEL sel, int style) {
    $setBarStyle$_(@"NavigationBar", style);
    return _UINavigationBar$setBarStyle$(self, sel, style);
}

MSHook(void, SBButtonBar$didMoveToSuperview, UIView *self, SEL sel) {
    [[self superview] setBackgroundColor:[UIColor clearColor]];
    _SBButtonBar$didMoveToSuperview(self, sel);
}

MSHook(void, SBStatusBarContentsView$didMoveToSuperview, UIView *self, SEL sel) {
    [[self superview] setBackgroundColor:[UIColor clearColor]];
    _SBStatusBarContentsView$didMoveToSuperview(self, sel);
}

MSHook(UIImage *, UIImage$defaultDesktopImage, UIImage *self, SEL sel) {
    if (Debug_)
        NSLog(@"WB:Debug:DefaultDesktopImage");
    if (NSString *path = $getTheme$([NSArray arrayWithObjects:@"LockBackground.png", @"LockBackground.jpg", nil]))
        return [UIImage imageWithContentsOfFile:path];
    return _UIImage$defaultDesktopImage(self, sel);
}

static NSArray *Wallpapers_;
static NSString *WallpaperFile_;
static UIImageView *WallpaperImage_;
static UIWebDocumentView *WallpaperPage_;
static NSURL *WallpaperURL_;

#define _release(object) \
    do if (object != nil) { \
        [object release]; \
        object = nil; \
    } while (false)

MSHook(id, SBUIController$init, SBUIController *self, SEL sel) {
    self = _SBUIController$init(self, sel);
    if (self == nil)
        return nil;

    UIWindow *&_window(MSHookIvar<UIWindow *>(self, "_window"));
    UIView *&_contentLayer(MSHookIvar<UIView *>(self, "_contentLayer"));
    UIView *&_contentView(MSHookIvar<UIView *>(self, "_contentView"));

    UIView *layer;
    if (&_contentLayer != NULL)
        layer = _contentLayer;
    else if (&_contentView != NULL)
        layer = _contentView;
    else
        layer = nil;

    UIView *content([[[UIView alloc] initWithFrame:[layer frame]] autorelease]);
    [content setBackgroundColor:[layer backgroundColor]];
    [layer setBackgroundColor:[UIColor clearColor]];
    [layer setFrame:[content bounds]];
    [_window setContentView:content];

    _release(WallpaperFile_);
    _release(WallpaperImage_);
    _release(WallpaperPage_);
    _release(WallpaperURL_);

    if (NSString *theme = $getTheme$(Wallpapers_, true)) {
        NSString *mp4 = [theme stringByAppendingPathComponent:@"Wallpaper.mp4"];
        if ([Manager_ fileExistsAtPath:mp4]) {
#if UseAVController
            NSError *error;

            static AVController *controller_(nil);
            if (controller_ == nil) {
                AVQueue *queue([AVQueue avQueue]);
                controller_ = [[AVController avControllerWithQueue:queue error:&error] retain];
            }

            AVQueue *queue([controller_ queue]);

            UIView *video([[[UIView alloc] initWithFrame:[content bounds]] autorelease]);
            [controller_ setLayer:[video _layer]];

            AVItem *item([[[AVItem alloc] initWithPath:mp4 error:&error] autorelease]);
            [queue appendItem:item error:&error];

            [controller_ play:&error];
#elif UseMPMoviePlayerController
            NSURL *url([NSURL fileURLWithPath:mp4]);
            MPMoviePlayerController *controller = [[$MPMoviePlayerController alloc] initWithContentURL:url];
	    controller.movieControlMode = MPMovieControlModeHidden;
	    [controller play];
#else
            MPVideoView *video = [[[$MPVideoView alloc] initWithFrame:[content bounds]] autorelease];
            [video setMovieWithPath:mp4];
            [video setRepeatMode:1];
            [video setRepeatGap:-1];
            [video playFromBeginning];;
#endif

            [content addSubview:video];
        }

        NSString *png = [theme stringByAppendingPathComponent:@"Wallpaper.png"];
        NSString *jpg = [theme stringByAppendingPathComponent:@"Wallpaper.jpg"];

        NSString *path;
        if ([Manager_ fileExistsAtPath:png])
            path = png;
        else if ([Manager_ fileExistsAtPath:jpg])
            path = jpg;
        else path = nil;

        UIImage *image;
        if (path != nil) {
            image = [[UIImage alloc] initWithContentsOfFile:path];
            if (image != nil)
                image = [image autorelease];
        } else image = nil;

        if (image != nil) {
            WallpaperFile_ = [path retain];
            WallpaperImage_ = [[UIImageView alloc] initWithImage:image];
            if (NSNumber *number = [Info_ objectForKey:@"WallpaperAlpha"])
                [WallpaperImage_ setAlpha:[number floatValue]];
            [content addSubview:WallpaperImage_];
        }

        NSString *html = [theme stringByAppendingPathComponent:@"Wallpaper.html"];
        if ([Manager_ fileExistsAtPath:html]) {
            CGRect bounds = [content bounds];

            UIWebDocumentView *view([[[UIWebDocumentView alloc] initWithFrame:bounds] autorelease]);
            [view setAutoresizes:true];

            WallpaperPage_ = [view retain];
            WallpaperURL_ = [[NSURL fileURLWithPath:html] retain];

            [WallpaperPage_ loadRequest:[NSURLRequest requestWithURL:WallpaperURL_]];

            [view setBackgroundColor:[UIColor clearColor]];
            if ([view respondsToSelector:@selector(setDrawsBackground:)])
                [view setDrawsBackground:NO];
            [[view webView] setDrawsBackground:NO];

            [content addSubview:view];
        }
    }

    for (size_t i(0), e([themes_ count]); i != e; ++i) {
        NSString *theme = [themes_ objectAtIndex:(e - i - 1)];
        NSString *html = [theme stringByAppendingPathComponent:@"Widget.html"];
        if ([Manager_ fileExistsAtPath:html]) {
            CGRect bounds = [content bounds];

            UIWebDocumentView *view([[[UIWebDocumentView alloc] initWithFrame:bounds] autorelease]);
            [view setAutoresizes:true];

            NSURL *url = [NSURL fileURLWithPath:html];
            [view loadRequest:[NSURLRequest requestWithURL:url]];

            [view setBackgroundColor:[UIColor clearColor]];
            if ([view respondsToSelector:@selector(setDrawsBackground:)])
                [view setDrawsBackground:NO];
            [[view webView] setDrawsBackground:NO];

            [content addSubview:view];
        }
    }

    [content addSubview:layer];

    return self;
}

MSHook(void, SBAwayView$updateDesktopImage$, SBAwayView *self, SEL sel, UIImage *image) {
    NSString *path = $getTheme$([NSArray arrayWithObject:@"LockBackground.html"]);
    UIView *&_backgroundView(MSHookIvar<UIView *>(self, "_backgroundView"));

    if (path != nil && _backgroundView != nil)
        path = nil;

    _SBAwayView$updateDesktopImage$(self, sel, image);

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

- (NSString *) description {
    return time_;
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
- (NSString *) description;

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

- (NSString *) description {
    return [badge_ description];
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

MSHook(void, SBIcon$setAlpha$, SBIcon *self, SEL sel, float alpha) {
    if (NSNumber *number = [Info_ objectForKey:@"IconAlpha"])
        alpha = [number floatValue];
    return _SBIcon$setAlpha$(self, sel, alpha);
}

MSHook(id, SBIconBadge$initWithBadge$, SBIconBadge *self, SEL sel, NSString *badge) {
    if ((self = _SBIconBadge$initWithBadge$(self, sel, badge)) != nil) {
        id &_badge(MSHookIvar<id>(self, "_badge"));
        if (_badge != nil)
            if (id label = [[WBBadgeLabel alloc] initWithBadge:[_badge autorelease]])
                _badge = label;
    } return self;
}

void SBStatusBarController$setStatusBarMode(int &mode) {
    if (Debug_)
        NSLog(@"WB:Debug:setStatusBarMode:%d", mode);
    if (mode < 100) // 104:hidden 105:glowing
        if (NSNumber *number = [Info_ objectForKey:@"StatusBarMode"])
            mode = [number intValue];
}

/*MSHook(void, SBStatusBarController$setStatusBarMode$orientation$duration$animation$, SBStatusBarController *self, SEL sel, int mode, int orientation, double duration, int animation) {
    NSLog(@"mode:%d orientation:%d duration:%f animation:%d", mode, orientation, duration, animation);
    SBStatusBarController$setStatusBarMode(mode);
    return _SBStatusBarController$setStatusBarMode$orientation$duration$animation$(self, sel, mode, orientation, duration, animation);
}*/

MSHook(void, SBStatusBarController$setStatusBarMode$orientation$duration$fenceID$animation$, SBStatusBarController *self, SEL sel, int mode, int orientation, float duration, int fenceID, int animation) {
    //NSLog(@"mode:%d orientation:%d duration:%f fenceID:%d animation:%d", mode, orientation, duration, fenceID, animation);
    SBStatusBarController$setStatusBarMode(mode);
    return _SBStatusBarController$setStatusBarMode$orientation$duration$fenceID$animation$(self, sel, mode, orientation, duration, fenceID, animation);
}

MSHook(void, SBStatusBarController$setStatusBarMode$orientation$duration$fenceID$animation$startTime$, SBStatusBarController *self, SEL sel, int mode, int orientation, double duration, int fenceID, int animation, double startTime) {
    //NSLog(@"mode:%d orientation:%d duration:%f fenceID:%d animation:%d startTime:%f", mode, orientation, duration, fenceID, animation, startTime);
    SBStatusBarController$setStatusBarMode(mode);
    //NSLog(@"mode=%u", mode);
    return _SBStatusBarController$setStatusBarMode$orientation$duration$fenceID$animation$startTime$(self, sel, mode, orientation, duration, fenceID, animation, startTime);
}

/*MSHook(id, SBStatusBarContentsView$initWithStatusBar$mode$, SBStatusBarContentsView *self, SEL sel, id bar, int mode) {
    if (NSNumber *number = [Info_ objectForKey:@"StatusBarContentsMode"])
        mode = [number intValue];
    return _SBStatusBarContentsView$initWithStatusBar$mode$(self, sel, bar, mode);
}*/

MSHook(NSString *, SBStatusBarOperatorNameView$operatorNameStyle, SBStatusBarOperatorNameView *self, SEL sel) {
    NSString *style(_SBStatusBarOperatorNameView$operatorNameStyle(self, sel));
    if (Debug_)
        NSLog(@"operatorNameStyle= %@", style);
    if (NSString *custom = [Info_ objectForKey:@"OperatorNameStyle"])
        style = [NSString stringWithFormat:@"%@; %@", style, custom];
    return style;
}

MSHook(void, SBStatusBarOperatorNameView$setOperatorName$fullSize$, SBStatusBarOperatorNameView *self, SEL sel, NSString *name, BOOL full) {
    if (Debug_)
        NSLog(@"setOperatorName:\"%@\" fullSize:%u", name, full);
    return _SBStatusBarOperatorNameView$setOperatorName$fullSize$(self, sel, name, NO);
}

// XXX: replace this with [SBStatusBarTimeView tile]
MSHook(void, SBStatusBarTimeView$drawRect$, SBStatusBarTimeView *self, SEL sel, CGRect rect) {
    id &_time(MSHookIvar<id>(self, "_time"));
    if (_time != nil && [_time class] != [WBTimeLabel class])
        object_setInstanceVariable(self, "_time", reinterpret_cast<void *>([[WBTimeLabel alloc] initWithTime:[_time autorelease] view:self]));
    return _SBStatusBarTimeView$drawRect$(self, sel, rect);
}

@interface UIView (WinterBoard)
- (bool) wb$isWBImageView;
- (void) wb$logHierarchy;
@end

@implementation UIView (WinterBoard)

- (bool) wb$isWBImageView {
    return false;
}

- (void) wb$logHierarchy {
    WBLogHierarchy(self);
}

@end

@interface WBImageView : UIImageView {
}

- (bool) wb$isWBImageView;
- (void) wb$updateFrame;
@end

@implementation WBImageView

- (bool) wb$isWBImageView {
    return true;
}

- (void) wb$updateFrame {
    CGRect frame([self frame]);
    frame.origin.y = 0;

    for (UIView *view(self); ; ) {
        view = [view superview];
        if (view == nil)
            break;
        frame.origin.y -= [view frame].origin.y;
    }

    [self setFrame:frame];
}

@end

MSHook(void, SBIconList$setFrame$, SBIconList *self, SEL sel, CGRect frame) {
    NSArray *subviews([self subviews]);
    WBImageView *view([subviews count] == 0 ? nil : [subviews objectAtIndex:0]);
    if (view != nil && [view wb$isWBImageView])
        [view wb$updateFrame];
    _SBIconList$setFrame$(self, sel, frame);
}

MSHook(void, SBIconController$noteNumberOfIconListsChanged, SBIconController *self, SEL sel) {
    SBIconModel *&_iconModel(MSHookIvar<SBIconModel *>(self, "_iconModel"));
    NSArray *lists([_iconModel iconLists]);

    for (unsigned i(0), e([lists count]); i != e; ++i)
        if (NSString *path = $getTheme$([NSArray arrayWithObject:[NSString stringWithFormat:@"Page%u.png", i]])) {
            SBIconList *list([lists objectAtIndex:i]);
            NSArray *subviews([list subviews]);

            WBImageView *view([subviews count] == 0 ? nil : [subviews objectAtIndex:0]);
            if (view == nil || ![view wb$isWBImageView]) {
                view = [[[WBImageView alloc] init] autorelease];
                [list insertSubview:view atIndex:0];
            }

            UIImage *image([UIImage imageWithContentsOfFile:path]);

            CGRect frame([view frame]);
            frame.size = [image size];
            [view setFrame:frame];

            [view setImage:image];
            [view wb$updateFrame];
        }

    return _SBIconController$noteNumberOfIconListsChanged(self, sel);
}

MSHook(id, SBIconLabel$initWithSize$label$, SBIconLabel *self, SEL sel, CGSize size, NSString *label) {
    self = _SBIconLabel$initWithSize$label$(self, sel, size, label);
    if (self != nil)
        [self setClipsToBounds:NO];
    return self;
}

MSHook(void, SBIconLabel$setInDock$, SBIconLabel *self, SEL sel, BOOL docked) {
    id &_label(MSHookIvar<id>(self, "_label"));
    if (![Info_ wb$boolForKey:@"UndockedIconLabels"])
        docked = true;
    if (_label != nil && [_label respondsToSelector:@selector(setInDock:)])
        [_label setInDock:docked];
    return _SBIconLabel$setInDock$(self, sel, docked);
}

MSHook(NSString *, NSBundle$localizedStringForKey$value$table$, NSBundle *self, SEL sel, NSString *key, NSString *value, NSString *table) {
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
    return _NSBundle$localizedStringForKey$value$table$(self, sel, key, value, table);
}

@class WebCoreFrameBridge;
MSHook(CGSize, WebCoreFrameBridge$renderedSizeOfNode$constrainedToWidth$, WebCoreFrameBridge *self, SEL sel, id node, float width) {
    if (node == nil)
        return CGSizeZero;
    void **core(reinterpret_cast<void **>([node _node]));
    if (core == NULL || core[6] == NULL)
        return CGSizeZero;
    return _WebCoreFrameBridge$renderedSizeOfNode$constrainedToWidth$(self, sel, node, width);
}

MSHook(void, SBIconLabel$drawRect$, SBIconLabel *self, SEL sel, CGRect rect) {
    CGRect bounds = [self bounds];

    static Ivar drawMoreLegibly = object_getInstanceVariable(self, "_drawMoreLegibly", NULL);

    BOOL docked;
    Ivar ivar = object_getInstanceVariable(self, "_inDock", reinterpret_cast<void **>(&docked));
    docked = (docked & (ivar_getOffset(ivar) == ivar_getOffset(drawMoreLegibly) ? 0x2 : 0x1)) != 0;

    NSString *label(MSHookIvar<NSString *>(self, "_label"));

    NSString *style = [NSString stringWithFormat:@""
        "font-family: Helvetica; "
        "font-weight: bold; "
        "font-size: 11px; "
        "color: %@; "
    "", docked ? @"white" : @"#b3b3b3"];

    if (docked)
        style = [style stringByAppendingString:@"text-shadow: rgba(0, 0, 0, 0.5) 0px -1px 0px; "];

    bool ellipsis(false);
    float max = 75, width;
  width:
    width = [(ellipsis ? [label stringByAppendingString:@"..."] : label) sizeWithStyle:style forWidth:320].width;

    if (width > max) {
        size_t length([label length]);
        float spacing((width - max) / (length - 1));

        if (spacing > 1.25) {
            ellipsis = true;
            label = [label substringToIndex:(length - 1)];
            goto width;
        }

        style = [style stringByAppendingString:[NSString stringWithFormat:@"letter-spacing: -%f; ", spacing]];
    }

    if (ellipsis)
        label = [label stringByAppendingString:@"..."];

    if (NSString *custom = [Info_ objectForKey:(docked ? @"DockedIconLabelStyle" : @"UndockedIconLabelStyle")])
        style = [style stringByAppendingString:custom];

    CGSize size = [label sizeWithStyle:style forWidth:bounds.size.width];
    [label drawAtPoint:CGPointMake((bounds.size.width - size.width) / 2, 0) withStyle:style];
}

MSHook(void, CKMessageCell$addBalloonView$, id self, SEL sel, CKBalloonView *balloon) {
    _CKMessageCell$addBalloonView$(self, sel, balloon);
    [balloon setBackgroundColor:[UIColor clearColor]];
}

MSHook(id, CKMessageCell$initWithStyle$reuseIdentifier$, id self, SEL sel, int style, NSString *reuse) {
    if ((self = _CKMessageCell$initWithStyle$reuseIdentifier$(self, sel, style, reuse)) != nil) {
        [[self contentView] setBackgroundColor:[UIColor clearColor]];
    } return self;
}

MSHook(id, CKTimestampView$initWithStyle$reuseIdentifier$, id self, SEL sel, int style, NSString *reuse) {
    if ((self = _CKTimestampView$initWithStyle$reuseIdentifier$(self, sel, style, reuse)) != nil) {
        UILabel *&_label(MSHookIvar<UILabel *>(self, "_label"));
        [_label setBackgroundColor:[UIColor clearColor]];
    } return self;
}

MSHook(void, CKTranscriptTableView$setSeparatorStyle$, id self, SEL sel, int style) {
    _CKTranscriptTableView$setSeparatorStyle$(self, sel, UITableViewCellSeparatorStyleNone);
}

MSHook(id, CKTranscriptTableView$initWithFrame$style$, id self, SEL sel, CGRect frame, int style) {
    _trace();
    if ((self = _CKTranscriptTableView$initWithFrame$style$(self, sel, frame, style)) != nil) {
        [self setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    } return self;
}

MSHook(void, TranscriptController$loadView, mSMSMessageTranscriptController *self, SEL sel) {
    _TranscriptController$loadView(self, sel);

    if (NSString *path = $getTheme$([NSArray arrayWithObjects:@"SMSBackground.png", @"SMSBackground.jpg", nil]))
        if (UIImage *image = [[UIImage alloc] initWithContentsOfFile:path]) {
            [image autorelease];

            UIView *&_transcriptTable(MSHookIvar<UIView *>(self, "_transcriptTable"));
            UIView *&_transcriptLayer(MSHookIvar<UIView *>(self, "_transcriptLayer"));
            UIView *table;
            if (&_transcriptTable != NULL)
                table = _transcriptTable;
            else if (&_transcriptLayer != NULL)
                table = _transcriptLayer;
            else
                table = nil;

            UIView *placard(table != nil ? [table superview] : MSHookIvar<UIView *>(self, "_backPlacard"));
            UIImageView *background([[[UIImageView alloc] initWithImage:image] autorelease]);

            if (table == nil)
                [placard insertSubview:background atIndex:0];
            else {
                [table setBackgroundColor:[UIColor clearColor]];
                [placard insertSubview:background belowSubview:table];
            }
        }
}

MSHook(UIImage *, _UIImageWithName, NSString *name) {
    int id(_UISharedImageNameGetIdentifier(name));
    if (Debug_)
        NSLog(@"WB:Debug: _UIImageWithName(\"%@\": %d)", name, id);

    if (id == -1)
        return _UIImageAtPath(name, _UIKitBundle());
    else {
        NSNumber *key([NSNumber numberWithInt:id]);
        UIImage *image = [UIImages_ objectForKey:key];
        if (image != nil)
            return reinterpret_cast<id>(image) == [NSNull null] ? _UISharedImageWithIdentifier(id) : image;
        if (NSString *path = $pathForFile$inBundle$(name, _UIKitBundle(), true)) {
            image = [[UIImage alloc] initWithContentsOfFile:path cache:true];
            if (image != nil)
                [image autorelease];
        }
        [UIImages_ setObject:(image == nil ? [NSNull null] : reinterpret_cast<id>(image)) forKey:key];
        return image == nil ? _UISharedImageWithIdentifier(id) : image;
    }
}

MSHook(UIImage *, _UIImageWithNameInDomain, NSString *name, NSString *domain) {
    NSString *key([NSString stringWithFormat:@"D:%zu%@%@", [domain length], domain, name]);
    UIImage *image([PathImages_ objectForKey:key]);
    if (image != nil)
        return reinterpret_cast<id>(image) == [NSNull null] ? __UIImageWithNameInDomain(name, domain) : image;
    if (Debug_)
        NSLog(@"WB:Debug: UIImageWithNameInDomain(\"%@\", \"%@\")", name, domain);
    if (NSString *path = $getTheme$([NSArray arrayWithObject:[NSString stringWithFormat:@"Domains/%@/%@", domain, name]])) {
        image = [[UIImage alloc] initWithContentsOfFile:path];
        if (image != nil)
            [image autorelease];
    }
    [PathImages_ setObject:(image == nil ? [NSNull null] : reinterpret_cast<id>(image)) forKey:key];
    return image == nil ? __UIImageWithNameInDomain(name, domain) : image;
}

MSHook(GSFontRef, GSFontCreateWithName, const char *name, GSFontSymbolicTraits traits, float size) {
    if (Debug_)
        NSLog(@"WB:Debug: GSFontCreateWithName(\"%s\", %f)", name, size);
    if (NSString *font = [Info_ objectForKey:[NSString stringWithFormat:@"FontName-%s", name]])
        name = [font UTF8String];
    return _GSFontCreateWithName(name, traits, size);
}

#define AudioToolbox "/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox"
#define UIKit "/System/Library/Frameworks/UIKit.framework/UIKit"

bool (*_Z24GetFileNameForThisActionmPcRb)(unsigned long a0, char *a1, bool &a2);

MSHook(bool, _Z24GetFileNameForThisActionmPcRb, unsigned long a0, char *a1, bool &a2) {
    if (Debug_)
        NSLog(@"WB:Debug:GetFileNameForThisAction(%u, %p, %u)", a0, a1, a2);
    bool value = __Z24GetFileNameForThisActionmPcRb(a0, a1, a2);
    if (Debug_)
        NSLog(@"WB:Debug:GetFileNameForThisAction(%u, %s, %u) = %u", a0, value ? a1 : NULL, a2, value);

    if (value) {
        NSString *path = [NSString stringWithUTF8String:a1];
        if ([path hasPrefix:@"/System/Library/Audio/UISounds/"]) {
            NSString *file = [path substringFromIndex:31];
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
    if (WallpaperFile_ != nil) {
        image = [[UIImage alloc] initWithContentsOfFile:WallpaperFile_];
        if (image != nil)
            image = [image autorelease];
    } else image = nil;

    if (WallpaperImage_ != nil)
        [WallpaperImage_ setImage:image];
    if (WallpaperPage_ != nil)
        [WallpaperPage_ loadRequest:[NSURLRequest requestWithURL:WallpaperURL_]];

}

#define WBRename(name, sel, imp) \
    _ ## name ## $ ## imp = MSHookMessage($ ## name, @selector(sel), &$ ## name ## $ ## imp)

template <typename Type_>
static void nlset(Type_ &function, struct nlist *nl, size_t index) {
    struct nlist &name(nl[index]);
    uintptr_t value(name.n_value);
    if ((name.n_desc & N_ARM_THUMB_DEF) != 0)
        value |= 0x00000001;
    function = reinterpret_cast<Type_>(value);
}

template <typename Type_>
static void dlset(Type_ &function, const char *name) {
    function = reinterpret_cast<Type_>(dlsym(RTLD_DEFAULT, name));
}

extern "C" void WBInitialize() {
    NSAutoreleasePool *pool([[NSAutoreleasePool alloc] init]);

    NSString *identifier([[NSBundle mainBundle] bundleIdentifier]);

    NSLog(@"WB:Notice: WinterBoard");

    dlset(_GSFontGetUseLegacyFontMetrics, "GSFontGetUseLegacyFontMetrics");

    struct nlist nl[8];

    memset(nl, 0, sizeof(nl));
    nl[0].n_un.n_name = (char *) "__UIApplicationImageWithName";
    nl[1].n_un.n_name = (char *) "__UIImageAtPath";
    nl[2].n_un.n_name = (char *) "__UIImageRefAtPath";
    nl[3].n_un.n_name = (char *) "__UIImageWithNameInDomain";
    nl[4].n_un.n_name = (char *) "__UIKitBundle";
    nl[5].n_un.n_name = (char *) "__UISharedImageNameGetIdentifier";
    nl[6].n_un.n_name = (char *) "__UISharedImageWithIdentifier";
    nlist(UIKit, nl);

    nlset(_UIApplicationImageWithName, nl, 0);
    nlset(_UIImageAtPath, nl, 1);
    nlset(_UIImageRefAtPath, nl, 2);
    nlset(_UIImageWithNameInDomain, nl, 3);
    nlset(_UIKitBundle, nl, 4);
    nlset(_UISharedImageNameGetIdentifier, nl, 5);
    nlset(_UISharedImageWithIdentifier, nl, 6);

    MSHookFunction(_UIApplicationImageWithName, &$_UIApplicationImageWithName, &__UIApplicationImageWithName);
    MSHookFunction(_UIImageRefAtPath, &$_UIImageRefAtPath, &__UIImageRefAtPath);
    MSHookFunction(_UIImageWithName, &$_UIImageWithName, &__UIImageWithName);
    MSHookFunction(_UIImageWithNameInDomain, &$_UIImageWithNameInDomain, &__UIImageWithNameInDomain);

    MSHookFunction(&GSFontCreateWithName, &$GSFontCreateWithName, &_GSFontCreateWithName);

    if (dlopen(AudioToolbox, RTLD_LAZY | RTLD_NOLOAD) != NULL) {
        struct nlist nl[2];
        memset(nl, 0, sizeof(nl));
        nl[0].n_un.n_name = (char *) "__Z24GetFileNameForThisActionmPcRb";
        nlist(AudioToolbox, nl);
        nlset(_Z24GetFileNameForThisActionmPcRb, nl, 0);
        MSHookFunction(_Z24GetFileNameForThisActionmPcRb, &$_Z24GetFileNameForThisActionmPcRb, &__Z24GetFileNameForThisActionmPcRb);
    }

    $NSBundle = objc_getClass("NSBundle");

    _NSBundle$localizedStringForKey$value$table$ = MSHookMessage($NSBundle, @selector(localizedStringForKey:value:table:), &$NSBundle$localizedStringForKey$value$table$);
    _NSBundle$pathForResource$ofType$ = MSHookMessage($NSBundle, @selector(pathForResource:ofType:), &$NSBundle$pathForResource$ofType$);

    $UIImage = objc_getClass("UIImage");
    $UINavigationBar = objc_getClass("UINavigationBar");
    $UIToolbar = objc_getClass("UIToolbar");

    _UIImage$defaultDesktopImage = MSHookMessage(object_getClass($UIImage), @selector(defaultDesktopImage), &$UIImage$defaultDesktopImage);

    //WBRename("UINavigationBar", @selector(initWithCoder:), (IMP) &UINavigationBar$initWithCoder$);
    //WBRename("UINavigationBarBackground", @selector(initWithFrame:withBarStyle:withTintColor:), (IMP) &UINavigationBarBackground$initWithFrame$withBarStyle$withTintColor$);

    _UINavigationBar$setBarStyle$ = MSHookMessage($UINavigationBar, @selector(setBarStyle:), &$UINavigationBar$setBarStyle$);
    _UIToolbar$setBarStyle$ = MSHookMessage($UIToolbar, @selector(setBarStyle:), &$UIToolbar$setBarStyle$);

    Manager_ = [[NSFileManager defaultManager] retain];
    UIImages_ = [[NSMutableDictionary alloc] initWithCapacity:16];
    PathImages_ = [[NSMutableDictionary alloc] initWithCapacity:16];
    Strings_ = [[NSMutableDictionary alloc] initWithCapacity:0];
    Bundles_ = [[NSMutableDictionary alloc] initWithCapacity:2];
    Themed_ = [[NSMutableDictionary alloc] initWithCapacity:128];

    themes_ = [[NSMutableArray alloc] initWithCapacity:8];

    if (NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"/User/Library/Preferences/com.saurik.WinterBoard.plist"]]) {
        if (NSNumber *value = [settings objectForKey:@"SummerBoard"])
            SummerBoard_ = [value boolValue];
        if (NSNumber *value = [settings objectForKey:@"Debug"])
            Debug_ = [value boolValue];

        NSArray *themes([settings objectForKey:@"Themes"]);
        if (themes == nil)
            if (NSString *theme = [settings objectForKey:@"Theme"])
                themes = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
                    theme, @"Name",
                    [NSNumber numberWithBool:true], @"Active",
                nil]];

        if (themes != nil)
            for (NSDictionary *theme in themes) {
                NSNumber *active([theme objectForKey:@"Active"]);
                if (![active boolValue])
                    continue;

                NSString *name([theme objectForKey:@"Name"]);
                if (name == nil)
                    continue;

                NSString *theme(nil);

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
        if (NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Info.plist", theme]])
            for (NSString *key in [info allKeys])
                if ([Info_ objectForKey:key] == nil)
                    [Info_ setObject:[info objectForKey:key] forKey:key];

    bool sms($getTheme$([NSArray arrayWithObjects:@"SMSBackground.png", @"SMSBackground.jpg", nil]) != nil);

    if ([NSBundle bundleWithIdentifier:@"com.apple.chatkit"])
        if (sms) {
            $CKMessageCell = objc_getClass("CKMessageCell");
            _CKMessageCell$addBalloonView$ = MSHookMessage($CKMessageCell, @selector(addBalloonView:), &$CKMessageCell$addBalloonView$);
            _CKMessageCell$initWithStyle$reuseIdentifier$ = MSHookMessage($CKMessageCell, @selector(initWithStyle:reuseIdentifier:), &$CKMessageCell$initWithStyle$reuseIdentifier$);

            $CKTranscriptTableView = objc_getClass("CKTranscriptTableView");
            _CKTranscriptTableView$setSeparatorStyle$ = MSHookMessage($CKTranscriptTableView, @selector(setSeparatorStyle:), &$CKTranscriptTableView$setSeparatorStyle$);
            _CKTranscriptTableView$initWithFrame$style$ = MSHookMessage($CKTranscriptTableView, @selector(initWithFrame:style:), &$CKTranscriptTableView$initWithFrame$style$);

            $CKTimestampView = objc_getClass("CKTimestampView");
            _CKTimestampView$initWithStyle$reuseIdentifier$ = MSHookMessage($CKTimestampView, @selector(initWithStyle:reuseIdentifier:), &$CKTimestampView$initWithStyle$reuseIdentifier$);

            $CKTranscriptController = objc_getClass("CKTranscriptController");
            _TranscriptController$loadView = MSHookMessage($CKTranscriptController, @selector(loadView), &$TranscriptController$loadView);
        }

    if ([identifier isEqualToString:@"com.apple.MobileSMS"]) {
        if (sms) {
            if (_TranscriptController$loadView == NULL) {
                Class mSMSMessageTranscriptController = objc_getClass("mSMSMessageTranscriptController");
                _TranscriptController$loadView = MSHookMessage(mSMSMessageTranscriptController, @selector(loadView), &$TranscriptController$loadView);
            }
        }
    } else if ([identifier isEqualToString:@"com.apple.springboard"]) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, &ChangeWallpaper, (CFStringRef) @"com.saurik.winterboard.lockbackground", NULL, 0
        );

        /*
        if ($getTheme$([NSArray arrayWithObjects:@"Wallpaper.mp4"]) != nil) {
            NSBundle *MediaPlayer([NSBundle bundleWithPath:@"/System/Library/Frameworks/MediaPlayer.framework"]);
            if (MediaPlayer != nil)
                [MediaPlayer load];

            $MPMoviePlayerController = objc_getClass("MPMoviePlayerController");
            $MPVideoView = objc_getClass("MPVideoView");
        }*/

        $WebCoreFrameBridge = objc_getClass("WebCoreFrameBridge");

        $SBApplication = objc_getClass("SBApplication");
        $SBApplicationIcon = objc_getClass("SBApplicationIcon");
        $SBAwayView = objc_getClass("SBAwayView");
        $SBBookmarkIcon = objc_getClass("SBBookmarkIcon");
        $SBButtonBar = objc_getClass("SBButtonBar");
        $SBCalendarIconContentsView = objc_getClass("SBCalendarIconContentsView");
        $SBIcon = objc_getClass("SBIcon");
        $SBIconBadge = objc_getClass("SBIconBadge");
        $SBIconController = objc_getClass("SBIconController");
        $SBIconLabel = objc_getClass("SBIconLabel");
        $SBIconList = objc_getClass("SBIconList");
        $SBIconModel = objc_getClass("SBIconModel");
        //$SBImageCache = objc_getClass("SBImageCache");
        $SBSearchView = objc_getClass("SBSearchView");
        $SBSearchTableViewCell = objc_getClass("SBSearchTableViewCell");
        $SBStatusBarContentsView = objc_getClass("SBStatusBarContentsView");
        $SBStatusBarController = objc_getClass("SBStatusBarController");
        $SBStatusBarOperatorNameView = objc_getClass("SBStatusBarOperatorNameView");
        $SBStatusBarTimeView = objc_getClass("SBStatusBarTimeView");
        $SBUIController = objc_getClass("SBUIController");
        $SBWidgetApplicationIcon = objc_getClass("SBWidgetApplicationIcon");

        WBRename(WebCoreFrameBridge, renderedSizeOfNode:constrainedToWidth:, renderedSizeOfNode$constrainedToWidth$);

        if (SummerBoard_) {
            WBRename(SBApplication, pathForIcon, pathForIcon);
            WBRename(SBApplicationIcon, icon, icon);
        }

        WBRename(SBBookmarkIcon, icon, icon);
        WBRename(SBButtonBar, didMoveToSuperview, didMoveToSuperview);
        WBRename(SBCalendarIconContentsView, drawRect:, drawRect$);
        WBRename(SBIcon, setAlpha:, setAlpha$);
        WBRename(SBIconBadge, initWithBadge:, initWithBadge$);
        WBRename(SBIconController, noteNumberOfIconListsChanged, noteNumberOfIconListsChanged);
        WBRename(SBUIController, init, init);
        WBRename(SBWidgetApplicationIcon, icon, icon);

        WBRename(SBIconLabel, drawRect:, drawRect$);
        WBRename(SBIconLabel, initWithSize:label:, initWithSize$label$);
        WBRename(SBIconLabel, setInDock:, setInDock$);

        WBRename(SBIconList, setFrame:, setFrame$);

        WBRename(SBIconModel, cacheImageForIcon:, cacheImageForIcon$);
        WBRename(SBIconModel, cacheImagesForIcon:, cacheImagesForIcon$);
        WBRename(SBIconModel, getCachedImagedForIcon:, getCachedImagedForIcon$);
        WBRename(SBIconModel, getCachedImagedForIcon:smallIcon:, getCachedImagedForIcon$smallIcon$);

        WBRename(SBSearchView, initWithFrame:, initWithFrame$);
        WBRename(SBSearchTableViewCell, drawRect:, drawRect$);
        WBRename(SBSearchTableViewCell, initWithStyle:reuseIdentifier:, initWithStyle$reuseIdentifier$);

        //WBRename(SBImageCache, initWithName:forImageWidth:imageHeight:initialCapacity:, initWithName$forImageWidth$imageHeight$initialCapacity$);

        WBRename(SBAwayView, updateDesktopImage:, updateDesktopImage$);
        WBRename(SBStatusBarContentsView, didMoveToSuperview, didMoveToSuperview);
        //WBRename(SBStatusBarContentsView, initWithStatusBar:mode:, initWithStatusBar$mode$);
        //WBRename(SBStatusBarController, setStatusBarMode:orientation:duration:animation:, setStatusBarMode$orientation$duration$animation$);
        WBRename(SBStatusBarController, setStatusBarMode:orientation:duration:fenceID:animation:, setStatusBarMode$orientation$duration$fenceID$animation$);
        WBRename(SBStatusBarController, setStatusBarMode:orientation:duration:fenceID:animation:startTime:, setStatusBarMode$orientation$duration$fenceID$animation$startTime$);
        WBRename(SBStatusBarOperatorNameView, operatorNameStyle, operatorNameStyle);
        WBRename(SBStatusBarOperatorNameView, setOperatorName:fullSize:, setOperatorName$fullSize$);
        WBRename(SBStatusBarTimeView, drawRect:, drawRect$);

        if (SummerBoard_)
            English_ = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/English.lproj/LocalizedApplicationNames.strings"];

        Cache_ = [[NSMutableDictionary alloc] initWithCapacity:64];
    }

    Wallpapers_ = [[NSArray arrayWithObjects:@"Wallpaper.mp4", @"Wallpaper.png", @"Wallpaper.jpg", @"Wallpaper.html", nil] retain];

    if ([Info_ objectForKey:@"UndockedIconLabels"] == nil)
        [Info_ setObject:[NSNumber numberWithBool:(
            $getTheme$(Wallpapers_) == nil ||
            [Info_ objectForKey:@"DockedIconLabelStyle"] != nil ||
            [Info_ objectForKey:@"UndockedIconLabelStyle"] != nil
        )] forKey:@"UndockedIconLabels"];

    if (Debug_)
        NSLog(@"WB:Debug:Info = %@", [Info_ description]);

    [pool release];
}
