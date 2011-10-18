/* WinterBoard - Theme Manager for the iPhone
 * Copyright (C) 2008-2011  Jay Freeman (saurik)
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
    NSLog(@"%lu.%.6u[%f]:_trace()@%s:%u[%s]\n", \
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
#import <ImageIO/CGImageSource.h>

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

#include <sys/sysctl.h>

#include "WBMarkup.h"

extern "C" void __clear_cache (char *beg, char *end);

@protocol WinterBoard
- (void *) _node;
@end

Class $MPMoviePlayerController;
Class $MPVideoView;

MSClassHook(NSBundle)
MSClassHook(NSString)

MSClassHook(UIImage)
MSClassHook(UINavigationBar)
MSClassHook(UIToolbar)

MSClassHook(CKMessageCell)
MSClassHook(CKTimestampView)
MSClassHook(CKTranscriptController)
MSClassHook(CKTranscriptTableView)

MSClassHook(SBApplication)
MSClassHook(SBApplicationIcon)
MSClassHook(SBAwayView)
MSClassHook(SBBookmarkIcon)
MSClassHook(SBButtonBar)
MSClassHook(SBCalendarApplicationIcon)
MSClassHook(SBCalendarIconContentsView)
MSClassHook(SBDockIconListView)
MSClassHook(SBIcon)
MSClassHook(SBIconBadge)
MSClassHook(SBIconBadgeFactory)
MSClassHook(SBIconController)
MSClassHook(SBIconLabel)
MSClassHook(SBIconList)
MSClassHook(SBIconModel)
//MSClassHook(SBImageCache)
MSClassHook(SBSearchView)
MSClassHook(SBSearchTableViewCell)
MSClassHook(SBStatusBarContentsView)
MSClassHook(SBStatusBarController)
MSClassHook(SBStatusBarOperatorNameView)
MSClassHook(SBStatusBarTimeView)
MSClassHook(SBUIController)
MSClassHook(SBWidgetApplicationIcon)

extern "C" void WKSetCurrentGraphicsContext(CGContextRef);

__attribute__((__constructor__))
static void MSFixClass() {
    if ($SBIcon == nil)
        $SBIcon = objc_getClass("SBIconView");
    if ($CKTranscriptController == nil)
        $CKTranscriptController = objc_getClass("mSMSMessageTranscriptController");
}

static bool IsWild_;
static bool Four_($SBDockIconListView != nil);

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

static bool Debug_ = false;
static bool Engineer_ = false;
static bool SummerBoard_ = true;
static bool SpringBoard_;

static UIImage *(*_UIApplicationImageWithName)(NSString *name);
static UIImage *(*_UIImageWithNameInDomain)(NSString *name, NSString *domain);
static NSBundle *(*_UIKitBundle)();
static bool (*_UIPackedImageTableGetIdentifierForName)(NSString *, int *);
static int (*_UISharedImageNameGetIdentifier)(NSString *);

static NSMutableDictionary *UIImages_ = [[NSMutableDictionary alloc] initWithCapacity:32];
static NSMutableDictionary *PathImages_ = [[NSMutableDictionary alloc] initWithCapacity:16];
static NSMutableDictionary *Cache_ = [[NSMutableDictionary alloc] initWithCapacity:64];
static NSMutableDictionary *Strings_ = [[NSMutableDictionary alloc] initWithCapacity:0];
static NSMutableDictionary *Bundles_ = [[NSMutableDictionary alloc] initWithCapacity:2];

static NSFileManager *Manager_;
static NSMutableArray *Themes_;

static NSDictionary *English_;
static NSMutableDictionary *Info_;

// $getTheme$() {{{
static NSMutableDictionary *Themed_ = [[NSMutableDictionary alloc] initWithCapacity:128];

static unsigned Scale_ = 0;

static unsigned $getScale$(NSString *path) {
    NSString *name(path);

    #define StripName(strip) \
        if ([name hasSuffix:@ strip]) \
            name = [name substringWithRange:NSMakeRange(0, [name length] - sizeof(strip) - 1)];

    StripName(".png");
    StripName(".jpg");
    StripName("~iphone");
    StripName("~ipad");

    return [name hasSuffix:@"@2x"] ? 2 : 1;
}

static NSArray *$useScale$(NSArray *files, bool use = true) {
    if (!use)
        return files;

    if (Scale_ == 0) {
        UIScreen *screen([UIScreen mainScreen]);
        if ([screen respondsToSelector:@selector(scale)])
            Scale_ = [screen scale];
        else
            Scale_ = 1;
    }

    if (Scale_ == 1)
        return files;

    NSMutableArray *scaled([NSMutableArray arrayWithCapacity:([files count] * 2)]);

    for (NSString *file in files) {
        [scaled addObject:[NSString stringWithFormat:@"%@@2x.%@", [file stringByDeletingPathExtension], [file pathExtension]]];
        [scaled addObject:file];
    }

    return scaled;
}

static NSString *$getTheme$(NSArray *files, NSArray *themes = Themes_) {
    if (NSString *path = [Themed_ objectForKey:files])
        return reinterpret_cast<id>(path) == [NSNull null] ? nil : path;

    if (Debug_)
        NSLog(@"WB:Debug: %@", [files description]);

    NSString *path;

    for (NSString *theme in Themes_)
        for (NSString *file in files) {
            path = [NSString stringWithFormat:@"%@/%@", theme, file];
            if ([Manager_ fileExistsAtPath:path])
                goto set;
        }

    path = nil;
  set:

    [Themed_ setObject:(path == nil ? [NSNull null] : reinterpret_cast<id>(path)) forKey:files];
    return path;
}
// }}}
// $pathForFile$inBundle$() {{{
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
        else if ([file isEqualToString:(oldname)]) \
            [names addObject:[NSString stringWithFormat:@"%@.png", newname]]; \

    bool summer(SpringBoard_ && SummerBoard_);

    if (identifier == nil);
    else if ([identifier isEqualToString:@"com.apple.chatkit"])
        [names addObject:[NSString stringWithFormat:@"Bundles/com.apple.MobileSMS/%@", file]];
    else if ([identifier isEqualToString:@"com.apple.calculator"])
        [names addObject:[NSString stringWithFormat:@"Files/Applications/Calculator.app/%@", file]];
    else if (!summer);
        remapResourceName(@"FSO_BG.png", @"StatusBar")
        remapResourceName(Four_ ? @"SBDockBG-old.png" : @"SBDockBG.png", @"Dock")
        remapResourceName(@"SBWeatherCelsius.png", @"Icons/Weather")

    if (NSString *path = $getTheme$($useScale$(names, ui)))
        return path;

    return nil;
}
// }}}

static NSString *$pathForIcon$(SBApplication *self, NSString *suffix = @"") {
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
            [names addObject:[NSString stringWithFormat:@"Icons%@/%@.png", suffix, name]];

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

// -[NSBundle wb$bundleWithFile] {{{
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
// }}}
// -[NSString wb$themedPath] {{{
@interface NSString (WinterBoard)
- (NSString *) wb$themedPath;
@end

@implementation NSString (WinterBoard)

- (NSString *) wb$themedPath {
    if ([self hasPrefix:@"/Library/Themes/"])
        return self;

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
// }}}

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

MSHook(UIImage *, SBApplicationIcon$generateIconImage$, SBApplicationIcon *self, SEL sel, int type) {
    if (type == 2)
        if (![Info_ wb$boolForKey:@"ComposeStoreIcons"]) {
            if (IsWild_ && false) // XXX: delete this code, it should not be supported
                if (NSString *path72 = $pathForIcon$([self application], @"-72"))
                    return [UIImage imageWithContentsOfFile:path72];
            if (NSString *path = $pathForIcon$([self application]))
                if (UIImage *image = [UIImage imageWithContentsOfFile:path]) {
                    float width;
                    if ([$SBIcon respondsToSelector:@selector(defaultIconImageSize)])
                        width = [$SBIcon defaultIconImageSize].width;
                    else
                        width = 59;
                    return width == 59 ? image : [image _imageScaledToProportion:(width / 59.0) interpolationQuality:5];
                }
        }
    return _SBApplicationIcon$generateIconImage$(self, sel, type);
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

// %hook -[NSBundle pathForResource:ofType:] {{{
MSInstanceMessageHook2(NSString *, NSBundle, pathForResource,ofType, NSString *, resource, NSString *, type) {
    NSString *file = type == nil ? resource : [NSString stringWithFormat:@"%@.%@", resource, type];
    if (Debug_)
        NSLog(@"WB:Debug: [NSBundle(%@) pathForResource:\"%@\"]", [self bundleIdentifier], file);
    if (NSString *path = $pathForFile$inBundle$(file, self, false))
        return path;
    return MSOldCall(resource, type);
}
// }}}

static struct WBStringDrawingState {
    WBStringDrawingState *next_;
    NSString *extra_;
    NSString *key_;
} *stringDrawingState_;

MSInstanceMessageHook4(CGSize, NSString, drawAtPoint,forWidth,withFont,lineBreakMode, CGPoint, point, float, width, UIFont *, font, int, mode) {
    if (stringDrawingState_ == NULL)
        return MSOldCall(point, width, font, mode);

    NSString *style([[font markupDescription] stringByAppendingString:@";"]);

    if (NSString *extra = stringDrawingState_->extra_)
        style = [style stringByAppendingString:extra];

    if (stringDrawingState_->key_ != nil)
        if (NSString *extra = [Info_ objectForKey:stringDrawingState_->key_])
            style = [style stringByAppendingString:extra];

    stringDrawingState_ = stringDrawingState_->next_;

    [self drawAtPoint:point withStyle:style];
    return CGSizeZero;
}

MSInstanceMessageHook2(CGSize, NSString, drawAtPoint,withFont, CGPoint, point, UIFont *, font) {
    if (stringDrawingState_ == NULL)
        return MSOldCall(point, font);

    NSString *style([[font markupDescription] stringByAppendingString:@";"]);

    if (NSString *extra = stringDrawingState_->extra_)
        style = [style stringByAppendingString:extra];

    if (stringDrawingState_->key_ != nil)
        if (NSString *extra = [Info_ objectForKey:stringDrawingState_->key_])
            style = [style stringByAppendingString:extra];

    stringDrawingState_ = stringDrawingState_->next_;

    [self drawAtPoint:point withStyle:style];
    return CGSizeZero;
}

MSInstanceMessageHook1(UIImage *, SBIconBadgeFactory, checkoutBadgeImageForText, NSString *, text) {
    WBStringDrawingState badgeState = {NULL, @""
        "color: white;"
    , @"BadgeStyle"};

    stringDrawingState_ = &badgeState;

    UIImage *image(MSOldCall(text));

    stringDrawingState_ = NULL;
    return image;
}

MSInstanceMessageHook1(UIImage *, SBCalendarApplicationIcon, generateIconImage, int, type) {
    WBStringDrawingState dayState = {NULL, @""
        "color: white;"
        "text-shadow: rgba(0, 0, 0, 0.2) -1px -1px 2px;"
    , @"CalendarIconDayStyle"};

    WBStringDrawingState dateState = {&dayState, @""
        "color: #333333;"
    , @"CalendarIconDateStyle"};

    stringDrawingState_ = &dateState;

    UIImage *image(MSOldCall(type));

    stringDrawingState_ = NULL;
    return image;
}

MSHook(void, SBCalendarIconContentsView$drawRect$, SBCalendarIconContentsView *self, SEL sel, CGRect rect) {
    NSBundle *bundle([NSBundle mainBundle]);

    CFLocaleRef locale(CFLocaleCopyCurrent());
    CFDateFormatterRef formatter(CFDateFormatterCreate(NULL, locale, kCFDateFormatterNoStyle, kCFDateFormatterNoStyle));
    CFRelease(locale);

    CFDateRef now(CFDateCreate(NULL, CFAbsoluteTimeGetCurrent()));

    CFDateFormatterSetFormat(formatter, (CFStringRef) [bundle localizedStringForKey:@"CALENDAR_ICON_DAY_NUMBER_FORMAT" value:@"d" table:@"SpringBoard"]);
    CFStringRef date(CFDateFormatterCreateStringWithDate(NULL, formatter, now));
    CFDateFormatterSetFormat(formatter, (CFStringRef) [bundle localizedStringForKey:@"CALENDAR_ICON_DAY_NAME_FORMAT" value:@"cccc" table:@"SpringBoard"]);
    CFStringRef day(CFDateFormatterCreateStringWithDate(NULL, formatter, now));

    CFRelease(now);

    CFRelease(formatter);

    NSString *datestyle([@""
        "font-family: Helvetica; "
        "font-weight: bold; "
        "color: #333333; "
        "alpha: 1.0; "
    "" stringByAppendingString:(IsWild_
        ? @"font-size: 54px; "
        : @"font-size: 39px; "
    )]);

    NSString *daystyle([@""
        "font-family: Helvetica; "
        "font-weight: bold; "
        "color: white; "
        "text-shadow: rgba(0, 0, 0, 0.2) -1px -1px 2px; "
    "" stringByAppendingString:(IsWild_
        ? @"font-size: 11px; "
        : @"font-size: 9px; "
    )]);

    if (NSString *style = [Info_ objectForKey:@"CalendarIconDateStyle"])
        datestyle = [datestyle stringByAppendingString:style];
    if (NSString *style = [Info_ objectForKey:@"CalendarIconDayStyle"])
        daystyle = [daystyle stringByAppendingString:style];

    float width([self bounds].size.width);
    float leeway(10);
    CGSize datesize = [(NSString *)date sizeWithStyle:datestyle forWidth:(width + leeway)];
    CGSize daysize = [(NSString *)day sizeWithStyle:daystyle forWidth:(width + leeway)];

    unsigned base0(IsWild_ ? 89 : 70);
    if ($GSFontGetUseLegacyFontMetrics())
        base0 = base0 + 1;
    unsigned base1(IsWild_ ? 18 : 16);

    if (Four_) {
        ++base0;
        ++base1;
    }

    [(NSString *)date drawAtPoint:CGPointMake(
        (width + 1 - datesize.width) / 2, (base0 - datesize.height) / 2
    ) withStyle:datestyle];

    [(NSString *)day drawAtPoint:CGPointMake(
        (width + 1 - daysize.width) / 2, (base1 - daysize.height) / 2
    ) withStyle:daystyle];

    CFRelease(date);
    CFRelease(day);
}

// %hook -[{NavigationBar,Toolbar} setBarStyle:] {{{
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

MSInstanceMessageHook1(void, UIToolbar, setBarStyle, int, style) {
    $setBarStyle$_(@"Toolbar", style);
    return MSOldCall(style);
}

MSInstanceMessageHook1(void, UINavigationBar, setBarStyle, int, style) {
    $setBarStyle$_(@"NavigationBar", style);
    return MSOldCall(style);
}
// }}}

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
static bool Papered_;
static bool Docked_;
static NSString *WallpaperFile_;
static UIImageView *WallpaperImage_;
static UIWebDocumentView *WallpaperPage_;
static NSURL *WallpaperURL_;

#define _release(object) \
    do if (object != nil) { \
        [object release]; \
        object = nil; \
    } while (false)

static UIImage *$getImage$(NSString *path) {
    UIImage *image([UIImage imageWithContentsOfFile:path]);

    unsigned scale($getScale$(path));
    if (scale != 1 && [image respondsToSelector:@selector(setScale)])
        [image setScale:scale];

    return image;
}

// %hook -[SBUIController init] {{{
MSInstanceMessageHook0(id, SBUIController, init) {
    self = MSOldCall();
    if (self == nil)
        return nil;

    NSString *paper($getTheme$(Wallpapers_));
    if (paper != nil)
        paper = [paper stringByDeletingLastPathComponent];

    {
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = new char[size];

        if (sysctlbyname("hw.machine", machine, &size, NULL, 0) == -1) {
            perror("sysctlbyname(\"hw.machine\", ?)");
            delete [] machine;
            machine = NULL;
        }

        IsWild_ = machine != NULL && strncmp(machine, "iPad", 4) == 0;
    }

    BOOL (*GSSystemHasCapability)(CFStringRef) = reinterpret_cast<BOOL (*)(CFStringRef)>(dlsym(RTLD_DEFAULT, "GSSystemHasCapability"));

    if ([Info_ objectForKey:@"UndockedIconLabels"] == nil)
        [Info_ setObject:[NSNumber numberWithBool:(
            !(paper != nil || GSSystemHasCapability != NULL && GSSystemHasCapability(CFSTR("homescreen-wallpaper"))) ||
            [Info_ objectForKey:@"DockedIconLabelStyle"] != nil ||
            [Info_ objectForKey:@"UndockedIconLabelStyle"] != nil
        )] forKey:@"UndockedIconLabels"];

    if (Debug_)
        NSLog(@"WB:Debug:Info = %@", [Info_ description]);

    if (paper != nil) {
        UIImageView *&_wallpaperView(MSHookIvar<UIImageView *>(self, "_wallpaperView"));
        if (&_wallpaperView != NULL) {
            [_wallpaperView removeFromSuperview];
            [_wallpaperView release];
            _wallpaperView = nil;
        }
    }

    UIView *&_contentLayer(MSHookIvar<UIView *>(self, "_contentLayer"));
    UIView *&_contentView(MSHookIvar<UIView *>(self, "_contentView"));

    UIView **player;
    if (&_contentLayer != NULL)
        player = &_contentLayer;
    else if (&_contentView != NULL)
        player = &_contentView;
    else
        player = NULL;
    UIView *layer(player == NULL ? nil : *player);

    UIWindow *window([[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]]);
    UIView *content([[[UIView alloc] initWithFrame:[window frame]] autorelease]);
    [window setContentView:content];

    UIWindow *&_window(MSHookIvar<UIWindow *>(self, "_window"));
    [window setBackgroundColor:[_window backgroundColor]];
    [_window setBackgroundColor:[UIColor clearColor]];

    [window setLevel:-1000];
    [window setHidden:NO];

    /*if (player != NULL)
        *player = content;*/

    [content setBackgroundColor:[layer backgroundColor]];
    [layer setBackgroundColor:[UIColor clearColor]];

    UIView *indirect;
    if (!SummerBoard_ || !IsWild_)
        indirect = content;
    else {
        CGRect bounds([content bounds]);
        bounds.origin.y = -30;
        indirect = [[[UIView alloc] initWithFrame:bounds] autorelease];
        [content addSubview:indirect];
        [indirect zoomToScale:2.4];
    }

    _release(WallpaperFile_);
    _release(WallpaperImage_);
    _release(WallpaperPage_);
    _release(WallpaperURL_);

    if (paper != nil) {
        NSArray *themes([NSArray arrayWithObject:paper]);

        if (NSString *path = $getTheme$([NSArray arrayWithObject:@"Wallpaper.mp4"], themes)) {
#if UseAVController
            NSError *error;

            static AVController *controller_(nil);
            if (controller_ == nil) {
                AVQueue *queue([AVQueue avQueue]);
                controller_ = [[AVController avControllerWithQueue:queue error:&error] retain];
            }

            AVQueue *queue([controller_ queue]);

            UIView *video([[[UIView alloc] initWithFrame:[indirect bounds]] autorelease]);
            [controller_ setLayer:[video _layer]];

            AVItem *item([[[AVItem alloc] initWithPath:path error:&error] autorelease]);
            [queue appendItem:item error:&error];

            [controller_ play:&error];
#elif UseMPMoviePlayerController
            NSURL *url([NSURL fileURLWithPath:path]);
            MPMoviePlayerController *controller = [[$MPMoviePlayerController alloc] initWithContentURL:url];
	    controller.movieControlMode = MPMovieControlModeHidden;
	    [controller play];
#else
            MPVideoView *video = [[[$MPVideoView alloc] initWithFrame:[indirect bounds]] autorelease];
            [video setMovieWithPath:path];
            [video setRepeatMode:1];
            [video setRepeatGap:-1];
            [video playFromBeginning];;
#endif

            [indirect addSubview:video];
        }

        if (NSString *path = $getTheme$($useScale$([NSArray arrayWithObjects:@"Wallpaper.png", @"Wallpaper.jpg", nil]), themes)) {
            if (UIImage *image = $getImage$(path)) {
                WallpaperFile_ = [path retain];
                WallpaperImage_ = [[UIImageView alloc] initWithImage:image];
                if (NSNumber *number = [Info_ objectForKey:@"WallpaperAlpha"])
                    [WallpaperImage_ setAlpha:[number floatValue]];
                [indirect addSubview:WallpaperImage_];
            }
        }

        if (NSString *path = $getTheme$([NSArray arrayWithObject:@"Wallpaper.html"], themes)) {
            CGRect bounds = [indirect bounds];

            UIWebDocumentView *view([[[UIWebDocumentView alloc] initWithFrame:bounds] autorelease]);
            [view setAutoresizes:true];

            WallpaperPage_ = [view retain];
            WallpaperURL_ = [[NSURL fileURLWithPath:path] retain];

            [WallpaperPage_ loadRequest:[NSURLRequest requestWithURL:WallpaperURL_]];

            [view setBackgroundColor:[UIColor clearColor]];
            if ([view respondsToSelector:@selector(setDrawsBackground:)])
                [view setDrawsBackground:NO];
            [[view webView] setDrawsBackground:NO];

            [indirect addSubview:view];
        }
    }

    for (size_t i(0), e([Themes_ count]); i != e; ++i) {
        NSString *theme = [Themes_ objectAtIndex:(e - i - 1)];
        NSString *html = [theme stringByAppendingPathComponent:@"Widget.html"];
        if ([Manager_ fileExistsAtPath:html]) {
            CGRect bounds = [indirect bounds];

            UIWebDocumentView *view([[[UIWebDocumentView alloc] initWithFrame:bounds] autorelease]);
            [view setAutoresizes:true];

            NSURL *url = [NSURL fileURLWithPath:html];
            [view loadRequest:[NSURLRequest requestWithURL:url]];

            [view setBackgroundColor:[UIColor clearColor]];
            if ([view respondsToSelector:@selector(setDrawsBackground:)])
                [view setDrawsBackground:NO];
            [[view webView] setDrawsBackground:NO];

            [indirect addSubview:view];
        }
    }

    return self;
}
// }}}

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

// IconAlpha {{{
MSInstanceMessageHook1(void, SBIcon, setIconImageAlpha, float, alpha) {
    if (NSNumber *number = [Info_ objectForKey:@"IconAlpha"])
        alpha = [number floatValue];
    return MSOldCall(alpha);
}

MSInstanceMessageHook1(void, SBIcon, setIconLabelAlpha, float, alpha) {
    if (NSNumber *number = [Info_ objectForKey:@"IconAlpha"])
        alpha = [number floatValue];
    return MSOldCall(alpha);
}

MSInstanceMessageHook0(id, SBIcon, initWithDefaultSize) {
    if ((self = MSOldCall()) != nil) {
        if (NSNumber *number = [Info_ objectForKey:@"IconAlpha"]) {
            // XXX: note: this is overridden above, which is silly
            float alpha([number floatValue]);
            [self setIconImageAlpha:alpha];
            [self setIconLabelAlpha:alpha];
        }
    } return self;
}

MSInstanceMessageHook1(void, SBIcon, setAlpha, float, alpha) {
    if (NSNumber *number = [Info_ objectForKey:@"IconAlpha"])
        alpha = [number floatValue];
    return MSOldCall(alpha);
}
// }}}

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

MSHook(BOOL, SBDockIconListView$shouldShowNewDock, id self, SEL sel) {
    return SummerBoard_ && Docked_ ? NO : _SBDockIconListView$shouldShowNewDock(self, sel);
}

MSHook(void, SBDockIconListView$setFrame$, id self, SEL sel, CGRect frame) {
    _SBDockIconListView$setFrame$(self, sel, frame);
}

// %hook -[NSBundle localizedStringForKey:value:table:] {{{
MSInstanceMessageHook3(NSString *, NSBundle, localizedStringForKey,value,table, NSString *, key, NSString *, value, NSString *, table) {
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
    return MSOldCall(key, value, table);
}
// }}}
// %hook -[WebCoreFrameBridge renderedSizeOfNode:constrainedToWidth:] {{{
MSClassHook(WebCoreFrameBridge)

MSInstanceMessageHook2(CGSize, WebCoreFrameBridge, renderedSizeOfNode,constrainedToWidth, id, node, float, width) {
    if (node == nil)
        return CGSizeZero;
    void **core(reinterpret_cast<void **>([node _node]));
    if (core == NULL || core[6] == NULL)
        return CGSizeZero;
    return MSOldCall(node, width);
}
// }}}

MSInstanceMessageHook1(void, SBIconLabel, drawRect, CGRect, rect) {
    CGRect bounds = [self bounds];

    static Ivar drawMoreLegibly = object_getInstanceVariable(self, "_drawMoreLegibly", NULL);

    int docked;
    Ivar ivar = object_getInstanceVariable(self, "_inDock", reinterpret_cast<void **>(&docked));
    docked = (docked & (ivar_getOffset(ivar) == ivar_getOffset(drawMoreLegibly) ? 0x2 : 0x1)) != 0;

    NSString *label(MSHookIvar<NSString *>(self, "_label"));

    NSString *style = [NSString stringWithFormat:@""
        "font-family: Helvetica; "
        "font-weight: bold; "
        "color: %@; %@"
    "", (docked || !SummerBoard_ ? @"white" : @"#b3b3b3"), (IsWild_
        ? @"font-size: 12px; "
        : @"font-size: 11px; "
    )];

    if (IsWild_)
        style = [style stringByAppendingString:@"text-shadow: rgba(0, 0, 0, 0.5) 0px 1px 0px; "];
    else if (docked)
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

// ChatKit {{{
MSInstanceMessageHook1(void, CKMessageCell, addBalloonView, CKBalloonView *, balloon) {
    MSOldCall(balloon);
    [balloon setBackgroundColor:[UIColor clearColor]];
}

MSInstanceMessageHook2(id, CKMessageCell, initWithStyle,reuseIdentifier, int, style, NSString *, reuse) {
    if ((self = MSOldCall(style, reuse)) != nil) {
        [[self contentView] setBackgroundColor:[UIColor clearColor]];
    } return self;
}

MSInstanceMessageHook2(id, CKTimestampView, initWithStyle,reuseIdentifier, int, style, NSString *, reuse) {
    if ((self = MSOldCall(style, reuse)) != nil) {
        UILabel *&_label(MSHookIvar<UILabel *>(self, "_label"));
        [_label setBackgroundColor:[UIColor clearColor]];
    } return self;
}

MSInstanceMessageHook1(void, CKTranscriptTableView, setSeparatorStyle, int, style) {
    MSOldCall(UITableViewCellSeparatorStyleNone);
}

MSInstanceMessageHook2(id, CKTranscriptTableView, initWithFrame,style, CGRect, frame, int, style) {
    if ((self = MSOldCall(frame, style)) != nil) {
        [self setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    } return self;
}

MSInstanceMessageHook0(void, CKTranscriptController, loadView) {
    MSOldCall();

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
// }}}

// %hook _UIImageWithName() {{{
MSHook(UIImage *, _UIImageWithName, NSString *name) {
    if (Debug_)
        NSLog(@"WB:Debug: _UIImageWithName(\"%@\")", name);
    if (name == nil)
        return nil;

    int identifier;
    bool packed;

    if (_UIPackedImageTableGetIdentifierForName != NULL)
        packed = _UIPackedImageTableGetIdentifierForName(name, &identifier);
    else if (_UISharedImageNameGetIdentifier != NULL) {
        identifier = _UISharedImageNameGetIdentifier(name);
        packed = identifier != -1;
    } else {
        identifier = -1;
        packed = false;
    }

    if (Debug_)
        NSLog(@"WB:Debug: _UISharedImageNameGetIdentifier(\"%@\") = %d", name, identifier);

    if (!packed)
        return __UIImageWithName(name);
    else {
        NSNumber *key([NSNumber numberWithInt:identifier]);
        UIImage *image([UIImages_ objectForKey:key]);
        if (image != nil)
            return reinterpret_cast<id>(image) == [NSNull null] ? __UIImageWithName(name) : image;
        if (NSString *path = $pathForFile$inBundle$(name, _UIKitBundle(), true))
            image = $getImage$(path);
        [UIImages_ setObject:(image == nil ? [NSNull null] : reinterpret_cast<id>(image)) forKey:key];
        return image == nil ? __UIImageWithName(name) : image;
    }
}
// }}}
// %hook _UIImageWithNameInDomain() {{{
MSHook(UIImage *, _UIImageWithNameInDomain, NSString *name, NSString *domain) {
    NSString *key([NSString stringWithFormat:@"D:%zu%@%@", [domain length], domain, name]);
    UIImage *image([PathImages_ objectForKey:key]);
    if (image != nil)
        return reinterpret_cast<id>(image) == [NSNull null] ? __UIImageWithNameInDomain(name, domain) : image;
    if (Debug_)
        NSLog(@"WB:Debug: UIImageWithNameInDomain(\"%@\", \"%@\")", name, domain);
    if (NSString *path = $getTheme$($useScale$([NSArray arrayWithObject:[NSString stringWithFormat:@"Domains/%@/%@", domain, name]])))
        image = $getImage$(path);
    [PathImages_ setObject:(image == nil ? [NSNull null] : reinterpret_cast<id>(image)) forKey:key];
    return image == nil ? __UIImageWithNameInDomain(name, domain) : image;
}
// }}}

// %hook GSFontCreateWithName() {{{
MSHook(GSFontRef, GSFontCreateWithName, const char *name, GSFontSymbolicTraits traits, float size) {
    if (Debug_)
        NSLog(@"WB:Debug: GSFontCreateWithName(\"%s\", %f)", name, size);
    if (NSString *font = [Info_ objectForKey:[NSString stringWithFormat:@"FontName-%s", name]])
        name = [font UTF8String];
    //if (NSString *scale = [Info_ objectForKey:[NSString stringWithFormat:@"FontScale-%s", name]])
    //    size *= [scale floatValue];
    return _GSFontCreateWithName(name, traits, size);
}
// }}}

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
            for (NSString *theme in Themes_) {
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
static void msset(Type_ &function, MSImageRef image, const char *name) {
    function = reinterpret_cast<Type_>(MSFindSymbol(image, name));
}

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

// %hook CGImageReadCreateWithFile() {{{
MSHook(void *, CGImageReadCreateWithFile, NSString *path, int flag) {
    if (Debug_)
        NSLog(@"WB:Debug: CGImageReadCreateWithFile(%@, %d)", path, flag);
    NSAutoreleasePool *pool([[NSAutoreleasePool alloc] init]);
    void *value(_CGImageReadCreateWithFile([path wb$themedPath], flag));
    [pool release];
    return value;
}
// }}}

static void NSString$drawAtPoint$withStyle$(NSString *self, SEL _cmd, CGPoint point, NSString *style) {
    WKSetCurrentGraphicsContext(UIGraphicsGetCurrentContext());
    if (style == nil || [style length] == 0)
        style = @"font-family: Helvetica; font-size: 12px";
    return [[WBMarkup sharedMarkup] drawString:self atPoint:point withStyle:style];
}

static CGSize NSString$sizeWithStyle$forWidth$(NSString *self, SEL _cmd, NSString *style, float width) {
    if (style == nil || [style length] == 0)
        style = @"font-family: Helvetica; font-size: 12px";
    return [[WBMarkup sharedMarkup] sizeOfString:self withStyle:style forWidth:width];
}

static void SBInitialize() {
    class_addMethod($NSString, @selector(drawAtPoint:withStyle:), (IMP) &NSString$drawAtPoint$withStyle$, "v20@0:4{CGPoint=ff}8@16");
    class_addMethod($NSString, @selector(sizeWithStyle:forWidth:), (IMP) &NSString$sizeWithStyle$forWidth$, "{CGSize=ff}16@0:4@8f12");

    _UIImage$defaultDesktopImage = MSHookMessage(object_getClass($UIImage), @selector(defaultDesktopImage), &$UIImage$defaultDesktopImage);

    if (SummerBoard_) {
        WBRename(SBApplication, pathForIcon, pathForIcon);
        WBRename(SBApplicationIcon, icon, icon);
        WBRename(SBApplicationIcon, generateIconImage:, generateIconImage$);
    }

    WBRename(SBBookmarkIcon, icon, icon);
    WBRename(SBButtonBar, didMoveToSuperview, didMoveToSuperview);
    WBRename(SBCalendarIconContentsView, drawRect:, drawRect$);
    WBRename(SBIconBadge, initWithBadge:, initWithBadge$);
    WBRename(SBIconController, noteNumberOfIconListsChanged, noteNumberOfIconListsChanged);

    WBRename(SBWidgetApplicationIcon, icon, icon);

    WBRename(SBDockIconListView, setFrame:, setFrame$);
    MSHookMessage(object_getClass($SBDockIconListView), @selector(shouldShowNewDock), &$SBDockIconListView$shouldShowNewDock, &_SBDockIconListView$shouldShowNewDock);

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
}

MSInitialize {
    NSAutoreleasePool *pool([[NSAutoreleasePool alloc] init]);

    NSString *identifier([[NSBundle mainBundle] bundleIdentifier]);
    SpringBoard_ = [identifier isEqualToString:@"com.apple.springboard"];

    Manager_ = [[NSFileManager defaultManager] retain];
    Themes_ = [[NSMutableArray alloc] initWithCapacity:8];

    dlset(_GSFontGetUseLegacyFontMetrics, "GSFontGetUseLegacyFontMetrics");

    // Load Settings.plist {{{
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
                            [Themes_ addObject:path]; \
                            continue; \
                        } \
                    }

                testForTheme(@"/Library/Themes/%@.theme", name)
                testForTheme(@"/Library/Themes/%@", name)
                testForTheme(@"%@/Library/SummerBoard/Themes/%@", NSHomeDirectory(), name)

            }
    }
    // }}}
    // Merge Info.plist {{{
    Info_ = [[NSMutableDictionary dictionaryWithCapacity:16] retain];

    for (NSString *theme in Themes_)
        if (NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Info.plist", theme]])
            for (NSString *key in [info allKeys])
                if ([Info_ objectForKey:key] == nil)
                    [Info_ setObject:[info objectForKey:key] forKey:key];
    // }}}

    // AudioToolbox {{{
    if (MSImageRef image = MSGetImageByName(AudioToolbox)) {
        msset(_Z24GetFileNameForThisActionmPcRb, image, "__Z24GetFileNameForThisActionmPcRb");
        MSHookFunction(_Z24GetFileNameForThisActionmPcRb, &$_Z24GetFileNameForThisActionmPcRb, &__Z24GetFileNameForThisActionmPcRb);
    }
    // }}}
    // GraphicsServices {{{
    if (true) {
        MSHookFunction(&GSFontCreateWithName, &$GSFontCreateWithName, &_GSFontCreateWithName);
    }
    // }}}
    // ImageIO {{{
    if (MSImageRef image = MSGetImageByName("/System/Library/Frameworks/ImageIO.framework/ImageIO")) {
        void *(*CGImageReadCreateWithFile)(NSString *, int);
        msset(CGImageReadCreateWithFile, image, "_CGImageReadCreateWithFile");
        MSHookFunction(CGImageReadCreateWithFile, MSHake(CGImageReadCreateWithFile));
    }
    // }}}
    // SpringBoard {{{
    if (SpringBoard_) {
        Wallpapers_ = [[NSArray arrayWithObjects:@"Wallpaper.mp4", @"Wallpaper@2x.png", @"Wallpaper@2x.jpg", @"Wallpaper.png", @"Wallpaper.jpg", @"Wallpaper.html", nil] retain];
        Docked_ = $getTheme$([NSArray arrayWithObjects:@"Dock.png", nil]);

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, &ChangeWallpaper, (CFStringRef) @"com.saurik.winterboard.lockbackground", NULL, 0
        );

        if ($getTheme$([NSArray arrayWithObject:@"Wallpaper.mp4"]) != nil) {
            NSBundle *MediaPlayer([NSBundle bundleWithPath:@"/System/Library/Frameworks/MediaPlayer.framework"]);
            if (MediaPlayer != nil)
                [MediaPlayer load];

            $MPMoviePlayerController = objc_getClass("MPMoviePlayerController");
            $MPVideoView = objc_getClass("MPVideoView");
        }

        SBInitialize();
    }
    // }}}
    // UIKit {{{
    if ([NSBundle bundleWithIdentifier:@"com.apple.UIKit"] != nil) {
        struct nlist nl[6];
        memset(nl, 0, sizeof(nl));
        nl[0].n_un.n_name = (char *) "__UIApplicationImageWithName";
        nl[1].n_un.n_name = (char *) "__UIImageWithNameInDomain";
        nl[2].n_un.n_name = (char *) "__UIKitBundle";
        nl[3].n_un.n_name = (char *) "__UIPackedImageTableGetIdentifierForName";
        nl[4].n_un.n_name = (char *) "__UISharedImageNameGetIdentifier";
        nlist(UIKit, nl);

        nlset(_UIApplicationImageWithName, nl, 0);
        nlset(_UIImageWithNameInDomain, nl, 1);
        nlset(_UIKitBundle, nl, 2);
        nlset(_UIPackedImageTableGetIdentifierForName, nl, 3);
        nlset(_UISharedImageNameGetIdentifier, nl, 4);

        MSHookFunction(_UIApplicationImageWithName, &$_UIApplicationImageWithName, &__UIApplicationImageWithName);
        MSHookFunction(_UIImageWithName, &$_UIImageWithName, &__UIImageWithName);
        MSHookFunction(_UIImageWithNameInDomain, &$_UIImageWithNameInDomain, &__UIImageWithNameInDomain);
    }
    // }}}

    [pool release];
}
