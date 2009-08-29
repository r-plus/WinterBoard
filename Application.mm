/* WinterBoard - Theme Manager for the iPhone
 * Copyright (C) 2008-2009  Jay Freeman (saurik)
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

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIKit.h>

#import <Preferences/PSRootController.h>
#import <Preferences/PSViewController.h>
#import <Preferences/PSSpecifier.h>

@interface UIApplication (Private)
- (void) terminateWithSuccess;
@end

@interface WBRootController : PSRootController {
    PSViewController *_firstViewController;
}

@property (readonly) PSViewController *firstViewController;

- (void) setupRootListForSize:(CGSize)size;
- (BOOL) popController;

@end

@implementation WBRootController

@synthesize firstViewController = _firstViewController;

- (void) setupRootListForSize:(CGSize)size {
    PSSpecifier *spec = [[PSSpecifier alloc] init];
    [spec setTarget:self];
    spec.name = @"WinterBoard";

    NSBundle *wbSettingsBundle = [NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/WinterBoardSettings.bundle"];
    [wbSettingsBundle load];

    _firstViewController = [[[wbSettingsBundle principalClass] alloc] initForContentSize:size];
    _firstViewController.rootController = self;
    _firstViewController.parentController = self;
    [_firstViewController viewWillBecomeVisible:spec];

    [spec release];

    [self pushController:_firstViewController];
}

- (BOOL) popController {
    // Pop the last controller = exit the application.
    // The only time the last controller should pop is when the user taps Respring/Cancel.
    // Which only gets displayed if the user has made changes.
    if([self lastController] == _firstViewController)
        [[UIApplication sharedApplication] terminateWithSuccess];
    return [super popController];
}
@end

@interface WBApplication : UIApplication {
    WBRootController *_rootController;
}

@end

@implementation WBApplication

- (void) dealloc {
    [_rootController release];
    [super dealloc];
}

- (void) applicationWillTerminate:(UIApplication *)application {
    [_rootController.firstViewController suspend];
}

- (void) applicationDidFinishLaunching:(id)unused {
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    _rootController = [[WBRootController alloc] initWithTitle:@"WinterBoard" identifier:[[NSBundle mainBundle] bundleIdentifier]];
    [window addSubview:_rootController.contentView];
    [window makeKeyAndVisible];
}

@end

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    int value = UIApplicationMain(argc, argv, @"WBApplication", @"WBApplication");

    [pool release];
    return value;
}
