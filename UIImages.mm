#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <UIKit/UIKeyboard.h>
#import <UIKit/UIImage.h>

extern "C" {
    #include <mach-o/nlist.h>
}

extern "C" NSData *UIImagePNGRepresentation(UIImage *image);

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    struct nlist nl[3];
    memset(nl, 0, sizeof(nl));
    nl[0].n_un.n_name = (char *) "___mappedImages";
    nl[1].n_un.n_name = (char *) "__UISharedImageInitialize";
    nlist("/System/Library/Frameworks/UIKit.framework/UIKit", nl);
    NSMutableDictionary **images = (id *) nl[0].n_value;
    void (*__UISharedImageInitialize)(bool) = (void (*)(bool)) nl[1].n_value;

    __UISharedImageInitialize(false);
    [UIKeyboard preheatArtwork];

    NSArray *keys = [*images allKeys];
    for (int i(0), e([keys count]); i != e; ++i) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSString *key = [keys objectAtIndex:i];
        CGImageRef ref = (CGImageRef) [*images objectForKey:key];
        UIImage *image = [UIImage imageWithCGImage:ref];
        NSData *data = UIImagePNGRepresentation(image);
        [data writeToFile:[NSString stringWithFormat:@"%@", key] atomically:YES];
        [pool release];
    }

    [pool release];
    return 0;
}
