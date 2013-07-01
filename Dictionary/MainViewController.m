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
#import "LookupResponse.h"

#define kCellID @"wordCellID"


// from UIReferenceLibraryViewController

#define DICTIONARY_BASIC_TINT_COLOR [UIColor colorWithRed:0.945098 green:0.933333 blue:0.898039 alpha:1]
#define DICTIONARY_BASIC_TEXT_COLOR [UIColor colorWithRed:87.0/255 green:57.0/255 blue:32.0/255 alpha:1]
#define DICTIONARY_BASIC_CELL_SELECTED_COLOR [UIColor colorWithRed:175.0/255 green:114.0/255 blue:65.0/255 alpha:1]

@interface MainViewController ()

@property UISearchBar *searchBar;
@property UITableView *lookupHistoryTableView;
@property UISearchDisplayController *dictionarySearchDisplayController;

@property LookupHistory *lookupHistory;
@property LookupRequest *lookupRequest;
@property LookupResponse *lookupResponse;

@end


@implementation MainViewController


# pragma mark - View lifecycle


- (void)viewDidLoad {
  [super viewDidLoad];

  _lookupHistory = [LookupHistory sharedInstance];
  _lookupRequest = [[LookupRequest alloc] init];
  _lookupResponse = [LookupResponse responseWithProgressState:DictionaryLookupProgressStateIdle terms:@[]];

  [self buildViews];
}


- (void)buildViews {
  [[UISearchBar appearance] setTintColor:DICTIONARY_BASIC_TINT_COLOR];

  _searchBar = [[UISearchBar alloc] init];
  _lookupHistoryTableView = [[UITableView alloc] init];
  _dictionarySearchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:self.searchBar contentsController:self];

  [self buildSearchBar];
  [self buildLookupHistoryTableView];
  [self buildSearchDisplayController];
  [self setupViewConstraints];
}


- (void)buildSearchBar {
  [[UIBarButtonItem appearanceWhenContainedIn:[UISearchBar class], nil] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                DICTIONARY_BASIC_TEXT_COLOR,
                                                                                                UITextAttributeTextColor,
                                                                                                DICTIONARY_BASIC_TINT_COLOR,
                                                                                                UITextAttributeTextShadowColor,
                                                                                                [NSValue valueWithUIOffset:UIOffsetMake(0, -1)],
                                                                                                UITextAttributeTextShadowOffset,
                                                                                                nil]
                                                                                      forState:UIControlStateNormal];
  self.searchBar.delegate = self;
  self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
  [self.searchBar sizeToFit];
}


- (void)buildLookupHistoryTableView {
//  self.lookupHistoryTableView.backgroundColor = BASIC_TINT_COLOR;
  [[UITableViewHeaderFooterView appearance] setTintColor:DICTIONARY_BASIC_TEXT_COLOR];
  UILabel *labelProxy = [UILabel appearanceWhenContainedIn:[UITableViewHeaderFooterView class], nil];
  labelProxy.textColor = DICTIONARY_BASIC_TINT_COLOR;
  labelProxy.font = [UIFont fontWithName:@"Helvetica-Bold" size:16];
  labelProxy.shadowOffset = CGSizeZero;

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
    [self.lookupHistoryTableView deleteRowsAtIndexPaths:[self indexPathsFromOffset:0 count:self.lookupHistory.count] withRowAnimation:UITableViewRowAnimationTop];
    [self.lookupHistory clear];
    [self.lookupHistoryTableView endUpdates];
  }];

  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self.lookupHistoryTableView reloadData];
    [self.lookupHistoryTableView setContentOffset:CGPointZero animated:YES];
  }];
}


# pragma mark - view manipulation


- (void)makeCellDefault:(UITableViewCell *)cell withText:(NSString *)text {
  cell.selectionStyle = UITableViewCellSelectionStyleBlue;
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  cell.textLabel.textAlignment = NSTextAlignmentLeft;
  cell.textLabel.font = [UIFont fontWithName:@"Baskerville" size:24];
  cell.textLabel.text = text;
  cell.textLabel.highlightedTextColor = DICTIONARY_BASIC_TEXT_COLOR;
}


- (void)makeCellNormal:(UITableViewCell *)cell withText:(NSString *)text {
  [self makeCellDefault:cell withText:text];
  cell.textLabel.textColor = DICTIONARY_BASIC_TEXT_COLOR;
}


- (void)disableCell:(UITableViewCell *)cell withText:(NSString *)text {
  [self makeCellDefault:cell withText:text];
  cell.textLabel.textColor = [UIColor grayColor];
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  cell.accessoryType = UITableViewCellAccessoryNone;
}


- (void)makeActionCell:(UITableViewCell *)cell withText:(NSString *)text {
  [self makeCellNormal:cell withText:text];
  cell.textLabel.textAlignment = NSTextAlignmentCenter;
  cell.accessoryType = UITableViewCellAccessoryNone;
  cell.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:18];
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
    UIView *backgroundView = [[UIView alloc] initWithFrame:cell.bounds];
    backgroundView.backgroundColor = DICTIONARY_BASIC_TINT_COLOR;
    cell.selectedBackgroundView = backgroundView;
  }

  if (tableView == self.searchDisplayController.searchResultsTableView) {
    [self makeSearchResultCell:cell forRowAtIndexPath:indexPath];
  } else if (tableView == self.lookupHistoryTableView) {
    [self makeHistoryCell:cell forRowAtIndexPath:indexPath];
  }

  return cell;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  if (tableView == self.lookupHistoryTableView) {
    return @"History";
  }
  if (self.lookupResponse.lookupState == DictionaryLookupProgressStateFinishedWithGuesses) {
    return @"Did you mean?";
  }

  return nil;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (tableView == self.searchDisplayController.searchResultsTableView) {
    switch (self.lookupResponse.lookupState) {
      case DictionaryLookupProgressStateIdle:
        return 0;
      case DictionaryLookupProgressStateLookingUpCompletionsButNoResultYet:
      case DictionaryLookupProgressStateFoundNoCompletionsLookingUpGuessesButNoResultsYet:
        return 1;
      case DictionaryLookupProgressStateHasPartialResults:
      case DictionaryLookupProgressStateFinishedWithCompletions:
      case DictionaryLookupProgressStateFinishedWithGuesses:
        return self.lookupResponse.terms.count;
      case DictionaryLookupProgressStateFinishedWithNoResultsAtAll:
        return 1;
      default:
        return 0;
    }
  } else {
    return self.lookupHistory.count + 1;
  }
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  if (tableView == self.lookupHistoryTableView && self.lookupHistory.count > 0 && indexPath.row < self.lookupHistory.count) {
    return YES;
  }

  return NO;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (tableView == self.lookupHistoryTableView && editingStyle == UITableViewCellEditingStyleDelete) {
    if (self.lookupHistory.count > 1) {
      [self.lookupHistoryTableView beginUpdates];
      [self.lookupHistory removeLookupHistoryAtIndex:indexPath.row];
      [self.lookupHistoryTableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      [self.lookupHistoryTableView endUpdates];
    } else {
      [self.lookupHistory removeLookupHistoryAtIndex:indexPath.row];
      [self.lookupHistoryTableView reloadData];
    }
  }
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  if ([self tableView:tableView titleForHeaderInSection:section]) {
    return 30;
  }

  return 0;
}

# pragma mark private


- (void)makeHistoryCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.lookupHistory.count == 0) {
    [self disableCell:cell withText:@"No history"];
  } else if (indexPath.row == self.lookupHistory.count) {
    [self makeActionCell:cell withText:@"Clear History"];
  } else {
    [self makeCellNormal:cell withText:[self.lookupHistory[indexPath.row] description]];
  }
}


- (void)makeSearchResultCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  switch (self.lookupResponse.lookupState) {
    case DictionaryLookupProgressStateLookingUpCompletionsButNoResultYet:
      return [self disableCell:cell withText:@"Looking up..."];
    case DictionaryLookupProgressStateFoundNoCompletionsLookingUpGuessesButNoResultsYet:
      return [self disableCell:cell withText:@"No results, guessing..."];
    case DictionaryLookupProgressStateHasPartialResults:
    case DictionaryLookupProgressStateFinishedWithCompletions:
    case DictionaryLookupProgressStateFinishedWithGuesses:
      return [self makeCellNormal:cell withText:[self.lookupResponse.terms[indexPath.row] description]];
    default:
      return [self disableCell:cell withText:@"No result"];
  }
}


# pragma mark - UITableViewDelegate


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  if (tableView == self.searchDisplayController.searchResultsTableView) {
    switch (self.lookupResponse.lookupState) {
      case DictionaryLookupProgressStateHasPartialResults:
      case DictionaryLookupProgressStateFinishedWithCompletions:
      case DictionaryLookupProgressStateFinishedWithGuesses:
        return [self showDefinitionForTerm:self.lookupResponse.terms[indexPath.row]];
      default:
        return;
    }
  } else {
    if (self.lookupHistory.count == 0) {
      // empty history, do nothing
    } else if (indexPath.row == self.lookupHistory.count) {
      [self clearHistory];
    } else {
      [self showDefinitionForTerm:[self.lookupHistory[indexPath.row] description]];
    }
  }
}


# pragma mark - UISearchDisplayDelegate


- (BOOL)searchDisplayController:(UISearchDisplayController *)searchDisplayController shouldReloadTableForSearchString:(NSString *)searchString {
  if (searchString.length < 1) {
    return NO;
  }

  [self.lookupRequest startLookingUpDictionaryWithTerm:searchString existingTerms:self.lookupResponse.terms progressBlock:^(LookupResponse *response) {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      self.lookupResponse = response;
      [self.searchDisplayController.searchResultsTableView reloadData];
    }];
  }];

  return NO;
}


# pragma mark - UISearchBarDelegate


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
  if (searchBar.text.length > 0 && self.lookupResponse.terms.count > 0 && [searchBar.text isEqualToString:self.lookupResponse.terms[0]]) {
    [self showDefinitionForTerm:searchBar.text];
  }
}


@end
