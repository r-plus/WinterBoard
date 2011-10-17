#include "WBMarkup.h"

@class WKView;

extern "C" {
    void WebThreadLock();
    CGContextRef WKGetCurrentGraphicsContext();
    void WKViewLockFocus(WKView *);
    void WKViewUnlockFocus(WKView *);
    void WKViewDisplayRect(WKView *, CGRect);
}

@interface DOMElement : NSObject
- (void) setInnerHTML:(NSString *)value;
- (void) setInnerText:(NSString *)value;
- (void) setAttribute:(NSString *)name value:(NSString *)value;
- (void) removeAttribute:(NSString *)name;
- (DOMElement *) firstChild;
- (void) appendChild:(DOMElement *)child;
- (void) removeChild:(DOMElement *)child;
- (void) setScrollXOffset:(float)x scrollYOffset:(float)y;
@end

@interface DOMDocument : NSObject
- (DOMElement *) getElementById:(NSString *)id;
@end

@interface WebPreferences : NSObject
- (id) initWithIdentifier:(NSString *)identifier;
- (void) setPlugInsEnabled:(BOOL)value;
@end

@interface WebFrameView : NSObject
- (void) setAllowsScrolling:(BOOL)value;
@end

@interface WebFrame : NSObject
- (WebFrameView *) frameView;
- (void) _setLoadsSynchronously:(BOOL)value;
- (void) loadHTMLString:(NSString *)string baseURL:(id)url;
- (void) forceLayoutAdjustingViewSize:(BOOL)adjust;
- (CGSize) renderedSizeOfNode:(DOMElement *)node constrainedToWidth:(float)width;
- (DOMDocument *) DOMDocument;
@end

@interface WebView : NSObject
- (id) initWithFrame:(CGRect)frame;
- (WebFrame *) mainFrame;
- (void) setDrawsBackground:(BOOL)value;
- (void) setPreferences:(WebPreferences *)preferences;
- (WKView *) _viewRef;
@end

@interface WAKWindow : NSObject
- (id) initWithFrame:(CGRect)frame;
- (void) setContentView:(WebView *)view;
@end

static WBMarkup *SharedMarkup_;

@implementation WBMarkup

+ (BOOL) isSharedMarkupCreated {
    return SharedMarkup_ != nil;
}

+ (WBMarkup *) sharedMarkup {
    if (SharedMarkup_ == nil)
        SharedMarkup_ = [[WBMarkup alloc] init];
    return SharedMarkup_;
}

- (id) init {
    if ((self = [super init]) != nil) {
        WebThreadLock();

        SharedMarkup_ = self;

        view_ = [[WebView alloc] initWithFrame:CGRectMake(0, 0, 640, 5000)];
        [view_ setDrawsBackground:NO];

        WebPreferences *preferences([[WebPreferences alloc] initWithIdentifier:@"com.apple.webkit.webmarkup"]);
        [preferences setPlugInsEnabled:NO];
        [view_ setPreferences:preferences];
        [preferences release];

        window_ = [[WAKWindow alloc] initWithFrame:CGRectMake(0, 0, 640, 5000)];
        [window_ setContentView:view_];

        WebFrame *frame([view_ mainFrame]);
        [[frame frameView] setAllowsScrolling:NO];
        [frame _setLoadsSynchronously:YES];

        [frame loadHTMLString:@"<html><body style='margin: 0px; word-wrap: break-word; -khtml-nbsp-mode: space; -khtml-line-break: after-white-space'><div id='size'><div id='text'></div></div></body></html>" baseURL:nil];
    } return self;
}

- (void) dealloc {
    [window_ release];
    [view_ release];
    [super dealloc];
}

- (WebView *) _webView {
    return view_;
}

- (void) setStringDrawingOrigin:(CGPoint)origin {
    origin_ = origin;
}

- (void) clearStringDrawingOrigin {
    origin_ = CGPointZero;
}

- (CGSize) sizeOfMarkup:(NSString *)markup forWidth:(float)width {
    WebThreadLock();

    if (![self _webPrepareContextForTextDrawing:NO])
        return CGSizeZero;

    [text_ setInnerHTML:markup];
    [text_ removeAttribute:@"style"];

    NSString *value([[NSString alloc] initWithFormat:[self _styleFormatString:@"width: %.0fpx; height: 5000px"], width]);
    [size_ setAttribute:@"style" value:value];
    [value release];

    [[view_ mainFrame] forceLayoutAdjustingViewSize:YES];
    return [[view_ mainFrame] renderedSizeOfNode:text_ constrainedToWidth:width];
}

- (CGSize) sizeOfString:(NSString *)string withStyle:(NSString *)style forWidth:(float)width {
    WebThreadLock();

    if (![self _webPrepareContextForTextDrawing:NO])
        return CGSizeZero;

    [size_ removeChild:[size_ firstChild]];

    WebFrame *frame([view_ mainFrame]);

    [frame forceLayoutAdjustingViewSize:YES];
    [text_ setInnerText:string];
    [self _setupWithStyle:style width:width height:5000];
    [frame forceLayoutAdjustingViewSize:YES];

    return [[view_ mainFrame] renderedSizeOfNode:text_ constrainedToWidth:width];
}

- (NSString *) _styleFormatString:(NSString *)style {
    return style;
}

- (void) _setupWithStyle:(NSString *)style width:(float)width height:(float)height {
    WebThreadLock();

    if (style != nil && [style length] != 0)
        [text_ setAttribute:@"style" value:style];
    else
        [text_ removeAttribute:@"style"];

    NSString *value([[NSString alloc] initWithFormat:[self _styleFormatString:@"width: %.0fpx; height: %.0fpx"], width, height]);
    [size_ setAttribute:@"style" value:value];
    [value release];

    [size_ appendChild:text_];
}

- (BOOL) _webPrepareContextForTextDrawing:(BOOL)drawing {
    WebThreadLock();

    if (document_ == nil) {
        WebFrame *frame([view_ mainFrame]);

        document_ = [[frame DOMDocument] retain];
        if (document_ == nil) {
            NSLog(@"*** ERROR: no DOM document in text-drawing webview");
            return NO;
        }

        text_ = [[document_ getElementById:@"text"] retain];
        size_ = [[document_ getElementById:@"size"] retain];

        if (text_ == nil || size_ == nil) {
            NSLog(@"*** ERROR: cannot find DOM element required for text drawing");
            return NO;
        }
    }

    context_ = NULL;

    if (!drawing)
        context_ = NULL;
    else {
        context_ = WKGetCurrentGraphicsContext();
        if (context_ == NULL) {
            NSLog(@"*** ERROR: no CGContext set for drawing");
            return NO;
        }
    }

    return YES;
}

- (void) drawMarkup:(NSString *)markup atPoint:(CGPoint)point {
    [self drawMarkup:markup inRect:CGRectMake(point.x, point.y, 65535, 65535)];
}

- (void) drawMarkup:(NSString *)markup inRect:(CGRect)rect {
    WebThreadLock();

    if (![self _webPrepareContextForTextDrawing:YES])
        return;

    [text_ setInnerHTML:markup];
    [text_ removeAttribute:@"style"];

    NSString *value([[NSString alloc] initWithFormat:[self _styleFormatString:@"width: %.0fpx; height: %.0fpx"], CGRectGetWidth(rect), CGRectGetHeight(rect)]);
    [size_ setAttribute:@"style" value:value];
    [value release];

    [[view_ mainFrame] forceLayoutAdjustingViewSize:YES];

    [text_ setScrollXOffset:origin_.x scrollYOffset:origin_.y];

    WKView *view([view_ _viewRef]);

    CGContextSaveGState(context_); {
        CGContextTranslateCTM(context_, rect.origin.x, rect.origin.y);

        WKViewLockFocus(view); {
            WKViewDisplayRect(view, CGRectMake(0, 0, rect.origin.x, rect.origin.y));
        } WKViewUnlockFocus(view);
    } CGContextRestoreGState(context_);
}

- (void) drawString:(NSString *)string atPoint:(CGPoint)point withStyle:(NSString *)style {
    [self drawString:string inRect:CGRectMake(point.x, point.y, 65535, 65535) withStyle:style];
}

- (void) drawString:(NSString *)string inRect:(CGRect)rect withStyle:(NSString *)style {
    WebThreadLock();

    if (![self _webPrepareContextForTextDrawing:YES])
        return;

    [size_ removeChild:[size_ firstChild]];

    WebFrame *frame([view_ mainFrame]);

    [frame forceLayoutAdjustingViewSize:YES];
    [text_ setInnerText:string];
    [self _setupWithStyle:style width:CGRectGetWidth(rect) height:CGRectGetHeight(rect)];
    [frame forceLayoutAdjustingViewSize:YES];

    [text_ setScrollXOffset:origin_.x scrollYOffset:origin_.y];

    WKView *view([view_ _viewRef]);

    CGContextSaveGState(context_); {
        CGContextTranslateCTM(context_, rect.origin.x, rect.origin.y);

        WKViewLockFocus(view); {
            WKViewDisplayRect(view, CGRectMake(0, 0, rect.size.width, rect.size.height));
        } WKViewUnlockFocus(view);
    } CGContextRestoreGState(context_);
}

@end
