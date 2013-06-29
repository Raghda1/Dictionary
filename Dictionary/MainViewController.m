//
//  MainViewController.m
//  Dictionary
//
//  Created by Feng Ye on 11/18/11.
//  Copyright (c) 2011 @forresty. All rights reserved.
//

#import "MainViewController.h"
#import "LookupHistory.h"
#import "LookupRequest.h"

#define kCellID @"wordCellID"

@interface MainViewController ()

@property UISearchBar *searchBar;
@property UITableView *lookupHistoryTableView;
@property UISearchDisplayController *dictionarySearchDisplayController;

@property LookupHistory *lookupHistory;
@property LookupRequest *lookupRequest;

@property NSMutableArray *completions;
@property BOOL lookingUpCompletions;

@end


@implementation MainViewController


#pragma mark - View lifecycle


- (void)viewDidLoad {
  [super viewDidLoad];

  _lookupHistory = [LookupHistory sharedInstance];
  _lookupRequest = [[LookupRequest alloc] init];
  _completions = [@[] mutableCopy];
  _lookingUpCompletions = NO;

  [self buildViews];
}


- (void)buildViews {
  _searchBar = [[UISearchBar alloc] init];
  _lookupHistoryTableView = [[UITableView alloc] init];
  _dictionarySearchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:self.searchBar contentsController:self];

  [self buildSearchBar];
  [self buildLookupHistoryTableView];
  [self buildSearchDisplayController];
  [self setupViewConstraints];
}


- (void)buildSearchBar {
  self.searchBar.delegate = self;
  self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
  [self.searchBar sizeToFit];
}


- (void)buildLookupHistoryTableView {
  [self.lookupHistoryTableView setTranslatesAutoresizingMaskIntoConstraints:NO];
  self.lookupHistoryTableView.dataSource = self;
  self.lookupHistoryTableView.delegate = self;
  self.lookupHistoryTableView.tableHeaderView = self.searchBar;

  [self.view addSubview:self.lookupHistoryTableView];
}


- (void)buildSearchDisplayController {
  self.dictionarySearchDisplayController.delegate = self;
  self.dictionarySearchDisplayController.searchResultsDataSource = self;
  self.dictionarySearchDisplayController.searchResultsDelegate = self;
}


- (void)setupViewConstraints {
  UITableView *historyTableView = self.lookupHistoryTableView;
  NSDictionary *views = NSDictionaryOfVariableBindings(historyTableView, self.view);
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[historyTableView]|" options:0 metrics:nil views:views]];
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[historyTableView]|" options:0 metrics:nil views:views]];
}


# pragma mark - internal


- (NSArray *)indexPathsFromOffset:(NSUInteger)offset count:(NSUInteger)count {
  NSMutableArray * indexPaths = [[NSMutableArray alloc] initWithCapacity:count];

  for (int i = 0; i < count; i++) {
    [indexPaths addObject:[NSIndexPath indexPathForRow:i + offset inSection:0]];
  }

  return indexPaths;
}


# pragma mark - history


- (void)clearHistory {
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self.lookupHistoryTableView beginUpdates];
    [self.lookupHistoryTableView deleteRowsAtIndexPaths:[self indexPathsFromOffset:0 count:[self.lookupHistory count]] withRowAnimation:UITableViewRowAnimationTop];
    [self.lookupHistory clear];
    [self.lookupHistoryTableView endUpdates];
  }];

  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self.lookupHistoryTableView reloadData];
  }];
}


# pragma mark - view manipulation


- (void)makeCellDefault:(UITableViewCell *)cell withText:(NSString *)text {
  cell.selectionStyle = UITableViewCellSelectionStyleBlue;
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  cell.textLabel.textAlignment = NSTextAlignmentLeft;
  cell.textLabel.font = [UIFont fontWithName:@"Baskerville" size:24];
  cell.textLabel.text = text;
}


- (void)makeCellNormal:(UITableViewCell *)cell withText:(NSString *)text {
  [self makeCellDefault:cell withText:text];
  cell.textLabel.textColor = [UIColor blackColor];
}


- (void)disableCell:(UITableViewCell *)cell withText:(NSString *)text {
  [self makeCellDefault:cell withText:text];
  cell.textLabel.textColor = [UIColor grayColor];
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  cell.accessoryType = UITableViewCellAccessoryNone;
}


- (void)makeActionCell:(UITableViewCell *)cell withText:(NSString *)text {
  [self makeCellDefault:cell withText:text];
  cell.textLabel.textAlignment = NSTextAlignmentCenter;
  cell.accessoryType = UITableViewCellAccessoryNone;
  cell.textLabel.font = [UIFont fontWithName:@"Helvetica" size:18];
}


# pragma mark - UI presentation


- (void)showDefinitionForTerm:(NSString *)term {
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self.lookupHistory addLookupHistoryWithTerm:term];
    [self.lookupHistoryTableView reloadData];
  }];

  UIReferenceLibraryViewController *referenceLibraryViewController = [[UIReferenceLibraryViewController alloc] initWithTerm:term];

  [self presentViewController:referenceLibraryViewController animated:YES completion:NULL];
}


# pragma mark - UITableViewDataSource


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellID];

  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellID];
  }

  if (tableView == self.searchDisplayController.searchResultsTableView) {
    [self makeSearchResultCell:cell forRowAtIndexPath:indexPath];
  } else if (tableView == self.lookupHistoryTableView) {
    [self makeHistoryCell:cell forRowAtIndexPath:indexPath];
  }

  return cell;
}


- (void)makeHistoryCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  if ([self.lookupHistory count] == 0) {
    [self disableCell:cell withText:@"No history"];
  } else {
    if (indexPath.row == [self.lookupHistory count]) {
      [self makeActionCell:cell withText:@"Clear History"];
    } else {
      [self makeCellNormal:cell withText:[self.lookupHistory[indexPath.row] description]];
    }
  }
}


- (void)makeSearchResultCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.lookingUpCompletions) {
    [self disableCell:cell withText:@"Looking up..."];
  } else if ([self.completions count] > 0) {
    [self makeCellNormal:cell withText:[self.completions[indexPath.row] description]];
  } else {
    [self disableCell:cell withText:@"No result"];
  }
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  if (tableView == self.searchDisplayController.searchResultsTableView) {
    return 1;
  } else if (tableView == self.lookupHistoryTableView) {
    return 1;
  }

  return 0;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  if (tableView == self.searchDisplayController.searchResultsTableView) {
    return nil;
  } else if (tableView == self.lookupHistoryTableView) {
    return @"History";
  }

  return nil;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (tableView == self.searchDisplayController.searchResultsTableView) {
    if (self.lookingUpCompletions) {
      return 1;
    } else if ([self.completions count] > 0) {
      return [self.completions count];
    } else {
      return 1;
    }
  } else if (tableView == self.lookupHistoryTableView) {
    return [self.lookupHistory count] + 1;
  }

  return 0;
}


# pragma mark - UITableViewDelegate


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  if (tableView == self.searchDisplayController.searchResultsTableView) {
    if ([self.searchBar.text length] > 0 && [self.completions count] > 0 && indexPath.section == 0) {
      [self showDefinitionForTerm:self.completions[indexPath.row]];

    } else if (self.lookingUpCompletions) {
      // guessing, do nothing
      return;

    }
  } else if (tableView == self.lookupHistoryTableView) {
    if ([self.lookupHistory count] == 0) {
      // empty history, do nothing
    } else {
      if (indexPath.row == [self.lookupHistory count]) {
        [self clearHistory];
      } else {
        [self showDefinitionForTerm:[self.lookupHistory[indexPath.row] description]];
      }
    }
  }
}


# pragma mark - UISearchDisplayDelegate


- (BOOL)searchDisplayController:(UISearchDisplayController *)searchDisplayController shouldReloadTableForSearchString:(NSString *)searchString {
  if ([searchString length] < 1) {
    return NO;
  }

  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    self.lookingUpCompletions = YES;
    self.completions = [@[] mutableCopy];
    [self.searchDisplayController.searchResultsTableView reloadData];
  }];

  [self.lookupRequest startLookingUpDictionaryWithTerm:searchString batchCount:3 progressBlock:^(NSArray *partialResults) {
    self.lookingUpCompletions = self.lookupRequest.lookingUpCompletions;
    [self.completions addObjectsFromArray:partialResults];
    [self.searchDisplayController.searchResultsTableView reloadData];
//    [self insertPartialResults:partialResults];
  }];

  return NO;
}


- (void)insertPartialResults:(NSArray *)partialResults {
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self.dictionarySearchDisplayController.searchResultsTableView beginUpdates];
    self.lookingUpCompletions = self.lookupRequest.lookingUpCompletions;

    NSArray *indexPaths = [self indexPathsFromOffset:[self.completions count] count:[partialResults count]];
    [self.dictionarySearchDisplayController.searchResultsTableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];

    [self.completions addObjectsFromArray:partialResults];
    [self.dictionarySearchDisplayController.searchResultsTableView endUpdates];
  }];
}


# pragma mark - UISearchBarDelegate


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
  if ([searchBar.text length] > 0 && [self.completions count] > 0 && [searchBar.text isEqualToString:self.completions[0]]) {
    [self showDefinitionForTerm:searchBar.text];
  }
}


@end
