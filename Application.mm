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

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIKit.h>

#define _trace() NSLog(@"_trace(%u)", __LINE__);

@interface WBApplication : UIApplication <
    UITableViewDataSource,
    UITableViewDelegate
> {
    UIWindow *window_;
    UITableView *themesTable_;
    NSMutableArray *themesArray_;
}

@end

@implementation WBApplication

- (void) dealloc {
    [window_ release];
    [themesTable_ release];
    [themesArray_ release];
    [super dealloc];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero] autorelease];
    cell.text = [themesArray_ objectAtIndex:[indexPath row]];
    return cell;
}

- (NSInteger) tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return [themesArray_ count];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *theme = [themesArray_ objectAtIndex:[indexPath row]];

    [[NSDictionary dictionaryWithObjectsAndKeys:
        theme, @"Theme",
    nil] writeToFile:[NSString stringWithFormat:@"%@/Library/Preferences/com.saurik.WinterBoard.plist",
        NSHomeDirectory()
    ] atomically:YES];

    if (fork() == 0) {
        execlp("killall", "killall", "SpringBoard", NULL);
        exit(0);
    }
}

- (void) applicationDidFinishLaunching:(id)unused {
    window_ = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    [window_ makeKeyAndVisible];

    themesArray_ = [[NSMutableArray arrayWithCapacity:32] retain];
    NSFileManager *manager = [NSFileManager defaultManager];

    [themesArray_ addObjectsFromArray:[manager contentsOfDirectoryAtPath:@"/Library/Themes" error:NULL]];
    [themesArray_ addObjectsFromArray:[manager contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Library/SummerBoard/Themes", NSHomeDirectory()] error:NULL]];

    themesTable_ = [[UITableView alloc] initWithFrame:window_.bounds];
    [window_ addSubview:themesTable_];

    [themesTable_ setDataSource:self];
    [themesTable_ setDelegate:self];

    [themesTable_ setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
}

@end

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    int value = UIApplicationMain(argc, argv, @"WBApplication", @"WBApplication");

    [pool release];
    return value;
}
