#include <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>

@class DOMDocument;
@class DOMElement;

@class WAKWindow;
@class WebView;

@interface WBMarkup : NSObject {
    /*04*/ WebView *view_;
    /*08*/ DOMDocument *document_;
    /*0C*/ WAKWindow *window_;
    /*10*/ DOMElement *text_;
    /*14*/ DOMElement *size_;
    /*18*/ CGContextRef context_;
    /*1C*/ CGPoint origin_;
}

+ (BOOL) isSharedMarkupCreated;
+ (WBMarkup *) sharedMarkup;

- (id) init;
- (void) dealloc;

- (WebView *) _webView;

- (void) setStringDrawingOrigin:(CGPoint)origin;
- (void) clearStringDrawingOrigin;

- (CGSize) sizeOfMarkup:(NSString *)markup forWidth:(float)width;
- (CGSize) sizeOfString:(NSString *)string withStyle:(NSString *)style forWidth:(float)width;

- (NSString *) _styleFormatString:(NSString *)style;
- (void) _setupWithStyle:(NSString *)style width:(float)width height:(float)height;
- (BOOL) _webPrepareContextForTextDrawing:(BOOL)drawing;

- (void) drawMarkup:(NSString *)markup atPoint:(CGPoint)point;
- (void) drawMarkup:(NSString *)markup inRect:(CGRect)rect;

- (void) drawString:(NSString *)string atPoint:(CGPoint)point withStyle:(NSString *)style;
- (void) drawString:(NSString *)string inRect:(CGRect)rect withStyle:(NSString *)style;

@end
