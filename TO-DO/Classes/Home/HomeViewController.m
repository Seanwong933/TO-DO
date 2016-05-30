//
//  HomeViewController.m
//  TO-DO
//
//  Created by Siegrain on 16/5/13.
//  Copyright © 2016年 com.siegrain. All rights reserved.
//

#import "CreateViewController.h"
#import "DateUtil.h"
#import "HSDatePickerViewController+Configure.h"
#import "HomeDataManager.h"
#import "HomeViewController.h"
#import "LCTodo.h"
#import "Macros.h"
#import "NSDate+Extension.h"
#import "TodoHeaderCell.h"
#import "TodoTableViewCell.h"
#import "UIButton+WebCache.h"
#import "UIImage+Extension.h"
#import "UIImage+Qiniu.h"
#import "UINavigationController+Transparent.h"
#import "UIScrollView+Extension.h"
#import "UITableView+Extension.h"
#import "UITableView+SDAutoTableViewCellHeight.h"

// TODO: 滚动到一定高度后需要修改导航栏颜色为不透明，同样需要调整状态栏字体颜色
// TODO: 搜索功能
// Mark: 再不能全局变量都用成员变量了，内存释放太操心

@implementation HomeViewController {
    HSDatePickerViewController* datePickerViewController;
    HomeDataManager* dataManager;
    UITableView* tableView;
    NSMutableDictionary* dataDictionary;
    NSMutableArray* dateArray;

    NSInteger dataCount;
    TodoTableViewCell* snoozingCell;
}
#pragma mark - localization
- (void)localizeStrings
{
    headerView.titleLabel.text = [NSString stringWithFormat:@"%ld %@", (long)dataCount, NSLocalizedString(@"Tasks", nil)];
}
#pragma mark - initial
- (void)viewDidLoad
{
    [super viewDidLoad];

    dataDictionary = [NSMutableDictionary new];
    dateArray = [NSMutableArray new];
    dataManager = [HomeDataManager new];

    [self localizeStrings];
    [self retrieveDataFromServer];
}
- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [tableView ignoreNavigationHeight];
    [tableView resizeTableHeaderView];
}
- (void)setupView
{
    [super setupView];

    tableView = [UITableView new];
    tableView.bounces = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.showsHorizontalScrollIndicator = NO;
    tableView.showsVerticalScrollIndicator = NO;
    tableView.sectionHeaderHeight = 15;
    [tableView registerClass:[TodoTableViewCell class] forCellReuseIdentifier:kTodoIdentifierArray[TodoIdentifierNormal]];
    tableView.separatorInset = UIEdgeInsetsMake(0, kScreenHeight * kCellHorizontalInsetsMuiltipledByHeight, 0, kScreenHeight * kCellHorizontalInsetsMuiltipledByHeight);
    [self.view addSubview:tableView];

    headerView = [HeaderView headerViewWithAvatarPosition:HeaderAvatarPositionCenter titleAlignement:HeaderTitleAlignementCenter];
    headerView.subtitleLabel.text = [TodoHelper localizedFormatDate:[NSDate date]];
    [headerView.rightOperationButton setImage:[UIImage imageNamed:@"add"] forState:UIControlStateNormal];
    [headerView.avatarButton sd_setImageWithURL:GetPictureUrl(user.avatar, kQiniuImageStyleSmall) forState:UIControlStateNormal];
    headerView.backgroundImageView.image = [UIImage imageAtResourcePath:@"header bg"];
    [headerView setHeaderViewDidPressAvatarButton:^{ [LCUser logOut]; }];
    __weak typeof(self) weakSelf = self;
    [headerView setHeaderViewDidPressRightOperationButton:^{
        releaseWhileDisappear = NO;
        CreateViewController* createViewController = [[CreateViewController alloc] init];
        [createViewController setCreateViewControllerDidFinishCreate:^(LCTodo* model) {
            model.photoImage = [model.photoImage imageAddCornerWithRadius:model.photoImage.size.width / 2 andSize:model.photoImage.size];
            [weakSelf insertTodo:model];
        }];
        [createViewController setCreateViewControllerDidDisappear:^{
            releaseWhileDisappear = YES;
        }];
        [weakSelf.navigationController pushViewController:createViewController animated:YES];
    }];
    tableView.tableHeaderView = headerView;

    datePickerViewController = [HSDatePickerViewController new];
    [datePickerViewController configure];
    datePickerViewController.delegate = self;
}
- (void)bindConstraints
{
    [super bindConstraints];

    [tableView mas_makeConstraints:^(MASConstraintMaker* make) {
        make.top.bottom.right.left.offset(0);
    }];

    [headerView mas_makeConstraints:^(MASConstraintMaker* make) {
        make.top.left.offset(0);
        make.width.offset(kScreenWidth);
        make.height.offset(kScreenHeight * 0.6);
    }];
}
#pragma mark - retreive data
- (void)retrieveDataFromServer
{
    __weak typeof(self) weakSelf = self;
    [dataManager retrieveDataWithUser:user complete:^(bool succeed, NSDictionary* data, NSInteger count) {
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf->dataDictionary = [NSMutableDictionary dictionaryWithDictionary:data];
        dataCount = count;
        [weakSelf reloadData];
    }];
}
#pragma mark - reloadData
- (void)reloadData
{
    NSArray* dateArrayOrder = [dataDictionary.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString* dateString1, NSString* dateString2) {
        NSString* format = @"yyyy-MM-dd";
        NSNumber* interval1 = @([DateUtil stringToDate:dateString1 format:format].timeIntervalSince1970);
        NSNumber* interval2 = @([DateUtil stringToDate:dateString2 format:format].timeIntervalSince1970);
        return [interval1 compare:interval2];
    }];
    dateArray = [NSMutableArray arrayWithArray:dateArrayOrder];
    [self localizeStrings];
    [tableView reloadData];
}
- (void)removeEmptySection:(NSString*)dateString
{
    NSMutableArray<LCTodo*>* array = dataDictionary[dateString];
    if (!array.count) {
        [dataDictionary removeObjectForKey:dateString];
        NSInteger index = [dateArray indexOfObject:dateString];
        [dateArray removeObject:dateString];
        [tableView deleteSections:[NSIndexSet indexSetWithIndex:index] withRowAnimation:UITableViewRowAnimationLeft];
    }
}
#pragma mark - tableview
#pragma mark - tableview delegate
- (CGFloat)tableView:(UITableView*)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath*)indexPath
{
    return [self tableView:self->tableView heightForRowAtIndexPath:indexPath];
}
- (CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath
{
    LCTodo* model = [self modelAtIndexPath:indexPath];
    if (!model.cellHeight) {
        model.cellHeight = [self->tableView cellHeightForIndexPath:indexPath model:model keyPath:@"model" cellClass:[TodoTableViewCell class] contentViewWidth:kScreenWidth];
    }

    return model.cellHeight;
}
#pragma mark - tableview datasource
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
    return dateArray.count;
}
- (UIView*)tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section
{
    TodoHeaderCell* header = [TodoHeaderCell headerCell];
    header.text = dateArray[section];
    return header;
}
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self dataArrayAtSection:section].count;
}
- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    TodoTableViewCell* cell = [self->tableView dequeueReusableCellWithIdentifier:kTodoIdentifierArray[TodoIdentifierNormal] forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}
#pragma mark - swipe left cell events
- (void)setupCellEvents:(TodoTableViewCell*)cell
{
    __weak typeof(self) weakSelf = self;
    if (!cell.todoDidComplete) {
        [cell setTodoDidComplete:^BOOL(TodoTableViewCell* sender) {
            __strong typeof(self) strongSelf = weakSelf;
            [sender setUserInteractionEnabled:NO];
            sender.model.isCompleted = YES;
            [strongSelf->dataManager modifyTodo:sender.model complete:^(bool succeed) {
                [sender setUserInteractionEnabled:YES];
                if (succeed) [weakSelf removeTodo:sender.model atIndexPath:[strongSelf->tableView indexPathForCell:sender]];
            }];
            return NO;
        }];
    }
    if (!cell.todoDidSnooze) {
        [cell setTodoDidSnooze:^BOOL(TodoTableViewCell* sender) {
            __strong typeof(self) strongSelf = weakSelf;
            [sender setUserInteractionEnabled:NO];
            strongSelf->snoozingCell = sender;
            [weakSelf showDatetimePicker:sender.model.deadline];
            return YES;
        }];
    }
    if (!cell.todoDidRemove) {
        [cell setTodoDidRemove:^BOOL(TodoTableViewCell* sender) {
            __strong typeof(self) strongSelf = weakSelf;
            [sender setUserInteractionEnabled:NO];
            sender.model.isDeleted = YES;
            [strongSelf->dataManager modifyTodo:sender.model complete:^(bool succeed) {
                [sender setUserInteractionEnabled:YES];
                if (succeed) [weakSelf removeTodo:sender.model atIndexPath:[strongSelf->tableView indexPathForCell:sender]];
            }];
            return YES;
        }];
    }
}
#pragma mark - tableview helper
- (NSArray<LCTodo*>*)dataArrayAtSection:(NSInteger)section
{
    return dataDictionary[dateArray[section]];
}
- (LCTodo*)modelAtIndexPath:(NSIndexPath*)indexPath
{
    NSArray<LCTodo*>* dataArray = [self dataArrayAtSection:indexPath.section];
    return dataArray[indexPath.row];
}
- (void)configureCell:(TodoTableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath
{
    LCTodo* model = [self modelAtIndexPath:indexPath];
    [self setupCellEvents:cell];
    cell.model = model;
}
- (void)removeTodo:(LCTodo*)model atIndexPath:(NSIndexPath*)indexPath
{
    // FIXME: 多次请求会异常
    NSString* deadline = model.deadline.stringInYearMonthDay;
    NSMutableArray<LCTodo*>* array = dataDictionary[deadline];
    [array removeObject:model];

    if (!array.count) {
        [self removeEmptySection:deadline];
    } else {
        [tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationLeft];
    }

    dataCount--;
    // Mark:光用 deleteRows 方法删除该 Section 最后一行时，上一行会冒出一条迷の分割线，所以必须 reloadData
    [self reloadData];
}
- (void)insertTodo:(LCTodo*)model
{
    [self reorderTodo:model];
}
- (void)reorderTodo:(LCTodo*)model
{
    NSString* deadline = model.deadline.stringInYearMonthDay;

    NSMutableArray<LCTodo*>* array = dataDictionary[deadline];
    if (!array) array = dataDictionary[deadline] = [NSMutableArray new];
    if (![dateArray containsObject:deadline]) [dateArray addObject:deadline];

    // 检查是否是同一天，是同一天只需要重新排序即可
    // 不是则需要移除当前位置的 cell，加到另一个 section 中
    if (model.lastDeadline && ![model.lastDeadline.stringInYearMonthDay isEqualToString:deadline]) {
        NSString* lastDeadline = model.lastDeadline.stringInYearMonthDay;
        NSMutableArray<LCTodo*>* lastDateArray = dataDictionary[lastDeadline];
        [lastDateArray removeObject:model];

        [self removeEmptySection:lastDeadline];
        // Mark: 必须在 remove sections 后再添加到数据源中，不然 remove 时会报错，即使该数据源不在原来的位置上..
        [array addObject:model];
    } else if (!model.lastDeadline) {
        dataCount++;
        [array addObject:model];
    }

    NSSortDescriptor* sort = [NSSortDescriptor sortDescriptorWithKey:@"self.deadline.timeIntervalSince1970" ascending:YES];
    [array sortUsingDescriptors:@[ sort ]];

    [self reloadData];
}
#pragma mark - date time picker delegate
- (void)showDatetimePicker:(NSDate*)deadline
{
    releaseWhileDisappear = NO;

    datePickerViewController.minDate = [[NSDate date] dateByAddingTimeInterval:-60];
    if ([deadline timeIntervalSince1970] > [datePickerViewController.minDate timeIntervalSince1970])
        datePickerViewController.minDate = deadline;

    [self presentViewController:datePickerViewController animated:YES completion:nil];
}
- (BOOL)hsDatePickerPickedDate:(NSDate*)date
{
    releaseWhileDisappear = YES;

    if ([date timeIntervalSince1970] < [datePickerViewController.minDate timeIntervalSince1970])
        date = [NSDate date];

    __weak typeof(self) weakSelf = self;
    LCTodo* todo = snoozingCell.model;
    todo.lastDeadline = todo.deadline;
    todo.deadline = date;
    todo.status = LCTodoStatusSnoozed;
    [dataManager modifyTodo:todo complete:^(bool succeed) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf->snoozingCell setUserInteractionEnabled:YES];
        strongSelf->snoozingCell = nil;
        if (succeed)
            [weakSelf reorderTodo:todo];
    }];

    return YES;
}
#pragma mark - scrollview
#pragma mark - release
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    if (!releaseWhileDisappear) return;

    [tableView removeFromSuperview];
    tableView = nil;

    [self.view removeFromSuperview];
    self.view = nil;
    [self removeFromParentViewController];
}
- (void)dealloc
{
    NSLog(@"%s", __func__);
}
@end
