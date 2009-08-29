/* WinterBoard - Theme Manager for the iPhone
 * Copyright (C) 2009  Jay Freeman (saurik)
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
#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <UIKit/UINavigationButton.h>

extern NSString *PSTableCellKey;
extern "C" UIImage *_UIImageWithName(NSString *);

static UIImage *checkImage;
static UIImage *uncheckedImage;

static BOOL settingsChanged;
static NSMutableDictionary *_settings;
static NSString *_plist;

/* Theme Settings Controller {{{ */
@interface WBSThemesController: PSViewController <UITableViewDelegate, UITableViewDataSource> {
    UITableView *_tableView;
    NSMutableArray *_themes;
}

@property (nonatomic, retain) NSMutableArray *themes;

+ (void) load;

- (id) initForContentSize:(CGSize)size;
- (id) view;
- (id) navigationTitle;
- (void) themesChanged;

- (int) numberOfSectionsInTableView:(UITableView *)tableView;
- (id) tableView:(UITableView *)tableView titleForHeaderInSection:(int)section;
- (int) tableView:(UITableView *)tableView numberOfRowsInSection:(int)section;
- (id) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void) tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath;
- (UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL) tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL) tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@implementation WBSThemesController

@synthesize themes = _themes;

+ (void) load {
    NSAutoreleasePool *pool([[NSAutoreleasePool alloc] init]);
    checkImage = [_UIImageWithName(@"UIPreferencesBlueCheck.png") retain];
    uncheckedImage = [[UIImage imageWithContentsOfFile:@"/System/Library/PreferenceBundles/WinterBoardSettings.bundle/SearchResultsCheckmarkClear.png"] retain];
    [pool release];
}

- (id) initForContentSize:(CGSize)size {
    if ((self = [super initForContentSize:size]) != nil) {
        self.themes = [_settings objectForKey:@"Themes"];
        if (!_themes) {
            if (NSString *theme = [_settings objectForKey:@"Theme"]) {
                self.themes = [NSMutableArray arrayWithObject:
                         [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                            theme, @"Name",
                                [NSNumber numberWithBool:YES], @"Active", nil]];
                [_settings removeObjectForKey:@"Theme"];
            }
            if (!_themes)
                self.themes = [NSMutableArray array];
            [_settings setObject:_themes forKey:@"Themes"];
        }

        NSMutableArray *themesOnDisk([NSMutableArray array]);

        [themesOnDisk
            addObjectsFromArray:[[NSFileManager defaultManager]
            contentsOfDirectoryAtPath:@"/Library/Themes" error:NULL]
        ];

        [themesOnDisk addObjectsFromArray:[[NSFileManager defaultManager]
            contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Library/SummerBoard/Themes", NSHomeDirectory()]
            error:NULL
        ]];

        for (int i = 0, count = [themesOnDisk count]; i < count; i++) {
            NSString *theme = [themesOnDisk objectAtIndex:i];
            if ([theme hasSuffix:@".theme"])
                [themesOnDisk replaceObjectAtIndex:i withObject:[theme stringByDeletingPathExtension]];
        }

        NSMutableSet *themesSet([NSMutableSet set]);

        for (int i = 0, count = [_themes count]; i < count; i++) {
            NSDictionary *theme([_themes objectAtIndex:i]);
            NSString *name([theme objectForKey:@"Name"]);

            if (!name || ![themesOnDisk containsObject:name]) {
                [_themes removeObjectAtIndex:i];
                i--;
                count--;
            } else {
                [themesSet addObject:name];
            }
        }

        for (NSString *theme in themesOnDisk) {
            if ([themesSet containsObject:theme])
                continue;
            [themesSet addObject:theme];

            [_themes insertObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                    theme, @"Name",
                    [NSNumber numberWithBool:NO], @"Active",
            nil] atIndex:0];
        }

        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480-64) style:UITableViewStyleGrouped];
        [_tableView setDataSource:self];
        [_tableView setDelegate:self];
        [_tableView setEditing:YES];
        [_tableView setAllowsSelectionDuringEditing:YES];
        [self showLeftButton:@"WinterBoard" withStyle:1 rightButton:nil withStyle:0];
    }
    return self;
}

- (void) dealloc {
    [_tableView release];
    [_themes release];
    [super dealloc];
}

- (id) navigationTitle {
    return @"Themes";
}

- (id) view {
    return _tableView;
}

- (void) themesChanged {
    settingsChanged = YES;
}

/* UITableViewDelegate / UITableViewDataSource Methods {{{ */
- (int) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (id) tableView:(UITableView *)tableView titleForHeaderInSection:(int)section {
    return nil;
}

- (int) tableView:(UITableView *)tableView numberOfRowsInSection:(int)section {
    return _themes.count;
}

- (id) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ThemeCell"];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectMake(0, 0, 100, 100) reuseIdentifier:@"ThemeCell"] autorelease];
        //[cell setTableViewStyle:UITableViewCellStyleDefault];
    }

    NSDictionary *theme([_themes objectAtIndex:indexPath.row]);
    cell.text = [theme objectForKey:@"Name"];
    cell.hidesAccessoryWhenEditing = NO;
    NSNumber *active([theme objectForKey:@"Active"]);
    BOOL inactive(active == nil || ![active boolValue]);
    [cell setImage:(inactive ? uncheckedImage : checkImage)];
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSMutableDictionary *theme = [_themes objectAtIndex:indexPath.row];
    NSNumber *active = [theme objectForKey:@"Active"];
    BOOL inactive = active == nil || ![active boolValue];
    [theme setObject:[NSNumber numberWithBool:inactive] forKey:@"Active"];
    [cell setImage:(!inactive ? uncheckedImage : checkImage)];
    [tableView deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:YES];
    [self themesChanged];
}

- (void) tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    NSUInteger fromIndex = [fromIndexPath row];
    NSUInteger toIndex = [toIndexPath row];
    if (fromIndex == toIndex)
        return;
    NSMutableDictionary *theme = [[[_themes objectAtIndex:fromIndex] retain] autorelease];
    [_themes removeObjectAtIndex:fromIndex];
    [_themes insertObject:theme atIndex:toIndex];
    [self themesChanged];
}

- (UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL) tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL) tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
/* }}} */
@end
/* }}} */

@interface WBSettingsController: PSListController {
}

- (id) initForContentSize:(CGSize)size;
- (void) dealloc;
- (void) suspend;
- (void) navigationBarButtonClicked:(int)buttonIndex;
- (void) viewWillRedisplay;
- (void) pushController:(id)controller;
- (id) specifiers;
- (void) settingsChanged;
- (NSString *) title;
- (void) setPreferenceValue:(id)value specifier:(PSSpecifier *)spec;
- (id) readPreferenceValue:(PSSpecifier *)spec;

@end

@implementation WBSettingsController

- (id) initForContentSize:(CGSize)size {
    if ((self = [super initForContentSize:size]) != nil) {
        _plist = [[NSString stringWithFormat:@"%@/Library/Preferences/com.saurik.WinterBoard.plist", NSHomeDirectory()] retain];
        _settings = [([NSMutableDictionary dictionaryWithContentsOfFile:_plist] ?: [NSMutableDictionary dictionary]) retain];
    } return self;
}

- (void) dealloc {
    [_settings release];
    [_plist release];
    [super dealloc];
}

- (void) suspend {
    if (!settingsChanged)
        return;

    NSData *data([NSPropertyListSerialization dataFromPropertyList:_settings format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
    if (!data)
        return;
    if (![data writeToFile:_plist options:NSAtomicWrite error:NULL])
        return;

    unlink("/User/Library/Caches/com.apple.springboard-imagecache-icons");
    unlink("/User/Library/Caches/com.apple.springboard-imagecache-icons.plist");
    unlink("/User/Library/Caches/com.apple.springboard-imagecache-smallicons");
    unlink("/User/Library/Caches/com.apple.springboard-imagecache-smallicons.plist");
    system("killall SpringBoard");
}

- (void) navigationBarButtonClicked:(int)buttonIndex {
    if (!settingsChanged) {
        [super navigationBarButtonClicked:buttonIndex];
        return;
    }

    if (buttonIndex == 0)
        settingsChanged = NO;

    [self suspend];
    [self.rootController popController];
}

- (void) viewWillRedisplay {
    if (settingsChanged)
        [self settingsChanged];
    [super viewWillRedisplay];
}

- (void) pushController:(id)controller {
    [self hideNavigationBarButtons];
    [super pushController:controller];
}

- (id) specifiers {
    if (!_specifiers)
        _specifiers = [[self loadSpecifiersFromPlistName:@"WinterBoard" target:self] retain];
    return _specifiers;
}

- (void) settingsChanged {
    [self showLeftButton:@"Respring" withStyle:2 rightButton:@"Cancel" withStyle:0];
    settingsChanged = YES;
}

- (NSString *) title {
    return @"WinterBoard";
}

- (void) setPreferenceValue:(id)value specifier:(PSSpecifier *)spec {
    if ([[spec propertyForKey:@"negate"] boolValue])
        value = [NSNumber numberWithBool:(![value boolValue])];
    [_settings setValue:value forKey:[spec propertyForKey:@"key"]];
    [self settingsChanged];
}

- (id) readPreferenceValue:(PSSpecifier *)spec {
    NSString *key([spec propertyForKey:@"key"]);
    id defaultValue([spec propertyForKey:@"default"]);
    id plistValue([_settings objectForKey:key]);
    if (!plistValue)
        return defaultValue;
    if ([[spec propertyForKey:@"negate"] boolValue])
        plistValue = [NSNumber numberWithBool:(![plistValue boolValue])];
    return plistValue;
}

@end
