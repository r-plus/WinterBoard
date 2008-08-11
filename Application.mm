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

#define _trace() NSLog(@"WE:_trace(%u)", __LINE__);

static NSString *plist_;
static NSMutableDictionary *settings_;
static BOOL changed_;

@interface WBThemeTableViewCell : UITableViewCell {
    UILabel *label;
}

@end

@implementation WBThemeTableViewCell


@end

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

- (void) applicationWillTerminate:(UIApplication *)application {
    if (changed_) {
        if (![settings_ writeToFile:plist_ atomically:YES])
            NSLog(@"WB:Error:writeToFile");
        system("killall SpringBoard");
    }
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero] autorelease];
    NSMutableDictionary *theme = [themesArray_ objectAtIndex:[indexPath row]];
    cell.text = [theme objectForKey:@"Name"];
    cell.hidesAccessoryWhenEditing = NO;
    NSNumber *active = [theme objectForKey:@"Active"];
    BOOL inactive = active == nil || ![active boolValue];
    cell.accessoryType = inactive ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSMutableDictionary *theme = [themesArray_ objectAtIndex:[indexPath row]];
    NSNumber *active = [theme objectForKey:@"Active"];
    BOOL inactive = active == nil || ![active boolValue];
    [theme setObject:[NSNumber numberWithBool:inactive] forKey:@"Active"];
    cell.accessoryType = inactive ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    [themesTable_ deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:YES];
    changed_ = YES;
}

- (NSInteger) tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return [themesArray_ count];
}

- (UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (void) tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    NSUInteger fromIndex = [fromIndexPath row];
    NSUInteger toIndex = [toIndexPath row];
    if (fromIndex == toIndex)
        return;
    NSMutableDictionary *theme = [[[themesArray_ objectAtIndex:fromIndex] retain] autorelease];
    [themesArray_ removeObjectAtIndex:fromIndex];
    [themesArray_ insertObject:theme atIndex:toIndex];
    changed_ = YES;
}

- (BOOL) tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void) applicationDidFinishLaunching:(id)unused {
    window_ = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    [window_ makeKeyAndVisible];

    plist_ = [[NSString stringWithFormat:@"%@/Library/Preferences/com.saurik.WinterBoard.plist",
        NSHomeDirectory()
    ] retain];

    settings_ = [[NSMutableDictionary alloc] initWithContentsOfFile:plist_];
    if (settings_ == nil)
        settings_ = [[NSMutableDictionary alloc] initWithCapacity:16];

    themesArray_ = [settings_ objectForKey:@"Themes"];
    if (themesArray_ == nil) {
        if (NSString *theme = [settings_ objectForKey:@"Theme"]) {
            themesArray_ = [[NSArray arrayWithObject:[[NSDictionary dictionaryWithObjectsAndKeys:
                theme, @"Name",
                [NSNumber numberWithBool:YES], @"Active",
            nil] mutableCopy]] mutableCopy];

            [settings_ removeObjectForKey:@"Theme"];
        }

        if (themesArray_ == nil)
            themesArray_ = [NSMutableArray arrayWithCapacity:16];
        [settings_ setObject:themesArray_ forKey:@"Themes"];
    }

    themesArray_ = [themesArray_ retain];

    NSMutableSet *themesSet = [NSMutableSet setWithCapacity:32];
    for (NSMutableDictionary *theme in themesArray_)
        if (NSString *name = [theme objectForKey:@"Name"])
            [themesSet addObject:name];

    NSFileManager *manager = [NSFileManager defaultManager];

    NSMutableArray *themes = [NSMutableArray arrayWithCapacity:32];
    [themes addObjectsFromArray:[manager contentsOfDirectoryAtPath:@"/Library/Themes" error:NULL]];
    [themes addObjectsFromArray:[manager contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Library/SummerBoard/Themes", NSHomeDirectory()] error:NULL]];

    for (NSUInteger i(0), e([themes count]); i != e; ++i) {
        NSString *theme = [themes objectAtIndex:i];
        if ([theme hasSuffix:@".theme"])
            [themes replaceObjectAtIndex:i withObject:[theme substringWithRange:NSMakeRange(0, [theme length] - 6)]];
    }

    for (NSUInteger i(0), e([themesArray_ count]); i != e; ++i) {
        NSMutableDictionary *theme = [themesArray_ objectAtIndex:i];
        NSString *name = [theme objectForKey:@"Name"];
        if (name == nil || ![themes containsObject:name]) {
            [themesArray_ removeObjectAtIndex:i];
            --i; --e;
        }
    }

    for (NSString *theme in themes) {
        if ([themesSet containsObject:theme])
            continue;
        [themesSet addObject:theme];
        [themesArray_ addObject:[[NSDictionary dictionaryWithObjectsAndKeys:
            theme, @"Name",
            [NSNumber numberWithBool:NO], @"Active",
        nil] mutableCopy]];
    }

    themesTable_ = [[UITableView alloc] initWithFrame:window_.bounds];
    [window_ addSubview:themesTable_];

    [themesTable_ setDataSource:self];
    [themesTable_ setDelegate:self];

    [themesTable_ setEditing:YES animated:NO];
    themesTable_.allowsSelectionDuringEditing = YES;

    [themesTable_ setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
}

@end

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    int value = UIApplicationMain(argc, argv, @"WBApplication", @"WBApplication");

    [pool release];
    return value;
}
