//
//  LUConsoleOverlayController.m
//
//  Lunar Unity Mobile Console
//  https://github.com/SpaceMadness/lunar-unity-console
//
//  Copyright 2019 Alex Lementuev, SpaceMadness.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "Lunar-Full.h"

#import "LUConsoleOverlayController.h"

@interface LUConsoleOverlayController () <UITableViewDataSource, UITableViewDelegate, LunarConsoleDelegate> {
    NSMutableArray<LUConsoleOverlayLogEntry *> * _entries;
    LUConsole                                  * _console;
    LULogOverlaySettings                       * _settings;
    BOOL                                         _entryRemovalScheduled;
    BOOL                                         _entryRemovalCancelled;
}

@property (nonatomic, weak) IBOutlet UITableView * tableView;

@end

@implementation LUConsoleOverlayController

+ (instancetype)controllerWithConsole:(LUConsole *)console settings:(LULogOverlaySettings *)settings {
    return [[[self class] alloc] initWithConsole:console settings:settings];
}

- (instancetype)initWithConsole:(LUConsole *)console settings:(LULogOverlaySettings *)settings {
    self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil];
    if (self)
    {
        _console = console;
        _console.delegate = self;
        
        _settings = settings;
        
        _entries = [[NSMutableArray alloc] initWithCapacity:_settings.maxVisibleLines];
    }
    return self;
}

- (void)dealloc {
    if (_console.delegate == self)
    {
        _console.delegate = nil;
    }
    
    _tableView.delegate   = nil;
    _tableView.dataSource = nil;
}

#pragma mark -
#pragma mark Life cycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _entryRemovalCancelled = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _entryRemovalCancelled = YES;
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    LUConsoleLogEntry *entry = [self entryForRowAtIndexPath:indexPath];
    LUConsoleOverlayLogEntryTableViewCell *cell = (LUConsoleOverlayLogEntryTableViewCell *) [entry tableView:tableView cellAtIndex:indexPath.row];
	
	// this is not an approprite place to customize but we're kinda on a tight budget
	LULogEntryColors *colors = [self colorsForEntryType:entry.type];
	cell.messageColor = colors.foreground.UIColor;
	if (colors.background.a > 0) {
		cell.cellColor = colors.background.UIColor;
	}
	return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    LUConsoleLogEntry *entry = [self entryForRowAtIndexPath:indexPath];
    return [entry cellSizeForTableView:tableView].height;
}

#pragma mark -
#pragma mark LunarConsoleDelegate

- (void)lunarConsole:(LUConsole *)console didAddEntryAtIndex:(NSInteger)index trimmedCount:(NSUInteger)trimmedCount {
	LUConsoleOverlayLogEntry *entry = [[LUConsoleOverlayLogEntry alloc] initWithEntry:[console entryAtIndex:index]];
	
	// mark "removal" date
	entry.removalDate = [[NSDate alloc] initWithTimeIntervalSinceNow:_settings.timeout];
	
	[UIView performWithoutAnimation:^{
		if (_entries.count < _settings.maxVisibleLines) {
			[_entries addObject:entry];
			[_tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:_entries.count - 1 inSection:0]]
							  withRowAnimation:UITableViewRowAnimationNone];
		} else {
			[_tableView beginUpdates];
			
			[self removeFirstRow];
			
			[_entries addObject:entry];
			[_tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:_entries.count - 1 inSection:0]]
							  withRowAnimation:UITableViewRowAnimationNone];
			
			[_tableView endUpdates];
		}
		
		// remove row after the delay
		[self scheduleEntryRemoval:entry];
	}];
}

- (void)lunarConsole:(LUConsole *)console didUpdateEntryAtIndex:(NSInteger)index trimmedCount:(NSUInteger)trimmedCount {
    [self lunarConsole:console didAddEntryAtIndex:index trimmedCount:trimmedCount];
}

- (void)lunarConsoleDidClearEntries:(LUConsole *)console {
     [_entries removeAllObjects];
     [self reloadData];
}

#pragma mark -
#pragma mark Rows

- (void)removeFirstRow {
	static id firstRow;
	if (firstRow == nil) {
		firstRow = @[[NSIndexPath indexPathForRow:0 inSection:0]];
	}
	
	if (_entries.count > 0) {
		[_entries removeObjectAtIndex:0];
		[_tableView deleteRowsAtIndexPaths:firstRow
						  withRowAnimation:UITableViewRowAnimationNone];
	}
}

#pragma mark -
#pragma mark Entry removal

- (void)scheduleEntryRemoval:(LUConsoleOverlayLogEntry *)entry {
	// we don't want to call this multiple times since it's a relatively expensive
	if (_entryRemovalScheduled) {
		return;
	}
	
	_entryRemovalScheduled = YES;
	
	NSTimeInterval timeout = MAX(0.0, [entry.removalDate timeIntervalSinceNow]);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		_entryRemovalScheduled = NO;
		
		if (_entryRemovalCancelled) {
			return;
		}
		
		LUConsoleOverlayLogEntry *firstEntry = _entries.firstObject;
		if (firstEntry == nil) {
			return;
		}
		
		if (firstEntry == entry) {
			[UIView performWithoutAnimation:^{
				[self removeFirstRow];
			}];
			firstEntry = _entries.firstObject;
		}
		
		[self scheduleEntryRemoval:firstEntry];
	});
}

#pragma mark -
#pragma mark Helpers

- (LUConsoleLogEntry *)entryForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [_entries objectAtIndex:indexPath.row];
}

- (LUConsoleLogEntry *)entryForRowAtIndex:(NSUInteger)index {
    return [_entries objectAtIndex:index];
}

- (void)reloadData {
    [_tableView reloadData];
}

- (LULogEntryColors *)colorsForEntryType:(LUConsoleLogType)type {
	static NSArray<LULogEntryColors *> *colorLookup;
	if (colorLookup == nil) {
		LULogColors *colors = _settings.colors;
		colorLookup = @[
		  colors.error,     // LUConsoleLogTypeError
		  colors.error,     // LUConsoleLogTypeAssert
		  colors.warning,   // LUConsoleLogTypeWarning
		  colors.debug,     // LUConsoleLogTypeLog
		  colors.exception, // LUConsoleLogTypeException
		];
	}
	
	return colorLookup[type];
}

@end
