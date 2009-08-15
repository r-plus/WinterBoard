#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <UIKit/UIKeyboard.h>
#import <UIKit/UIImage.h>

extern "C" {
    #include <mach-o/nlist.h>
}

extern "C" NSData *UIImagePNGRepresentation(UIImage *image);

template <typename Type_>
static void nlset(Type_ &function, struct nlist *nl, size_t index) {
    struct nlist &name(nl[index]);
    uintptr_t value(name.n_value);
    if ((name.n_desc & N_ARM_THUMB_DEF) != 0)
        value |= 0x00000001;
    function = reinterpret_cast<Type_>(value);
}

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    struct nlist nl[4];

    memset(nl, 0, sizeof(nl));
    nl[0].n_un.n_name = (char *) "___mappedImages";
    nl[1].n_un.n_name = (char *) "__UISharedImageInitialize";
    nl[2].n_un.n_name = (char *) "_LoadMappedImageRef";
    nlist("/System/Library/Frameworks/UIKit.framework/UIKit", nl);

    NSMutableDictionary **images;
    nlset(images, nl, 0);

    void (*__UISharedImageInitialize)(bool);
    nlset(__UISharedImageInitialize, nl, 1);

    CGImageRef (*_LoadMappedImageRef)(CFStringRef);
    nlset(_LoadMappedImageRef, nl, 2);

    __UISharedImageInitialize(false);

    NSArray *keys = [*images allKeys];
    for (int i(0), e([keys count]); i != e; ++i) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSString *key = [keys objectAtIndex:i];
        CGImageRef ref;
        if (_LoadMappedImageRef == NULL)
            ref = reinterpret_cast<CGImageRef>([*images objectForKey:key]);
        else
            ref = _LoadMappedImageRef(reinterpret_cast<CFStringRef>(key));
        UIImage *image = [UIImage imageWithCGImage:ref];
        NSData *data = UIImagePNGRepresentation(image);
        [data writeToFile:[NSString stringWithFormat:@"%@", key] atomically:YES];
        [pool release];
    }

    [pool release];
    return 0;
}
