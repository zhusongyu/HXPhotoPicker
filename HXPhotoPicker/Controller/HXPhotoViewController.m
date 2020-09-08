//
//  HXPhotoViewController.m
//  HXPhotoPicker-Demo
//
//  Created by 洪欣 on 2017/10/14.
//  Copyright © 2017年 洪欣. All rights reserved.
//

#import "HXPhotoViewController.h"
#import "UIImage+HXExtension.h"
#import "HXPhoto3DTouchViewController.h"
#import "HXPhotoPreviewViewController.h"
#import "UIButton+HXExtension.h" 
#import "HXCustomCameraViewController.h"
#import "HXCustomNavigationController.h"
#import "HXCustomCameraController.h"
#import "HXCustomPreviewView.h"
#import "HXPhotoEditViewController.h"
#import "HXPhotoViewFlowLayout.h"
#import "HXCircleProgressView.h"
#import "UIViewController+HXExtension.h"

#import "UIImageView+HXExtension.h"

#if __has_include(<SDWebImage/UIImageView+WebCache.h>)
#import <SDWebImage/UIImageView+WebCache.h>
#elif __has_include("UIImageView+WebCache.h")
#import "UIImageView+WebCache.h"
#endif

#import "HXAlbumlistView.h" 
#import "NSArray+HXExtension.h"
#import "HXVideoEditViewController.h"
#import "HXPhotoEdit.h"
#import "HX_PhotoEditViewController.h"
#import "UIColor+HXExtension.h"

@interface HXPhotoViewController ()
<
UICollectionViewDataSource,
UICollectionViewDelegate,
UICollectionViewDelegateFlowLayout,
UIViewControllerPreviewingDelegate,
HXPhotoViewCellDelegate,
HXPhotoBottomViewDelegate,
HXPhotoPreviewViewControllerDelegate,
HXCustomCameraViewControllerDelegate,
HXPhotoEditViewControllerDelegate,
HXVideoEditViewControllerDelegate,
HX_PhotoEditViewControllerDelegate
//PHPhotoLibraryChangeObserver
>
@property (assign, nonatomic) NSInteger selectedIndex;
@property (strong, nonatomic) NSMutableArray *selectedIndexArray;

@property (strong, nonatomic) UICollectionViewFlowLayout *flowLayout;
@property (strong, nonatomic) UICollectionView *collectionView;

@property (strong, nonatomic) NSMutableArray *allArray;
@property (assign, nonatomic) NSInteger photoCount;
@property (assign, nonatomic) NSInteger videoCount;
@property (strong, nonatomic) NSMutableArray *previewArray;
@property (strong, nonatomic) NSMutableArray *dateArray;

@property (assign, nonatomic) NSInteger currentSectionIndex;
@property (weak, nonatomic) id<UIViewControllerPreviewing> previewingContext;

@property (assign, nonatomic) BOOL orientationDidChange;
@property (assign, nonatomic) BOOL needChangeViewFrame;
@property (strong, nonatomic) NSIndexPath *beforeOrientationIndexPath;

@property (weak, nonatomic) HXPhotoViewSectionFooterView *footerView;
@property (assign, nonatomic) BOOL showBottomPhotoCount;

@property (strong, nonatomic) HXAlbumTitleView *albumTitleView;
@property (strong, nonatomic) HXAlbumlistView *albumView;
@property (strong, nonatomic) UIView *albumBgView;
@property (strong, nonatomic) UILabel *authorizationLb;

@property (assign, nonatomic) BOOL firstDidAlbumTitleView;

@property (assign, nonatomic) BOOL collectionViewReloadCompletion;

@property (weak, nonatomic) HXPhotoCameraViewCell *cameraCell;

@property (assign, nonatomic) BOOL cellCanSetModel;
@property (copy, nonatomic) NSArray *collectionVisibleCells;
@property (assign, nonatomic) BOOL isNewEditDismiss;

@property (assign, nonatomic) BOOL firstOn;
@property (assign, nonatomic) BOOL assetDidChanged;
@end

@implementation HXPhotoViewController
#pragma mark - < life cycle >
- (void)dealloc {
    if (_collectionView) {
        [self.collectionView.layer removeAllAnimations];
    }
    if (self.manager.configuration.open3DTouchPreview) {
        if (self.previewingContext) {
            if (@available(iOS 9.0, *)) {
                [self unregisterForPreviewingWithContext:self.previewingContext];
            }
        }
    }
//    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self changeColor];
            [self changeStatusBarStyle];
            [self setNeedsStatusBarAppearanceUpdate];
            UIColor *authorizationColor = self.manager.configuration.authorizationTipColor;
            _authorizationLb.textColor = [HXPhotoCommon photoCommon].isDark ? [UIColor whiteColor] : authorizationColor;
        }
    }
#endif
}
- (UIStatusBarStyle)preferredStatusBarStyle {
    if ([HXPhotoCommon photoCommon].isDark) {
        return UIStatusBarStyleLightContent;
    }
    return self.manager.configuration.statusBarStyle;
}
- (BOOL)prefersStatusBarHidden {
    return NO;
}
- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationFade;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self changeStatusBarStyle];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    if (self.needChangeViewFrame) {
        self.needChangeViewFrame = NO;
    }
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.manager.configuration.cameraCellShowPreview) {
        if (!self.cameraCell.startSession) {
            [self.cameraCell starRunning];
        }
    }
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
- (void)changeStatusBarStyle {
    if ([HXPhotoCommon photoCommon].isDark) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
        return;
    }
    [[UIApplication sharedApplication] setStatusBarStyle:self.manager.configuration.statusBarStyle animated:YES];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.orientationDidChange) {
        [self changeSubviewFrame];
        self.orientationDidChange = NO;
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.selectedIndexArray = [NSMutableArray arrayWithCapacity:0];
    self.assetDidChanged = NO;
//    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    self.firstOn = YES;
    self.cellCanSetModel = YES;
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.edgesForExtendedLayout = UIRectEdgeAll;
    if (self.manager.configuration.showBottomPhotoDetail) {
        self.showBottomPhotoCount = YES;
        self.manager.configuration.showBottomPhotoDetail = NO;
    }
//    HXWeakSelf
//    self.hx_customNavigationController.photoLibraryDidChange = ^(HXAlbumModel *albumModel) {
//        if (albumModel == weakSelf.albumModel ||
//            [albumModel.localIdentifier isEqualToString:weakSelf.albumModel.localIdentifier]) {
//            weakSelf.albumModel.assetResult = nil;
//            weakSelf.assetDidChanged = YES;
//            weakSelf.collectionViewReloadCompletion = NO;
//            [weakSelf.navigationController popToViewController:self animated:YES];
//            weakSelf.bottomView.selectCount = [weakSelf.manager selectedCount];
//            [weakSelf.view hx_showLoadingHUDText:nil];
//            [weakSelf startGetAllPhotoModel];
//        }
//    };
    if (self.manager.configuration.albumShowMode == HXPhotoAlbumShowModeDefault) {
        [self setupUI];
        [self changeSubviewFrame];
//        [self.view hx_showLoadingHUDText:nil];
        [self getPhotoList];
    }else if (self.manager.configuration.albumShowMode == HXPhotoAlbumShowModePopup) { 
        [self setupUI];
        [self changeSubviewFrame];
        // 获取当前应用对照片的访问授权状态
        [self.view hx_showLoadingHUDText:nil delay:0.1f];
        HXWeakSelf
        [HXPhotoTools requestAuthorization:self handler:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                [weakSelf getAlbumList];
            }else {
#ifdef __IPHONE_14_0
                if (@available(iOS 14, *)) {
                    if (status == PHAuthorizationStatusLimited) {
                        weakSelf.authorizationLb.text = [NSBundle hx_localizedStringForKey:@"无法访问所有照片\n请点击这里前往设置中允许访问所有照片"];
                    }
                }
#endif
                [weakSelf.view hx_handleLoading];
                [weakSelf.view addSubview:weakSelf.authorizationLb];
            }
        }];
    }

    if (self.manager.configuration.open3DTouchPreview) {
//#ifdef __IPHONE_13_0
//        if (@available(iOS 13.0, *)) {
//            [HXPhotoCommon photoCommon].isHapticTouch = YES;
//#else
//        if ((NO)) {
//#endif
//        }else {
            if ([self respondsToSelector:@selector(traitCollection)]) {
                if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)]) {
                    if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
                        HXWeakSelf
                        self.previewingContext = [self registerForPreviewingWithDelegate:weakSelf sourceView:weakSelf.collectionView];
                    }
                }
            }
//        }
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationChanged:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}
#pragma mark - < private >
- (void)setupUI {
    self.currentSectionIndex = 0;
    [self.view addSubview:self.collectionView];
    if (!self.manager.configuration.singleSelected) {
        [self.view addSubview:self.bottomView];
    }
    if (self.manager.configuration.albumShowMode == HXPhotoAlbumShowModePopup) {
        if (self.manager.configuration.photoListCancelLocation == HXPhotoListCancelButtonLocationTypeLeft) {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[NSBundle hx_localizedStringForKey:@"取消"] style:UIBarButtonItemStylePlain target:self action:@selector(didCancelClick)];
        }else if (self.manager.configuration.photoListCancelLocation == HXPhotoListCancelButtonLocationTypeRight) {
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[NSBundle hx_localizedStringForKey:@"取消"] style:UIBarButtonItemStylePlain target:self action:@selector(didCancelClick)];
        }
        if (self.manager.configuration.photoListTitleView) {
            self.navigationItem.titleView = self.manager.configuration.photoListTitleView(self.albumModel.albumName);
            HXWeakSelf
            self.manager.configuration.photoListTitleViewAction = ^(BOOL selected) {
                [weakSelf albumTitleViewDidAction:selected];
            };
        }else {
            self.navigationItem.titleView = self.albumTitleView;
        }
        [self.view addSubview:self.albumBgView];
        [self.view addSubview:self.albumView];
    }else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[NSBundle hx_localizedStringForKey:@"取消"] style:UIBarButtonItemStyleDone target:self action:@selector(didCancelClick)];
    }
    [self changeColor];
}
- (void)changeColor {
    UIColor *backgroundColor;
    UIColor *themeColor;
    UIColor *navBarBackgroudColor;
    UIColor *albumBgColor;
    UIColor *navigationTitleColor;
    if ([HXPhotoCommon photoCommon].isDark) {
        backgroundColor = [UIColor colorWithRed:0.075 green:0.075 blue:0.075 alpha:1];
        themeColor = [UIColor whiteColor];
        navBarBackgroudColor = [UIColor blackColor];
        albumBgColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1];
        navigationTitleColor = [UIColor whiteColor];
    }else {
        backgroundColor = self.manager.configuration.photoListViewBgColor;
        themeColor = self.manager.configuration.themeColor;
        navBarBackgroudColor = self.manager.configuration.navBarBackgroudColor;
        navigationTitleColor = self.manager.configuration.navigationTitleColor;
        albumBgColor = [UIColor blackColor];
    }
    self.view.backgroundColor = backgroundColor;
    self.collectionView.backgroundColor = backgroundColor;
    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    
    self.navigationController.navigationBar.barTintColor = navBarBackgroudColor;
    self.navigationController.navigationBar.barStyle = self.manager.configuration.navBarStyle;
    if (self.manager.configuration.navBarBackgroundImage) {
        [self.navigationController.navigationBar setBackgroundImage:self.manager.configuration.navBarBackgroundImage forBarMetrics:UIBarMetricsDefault];
    }
    
    if (self.manager.configuration.navigationTitleSynchColor) {
        self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : themeColor};
    }else {
        if (navigationTitleColor) {
            self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : navigationTitleColor};
        }else {
            self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : [UIColor blackColor]};
        }
    }
    
    _albumBgView.backgroundColor = [albumBgColor colorWithAlphaComponent:0.5f];
    
}
- (void)deviceOrientationChanged:(NSNotification *)notify {
    self.beforeOrientationIndexPath = [self.collectionView indexPathsForVisibleItems].firstObject;
    self.orientationDidChange = YES;
    if (self.navigationController.topViewController != self) {
        self.needChangeViewFrame = YES;
    }
}
- (void)changeSubviewFrame {
    CGFloat albumHeight = self.manager.configuration.popupTableViewHeight;
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat navBarHeight = hxNavigationBarHeight;
    NSInteger lineCount = self.manager.configuration.rowCount;
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        navBarHeight = hxNavigationBarHeight;
        lineCount = self.manager.configuration.rowCount;
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    }else if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft){
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
        if ([UIApplication sharedApplication].statusBarHidden) {
            navBarHeight = self.navigationController.navigationBar.hx_h;
        }else {
            navBarHeight = self.navigationController.navigationBar.hx_h + 20;
        }
        lineCount = self.manager.configuration.horizontalRowCount;
        albumHeight = self.manager.configuration.popupTableViewHorizontalHeight;
    }
    CGFloat bottomMargin = hxBottomMargin;
    CGFloat leftMargin = 0;
    CGFloat rightMargin = 0;
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    CGFloat viewWidth = [UIScreen mainScreen].bounds.size.width;
    
    
    if (!CGRectEqualToRect(self.view.bounds, [UIScreen mainScreen].bounds)) {
        self.view.frame = CGRectMake(0, 0, viewWidth, height);
    }
    if (HX_IS_IPhoneX_All &&
        (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight)) {
        bottomMargin = 21;
        leftMargin = 35;
        rightMargin = 35;
        width = [UIScreen mainScreen].bounds.size.width - 70;
    }
    CGFloat itemWidth = 89;//(width - (lineCount - 1)) / lineCount;
    CGFloat itemHeight = 89;//itemWidth;
    self.flowLayout.itemSize = CGSizeMake(itemWidth, itemHeight);
    CGFloat bottomViewY = height - 50 - bottomMargin;
    
    if (!self.manager.configuration.singleSelected) {
        self.collectionView.contentInset = UIEdgeInsetsMake(navBarHeight, leftMargin, 50 + bottomMargin, rightMargin);
    } else {
        self.collectionView.contentInset = UIEdgeInsetsMake(navBarHeight, leftMargin, bottomMargin, rightMargin);
    }

#ifdef __IPHONE_13_0
        if (@available(iOS 13.0, *)) {
            self.collectionView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 50.f, 0);
        }else {
            self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset;
        }
#else
        self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset;
#endif
    
    if (self.orientationDidChange) {
        [self.collectionView scrollToItemAtIndexPath:self.beforeOrientationIndexPath atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
    }
    
    self.bottomView.frame = CGRectMake(0, bottomViewY, viewWidth, 50 + bottomMargin);
    
    if (self.manager.configuration.albumShowMode == HXPhotoAlbumShowModePopup) {
        self.albumView.hx_w = viewWidth;
        self.albumView.hx_h = albumHeight;
        BOOL titleViewSeleted = NO;
        if (self.manager.configuration.photoListTitleView) {
            if (self.manager.configuration.photoListTitleViewSelected) {
                titleViewSeleted = self.manager.configuration.photoListTitleViewSelected();
            }
            if (self.manager.configuration.updatePhotoListTitle) {
                self.manager.configuration.updatePhotoListTitle(self.albumModel.albumName);
            }
        }else {
            titleViewSeleted = self.albumTitleView.selected;
            self.albumTitleView.model = self.albumModel;
        }
        if (titleViewSeleted) {
            self.albumView.hx_y = navBarHeight;
            if (self.manager.configuration.singleSelected) {
                self.albumView.alpha = 1;
            }
        }else {
            self.albumView.hx_y = -(navBarHeight + self.albumView.hx_h);
            if (self.manager.configuration.singleSelected) {
                self.albumView.alpha = 0;
            }
        }
        if (self.manager.configuration.singleSelected) {
            self.albumBgView.frame = CGRectMake(0, navBarHeight, viewWidth, height - navBarHeight);
        }else {
            self.albumBgView.hx_size = CGSizeMake(viewWidth, height);
        }
        if (self.manager.configuration.popupAlbumTableView) {
            self.manager.configuration.popupAlbumTableView(self.albumView.tableView);
        }
    }
    
    self.navigationController.navigationBar.translucent = self.manager.configuration.navBarTranslucent;
    
    if (!self.manager.configuration.singleSelected) {
        if (self.manager.configuration.photoListBottomView) {
            self.manager.configuration.photoListBottomView(self.bottomView);
        }
    }
    if (self.manager.configuration.photoListCollectionView) {
        self.manager.configuration.photoListCollectionView(self.collectionView);
    }
    if (self.manager.configuration.navigationBar) {
        self.manager.configuration.navigationBar(self.navigationController.navigationBar, self);
    }
}
- (void)getCameraRollAlbum {
    self.albumModel = self.hx_customNavigationController.cameraRollAlbumModel;
    if (self.manager.configuration.updatePhotoListTitle) {
        self.manager.configuration.updatePhotoListTitle(self.albumModel.albumName);
    }else {
        self.albumTitleView.model = self.albumModel;
    }
    [self getPhotoList];
}
- (void)getAlbumList {
    HXWeakSelf
    if (self.hx_customNavigationController.cameraRollAlbumModel) {
        [self getCameraRollAlbum];
    }else {
        self.hx_customNavigationController.requestCameraRollCompletion = ^{
            [weakSelf getCameraRollAlbum];
        };
    }
    if (self.hx_customNavigationController.albums) {
        self.albumView.albumModelArray = self.hx_customNavigationController.albums;
    }else {
        self.hx_customNavigationController.requestAllAlbumCompletion = ^{
            weakSelf.albumView.albumModelArray = weakSelf.hx_customNavigationController.albums;
        };
    }
}
- (void)getPhotoList {
    [self startGetAllPhotoModel];
}
- (void)didCancelClick {
    if (self.manager.configuration.albumShowMode == HXPhotoAlbumShowModePopup) {
        if (self.manager.configuration.photoListChangeTitleViewSelected) {
            self.manager.configuration.photoListChangeTitleViewSelected(NO);
        }
        [self.manager cancelBeforeSelectedList];
    }
    if ([self.delegate respondsToSelector:@selector(photoViewControllerDidCancel:)]) {
        [self.delegate photoViewControllerDidCancel:self];
    }
    if (self.cancelBlock) {
        self.cancelBlock(self, self.manager);
    }
    self.manager.selectPhotoing = NO;
    BOOL selectPhotoCancelDismissAnimated = self.manager.selectPhotoCancelDismissAnimated;
    [self dismissViewControllerAnimated:selectPhotoCancelDismissAnimated completion:^{
        if ([self.delegate respondsToSelector:@selector(photoViewControllerCancelDismissCompletion:)]) {
            [self.delegate photoViewControllerCancelDismissCompletion:self];
        }
    }];
}
- (NSInteger)dateItem:(HXPhotoModel *)model {
    NSInteger dateItem = [self.allArray indexOfObject:model];
    return dateItem;
}
- (void)scrollToPoint:(HXPhotoViewCell *)cell rect:(CGRect)rect {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat navBarHeight = hxNavigationBarHeight;
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        navBarHeight = hxNavigationBarHeight;
    }else if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft){
        if ([UIApplication sharedApplication].statusBarHidden) {
            navBarHeight = self.navigationController.navigationBar.hx_h;
        }else {
            navBarHeight = self.navigationController.navigationBar.hx_h + 20;
        }
    }
    
    if (rect.origin.y < navBarHeight) {
        [self.collectionView setContentOffset:CGPointMake(0, cell.frame.origin.y - navBarHeight)];
    }else if (rect.origin.y + rect.size.height > self.view.hx_h - 50.5 - hxBottomMargin) {
        [self.collectionView setContentOffset:CGPointMake(0, cell.frame.origin.y - self.view.hx_h + 50.5 + hxBottomMargin + rect.size.height)];
    }
}
#pragma mark - < public >
- (void)startGetAllPhotoModel {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        HXWeakSelf
        [self.manager getPhotoListWithAlbumModel:self.albumModel complete:^(NSMutableArray *allList, NSMutableArray *previewList, HXPhotoModel *firstSelectModel, HXAlbumModel *albumModel) {
            if ((weakSelf.albumModel != albumModel && !weakSelf.assetDidChanged) || !weakSelf) {
                return;
            }
            weakSelf.assetDidChanged = NO;
//            if (weakSelf.manager.configuration.albumShowMode == HXPhotoAlbumShowModeDefault) {
//                if (weakSelf.allArray.count) {
//                    return;
//                }
//            }
            if (weakSelf.collectionViewReloadCompletion) {
                return ;
            }
            [weakSelf setPhotoModelsWithAllList:allList previewList:previewList firstSelectModel:firstSelectModel];
        }];
    });
}
- (void)setPhotoModelsWithAllList:(NSMutableArray *)allList previewList:(NSMutableArray *)previewList firstSelectModel:(HXPhotoModel *)firstSelectModel {
    self.photoCount = [self.albumModel.assetResult countOfAssetsWithMediaType:PHAssetMediaTypeImage] + self.manager.cameraPhotoCount;
    self.videoCount = [self.albumModel.assetResult countOfAssetsWithMediaType:PHAssetMediaTypeVideo] + self.manager.cameraVideoCount;
    self.collectionViewReloadCompletion = YES;
    
    self.allArray = allList.mutableCopy;
    if (self.allArray.count && self.showBottomPhotoCount) {
        self.manager.configuration.showBottomPhotoDetail = YES;
    }
    self.previewArray = previewList.mutableCopy;
    [self reloadCollectionViewWithFirstSelectModel:firstSelectModel];
}
- (void)reloadCollectionViewWithFirstSelectModel:(HXPhotoModel *)firstSelectModel {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view hx_handleLoading:NO];
        [self.hx_customNavigationController.view hx_handleLoading];
        if (!self.firstOn) {
            self.cellCanSetModel = NO;
        }
        [self.collectionView reloadData];
        [self collectionViewReloadFinishedWithFirstSelectModel:firstSelectModel];
        if (!self.firstOn) {
            dispatch_async(dispatch_get_main_queue(),^{
                // 在 collectionView reload完成之后一个一个的cell去获取image，防止一次性获取造成卡顿
                self.collectionVisibleCells = [self.collectionView.visibleCells sortedArrayUsingComparator:^NSComparisonResult(HXPhotoViewCell *obj1, HXPhotoViewCell *obj2) {
                    // visibleCells 这个数组的数据顺序是乱的，所以在获取image之前先将可见cell排序
                    NSIndexPath *indexPath1 = [self.collectionView indexPathForCell:obj1];
                    NSIndexPath *indexPath2 = [self.collectionView indexPathForCell:obj2];
                    if (indexPath1.item > indexPath2.item) {
                        return NSOrderedDescending;
                    }else {
                        return NSOrderedAscending;
                    }
                }];
                // 排序完成之后从上到下依次获取image
                [self cellSetModelData:self.collectionVisibleCells.firstObject];
            });
        }
        self.firstOn = NO;
    });
}
- (void)cellSetModelData:(HXPhotoViewCell *)cell {
    if ([cell isKindOfClass:[HXPhotoViewCell class]]) {
        HXWeakSelf
        cell.alpha = 0;
        [cell setModelDataWithHighQuality:YES completion:^(HXPhotoViewCell *myCell) {
            [UIView animateWithDuration:0.125 animations:^{
                myCell.alpha = 1;
            }];
            NSInteger count = weakSelf.collectionVisibleCells.count;
            NSInteger index = [weakSelf.collectionVisibleCells indexOfObject:myCell];
            if (index < count - 1) {
                [weakSelf cellSetModelData:weakSelf.collectionVisibleCells[index + 1]];
            }else {
                // 可见cell已全部设置
                weakSelf.cellCanSetModel = YES;
                weakSelf.collectionVisibleCells = nil;
            }
        }];
    }else {
        cell.hidden = NO;
        NSInteger count = self.collectionVisibleCells.count;
        NSInteger index = [self.collectionVisibleCells indexOfObject:cell];
        if (index < count - 1) {
            [self cellSetModelData:self.collectionVisibleCells[index + 1]];
        }else {
            self.cellCanSetModel = YES;
            self.collectionVisibleCells = nil;
        }
    }
}
- (void)collectionViewReloadFinishedWithFirstSelectModel:(HXPhotoModel *)firstSelectModel {
    if (!self.manager.configuration.singleSelected) {
        self.bottomView.selectCount = 0;
    }
    NSIndexPath *scrollIndexPath;
    UICollectionViewScrollPosition position = UICollectionViewScrollPositionNone;
    if (!self.manager.configuration.reverseDate) {
        if (self.allArray.count > 0) {
            if (firstSelectModel) {
                scrollIndexPath = [NSIndexPath indexPathForItem:[self.allArray indexOfObject:firstSelectModel] inSection:0];
                position = UICollectionViewScrollPositionCenteredVertically;
            }else {
                NSInteger forItem = (self.allArray.count - 1) <= 0 ? 0 : self.allArray.count - 1;
                scrollIndexPath = [NSIndexPath indexPathForItem:forItem inSection:0];
                position = UICollectionViewScrollPositionBottom;
            }
        }
    }else {
        if (firstSelectModel) {
            scrollIndexPath = [NSIndexPath indexPathForItem:[self.allArray indexOfObject:firstSelectModel] inSection:0];
            position = UICollectionViewScrollPositionCenteredVertically;
        }
    }
    if (scrollIndexPath) {
        [self.collectionView scrollToItemAtIndexPath:scrollIndexPath atScrollPosition:position animated:NO];
    }
}
- (HXPhotoViewCell *)currentPreviewCell:(HXPhotoModel *)model {
    if (!model || ![self.allArray containsObject:model]) {
        return nil;
    }
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self dateItem:model] inSection:0];
    return (HXPhotoViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
}
- (BOOL)scrollToModel:(HXPhotoModel *)model {
    BOOL isContainsModel = [self.allArray containsObject:model];
    if (isContainsModel) {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:[self dateItem:model] inSection:0] atScrollPosition:UICollectionViewScrollPositionNone animated:NO];
        [self.collectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:[self dateItem:model] inSection:0]]];
    }
    return isContainsModel;
}

#pragma mark - < HXCustomCameraViewControllerDelegate >
- (void)customCameraViewController:(HXCustomCameraViewController *)viewController didDone:(HXPhotoModel *)model {
    model.currentAlbumIndex = self.albumModel.index;
    if (!self.manager.configuration.singleSelected) {
        [self.manager beforeListAddCameraTakePicturesModel:model];
    }
    [self collectionViewAddModel:model beforeModel:nil];
    
//    if (self.manager.configuration.singleSelected) {
//        if (model.subType == HXPhotoModelMediaSubTypePhoto) {
//            
//            if (self.manager.configuration.useWxPhotoEdit) {
//                HX_PhotoEditViewController *vc = [[HX_PhotoEditViewController alloc] initWithConfiguration:self.manager.configuration.photoEditConfigur];
//                vc.photoModel = model;
//                vc.delegate = self;
//                vc.onlyCliping = YES;
//                vc.supportRotation = YES;
//                vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
//                vc.modalPresentationCapturesStatusBarAppearance = YES;
//                [self presentViewController:vc animated:YES completion:nil];
//            }else {
//                HXPhotoEditViewController *vc = [[HXPhotoEditViewController alloc] init];
//                vc.isInside = YES;
//                vc.delegate = self;
//                vc.manager = self.manager;
//                vc.model = model;
//                vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
//                vc.modalPresentationCapturesStatusBarAppearance = YES;
//                [self presentViewController:vc animated:YES completion:nil];
//            }
//        }else {
//            HXPhotoPreviewViewController *previewVC = [[HXPhotoPreviewViewController alloc] init];
//            if (HX_IOS9Earlier) {
//                previewVC.photoViewController = self;
//            }
//            previewVC.delegate = self;
//            previewVC.modelArray = self.previewArray;
//            previewVC.manager = self.manager;
//            previewVC.currentModelIndex = [self.previewArray indexOfObject:model];
//            self.navigationController.delegate = previewVC;
//            [self.navigationController pushViewController:previewVC animated:NO];
//        }
//    }
}
- (void)collectionViewAddModel:(HXPhotoModel *)model beforeModel:(HXPhotoModel *)beforeModel {
    
    NSInteger cameraIndex = self.manager.configuration.openCamera ? 1 : 0;
    if (beforeModel) {
        NSInteger allIndex = cameraIndex;
        NSInteger previewIndex = 0;
        if ([self.allArray containsObject:beforeModel]) {
            allIndex = [self.allArray indexOfObject:beforeModel];
        }
        if ([self.previewArray containsObject:beforeModel]) {
            previewIndex = [self.previewArray indexOfObject:beforeModel];
        }
        [self.allArray insertObject:model atIndex:allIndex];
        [self.previewArray insertObject:model atIndex:previewIndex];
    }else {
        if (self.manager.configuration.reverseDate) {
            [self.allArray insertObject:model atIndex:cameraIndex];
            [self.previewArray insertObject:model atIndex:0];
        }else {
            NSInteger count = self.allArray.count - cameraIndex;
            [self.allArray insertObject:model atIndex:count];
            [self.previewArray addObject:model];
        }
    }
    if (beforeModel && [self.allArray containsObject:model]) {
        NSInteger index = [self.allArray indexOfObject:model];
        [self.collectionView insertItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:index inSection:0]]];
    }else {
        if (self.manager.configuration.reverseDate) {
            [self.collectionView insertItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:cameraIndex inSection:0]]];
        }else {
            NSInteger count = self.allArray.count - 1;
            [self.collectionView insertItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:count - cameraIndex inSection:0]]];
        }
    }
    self.footerView.photoCount = self.photoCount;
    self.footerView.videoCount = self.videoCount;
    self.bottomView.selectCount = [self.manager selectedCount];
    if (self.manager.configuration.albumShowMode == HXPhotoAlbumShowModePopup) {
        [self.albumView refreshCamearCount];
    }else if (self.manager.configuration.albumShowMode == HXPhotoAlbumShowModeDefault) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"CustomCameraViewControllerDidDoneNotification" object:nil];
    }
}
#pragma mark - < UICollectionViewDataSource >
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.allArray.count;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    HXPhotoModel *model;
    if (indexPath.item < self.allArray.count) {
        model = self.allArray[indexPath.item];
    }
    model.dateCellIsVisible = YES;
    if (model.type == HXPhotoModelMediaTypeCamera) {
        HXPhotoCameraViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"HXPhotoCameraViewCellId" forIndexPath:indexPath];
        cell.model = model;
        if (!self.cameraCell) {
            cell.cameraImage = [HXPhotoCommon photoCommon].cameraImage;
            self.cameraCell = cell;
        }
        if (!self.cellCanSetModel) {
            cell.hidden = YES;
        }
        return cell;
    }else {
        if (self.manager.configuration.specialModeNeedHideVideoSelectBtn) {
            if (self.manager.videoSelectedType == HXPhotoManagerVideoSelectedTypeSingle && !self.manager.videoCanSelected && model.subType == HXPhotoModelMediaSubTypeVideo) {
                model.videoUnableSelect = YES;
            }else {
                model.videoUnableSelect = NO;
            }
        }
        HXPhotoViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"HXPhotoViewCellID" forIndexPath:indexPath];
        cell.delegate = self;
        cell.darkSelectBgColor = self.manager.configuration.cellDarkSelectBgColor;
        cell.darkSelectedTitleColor = self.manager.configuration.cellDarkSelectTitleColor;
        cell.selectBtn.selected = _selectedIndex == indexPath.row;

        UIColor *cellSelectedTitleColor = self.manager.configuration.cellSelectedTitleColor;
        UIColor *selectedTitleColor = self.manager.configuration.selectedTitleColor;
        UIColor *cellSelectedBgColor = self.manager.configuration.cellSelectedBgColor;
        if (cellSelectedTitleColor) {
            cell.selectedTitleColor = cellSelectedTitleColor;
        }else if (selectedTitleColor) {
            cell.selectedTitleColor = selectedTitleColor;
        }
//        if (cellSelectedBgColor) {
//            cell.selectBgColor = cellSelectedBgColor;
//        }else {
//            cell.selectBgColor = self.manager.configuration.themeColor;
//        }
        cell.selectBgColor = [UIColor whiteColor];
        if (self.cellCanSetModel) {
            [cell setModel:model clearImage:NO];
            [cell setModelDataWithHighQuality:NO completion:nil];
        }else {
            [cell setModel:model clearImage:YES];
        }
        cell.singleSelected = self.manager.configuration.singleSelected;
        return cell;
    }
}
#pragma mark - < UICollectionViewDelegate >
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.navigationController.topViewController != self) {
        return;
    }
    if (_selectedIndex == indexPath.row) {
        _selectedIndex = -1;
    } else {
        _selectedIndex = indexPath.row;
        if (![_selectedIndexArray containsObject:indexPath]) {
            [_selectedIndexArray addObject: indexPath];
        }
    }
//    HXPhotoViewCell *cell = (HXPhotoViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
//    cell.selectBtn.selected = _selectedIndex == indexPath.row;

    for (NSIndexPath *path in _selectedIndexArray) {
        if (path.row != _selectedIndex) {
            HXPhotoViewCell *cell = (HXPhotoViewCell *)[collectionView cellForItemAtIndexPath:path];
            cell.selectBtn.selected = true;
            [self.manager beforeSelectedListdeletePhotoModel:cell.model];
            cell.model.selectIndexStr = @"";
            [self photoViewCell:cell didSelectBtn:cell.selectBtn];
        } else {
            HXPhotoViewCell *cell = (HXPhotoViewCell *)[collectionView cellForItemAtIndexPath:path];
            cell.selectBtn.selected = false;
            [self photoViewCell:cell didSelectBtn:cell.selectBtn];
        }
    }
//    visibleCell.model.selectIndexStr = @"";
//    [self photoViewCell:cell didSelectBtn:cell.selectBtn];

    [collectionView reloadItemsAtIndexPaths:_selectedIndexArray];
    return;
    
    HXPhotoModel *model = self.allArray[indexPath.item];
    if (model.type == HXPhotoModelMediaTypeCamera) {
        if(![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
            [self.view hx_showImageHUDText:[NSBundle hx_localizedStringForKey:@"无法使用相机!"]];
            return;
        }
        HXWeakSelf
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) {
                    if (weakSelf.manager.configuration.replaceCameraViewController) {
                        HXPhotoConfigurationCameraType cameraType;
                        if (weakSelf.manager.type == HXPhotoManagerSelectedTypePhoto) {
                            cameraType = HXPhotoConfigurationCameraTypePhoto;
                        }else if (weakSelf.manager.type == HXPhotoManagerSelectedTypeVideo) {
                            cameraType = HXPhotoConfigurationCameraTypeVideo;
                        }else {
                            if (!weakSelf.manager.configuration.selectTogether) {
                                if (weakSelf.manager.selectedPhotoArray.count > 0) {
                                    cameraType = HXPhotoConfigurationCameraTypePhoto;
                                }else if (weakSelf.manager.selectedVideoArray.count > 0) {
                                    cameraType = HXPhotoConfigurationCameraTypeVideo;
                                }else {
                                    cameraType = HXPhotoConfigurationCameraTypePhotoAndVideo;
                                }
                            }else {
                                cameraType = HXPhotoConfigurationCameraTypePhotoAndVideo;
                            }
                        }
                        switch (weakSelf.manager.configuration.customCameraType) {
                            case HXPhotoCustomCameraTypePhoto:
                                cameraType = HXPhotoConfigurationCameraTypePhoto;
                                break;
                            case HXPhotoCustomCameraTypeVideo:
                                cameraType = HXPhotoConfigurationCameraTypeVideo;
                                break;
                            case HXPhotoCustomCameraTypePhotoAndVideo:
                                cameraType = HXPhotoConfigurationCameraTypePhotoAndVideo;
                                break;
                            default:
                                break;
                        }
                        if (weakSelf.manager.configuration.shouldUseCamera) {
                            weakSelf.manager.configuration.shouldUseCamera(weakSelf, cameraType, weakSelf.manager);
                        }
                        weakSelf.manager.configuration.useCameraComplete = ^(HXPhotoModel *model) {
                            if (model.videoDuration < weakSelf.manager.configuration.videoMinimumSelectDuration) {
                                [weakSelf.view hx_showImageHUDText:[NSString stringWithFormat:[NSBundle hx_localizedStringForKey:@"视频少于%ld秒，无法选择"], weakSelf.manager.configuration.videoMinimumSelectDuration]];
                            }else if (model.videoDuration >= weakSelf.manager.configuration.videoMaximumSelectDuration + 1) {
                                [weakSelf.view hx_showImageHUDText:[NSString stringWithFormat:[NSBundle hx_localizedStringForKey:@"视频大于%ld秒，无法选择"], weakSelf.manager.configuration.videoMaximumSelectDuration]];
                            }
                            [weakSelf customCameraViewController:nil didDone:model];
                        };
                        return;
                    }
                    HXCustomCameraViewController *vc = [[HXCustomCameraViewController alloc] init];
                    vc.delegate = weakSelf;
                    vc.manager = weakSelf.manager;
                    HXCustomNavigationController *nav = [[HXCustomNavigationController alloc] initWithRootViewController:vc];
                    nav.isCamera = YES;
                    nav.supportRotation = weakSelf.manager.configuration.supportRotation;
                    nav.modalPresentationStyle = UIModalPresentationOverFullScreen;
                    nav.modalPresentationCapturesStatusBarAppearance = YES;
                    [weakSelf presentViewController:nav animated:YES completion:nil];
                }else {
                    hx_showAlert(weakSelf, [NSBundle hx_localizedStringForKey:@"无法使用相机"], [NSBundle hx_localizedStringForKey:@"请在设置-隐私-相机中允许访问相机"], [NSBundle hx_localizedStringForKey:@"取消"], [NSBundle hx_localizedStringForKey:@"设置"] , nil, ^{
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                    }); 
                }
            });
        }];
    }else {
        HXPhotoViewCell *cell = (HXPhotoViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        if (cell.model.videoUnableSelect) {
            [self.view hx_showImageHUDText:[NSBundle hx_localizedStringForKey:@"视频不能和图片同时选择"]];
            return;
        }
        if (cell.model.isICloud) {
            if (!cell.model.iCloudDownloading) {
                [cell startRequestICloudAsset];
            }
//            if (self.manager.configuration.downloadICloudAsset) {
//                if (!cell.model.iCloudDownloading) {
//                    [cell startRequestICloudAsset];
//                }
//            }else {
//                [self.view hx_showImageHUDText:[NSBundle hx_localizedStringForKey:@"尚未从iCloud上下载，请至系统相册下载完毕后选择"]];
//            }
            return;
        }
        if (cell.model.subType == HXPhotoModelMediaSubTypeVideo) {
            if (cell.model.videoDuration >= self.manager.configuration.videoMaximumSelectDuration + 1) {
                if (self.manager.configuration.selectVideoBeyondTheLimitTimeAutoEdit &&
                    self.manager.configuration.videoCanEdit) {
                    if (cell.model.cameraVideoType == HXPhotoModelMediaTypeCameraVideoTypeNetWork) {
                        if (self.manager.configuration.selectNetworkVideoCanEdit) {
                            [self jumpVideoEditWithModel:cell.model];
                            return;
                        }
                    }else {
                        [self jumpVideoEditWithModel:cell.model];
                        return;
                    }
                }
            }
        }
        if (!self.manager.configuration.singleSelected) {
            HXPhotoPreviewViewController *previewVC = [[HXPhotoPreviewViewController alloc] init];
            if (HX_IOS9Earlier) {
                previewVC.photoViewController = self;
            }
            NSInteger currentIndex = [self.previewArray indexOfObject:cell.model];
            previewVC.delegate = self;
            previewVC.modelArray = self.previewArray;
            previewVC.manager = self.manager;
            previewVC.currentModelIndex = currentIndex;
            self.navigationController.delegate = previewVC;
            [self.navigationController pushViewController:previewVC animated:YES];
        }else {
            if (!self.manager.configuration.singleJumpEdit) {
                NSInteger currentIndex = [self.previewArray indexOfObject:cell.model];
                HXPhotoPreviewViewController *previewVC = [[HXPhotoPreviewViewController alloc] init];
                if (HX_IOS9Earlier) {
                    previewVC.photoViewController = self;
                }
                previewVC.delegate = self;
                previewVC.modelArray = self.previewArray;
                previewVC.manager = self.manager;
                previewVC.currentModelIndex = currentIndex;
                self.navigationController.delegate = previewVC;
                [self.navigationController pushViewController:previewVC animated:YES];
            }else {
                if (cell.model.subType == HXPhotoModelMediaSubTypePhoto) {
                    if (self.manager.configuration.useWxPhotoEdit) {
                        HX_PhotoEditViewController *vc = [[HX_PhotoEditViewController alloc] initWithConfiguration:self.manager.configuration.photoEditConfigur];
                        vc.photoModel = cell.model;
                        vc.delegate = self;
                        vc.onlyCliping = YES;
                        vc.supportRotation = YES;
                        vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
                        vc.modalPresentationCapturesStatusBarAppearance = YES;
                        [self presentViewController:vc animated:YES completion:nil];
                    }else {
                        HXPhotoEditViewController *vc = [[HXPhotoEditViewController alloc] init];
                        vc.isInside = YES;
                        vc.model = cell.model;
                        vc.delegate = self;
                        vc.manager = self.manager;
                        vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
                        vc.modalPresentationCapturesStatusBarAppearance = YES;
                        [self presentViewController:vc animated:YES completion:nil];
                    }
                }else {
                    NSInteger currentIndex = [self.previewArray indexOfObject:cell.model];
                    HXPhotoPreviewViewController *previewVC = [[HXPhotoPreviewViewController alloc] init];
                    if (HX_IOS9Earlier) {
                        previewVC.photoViewController = self;
                    }
                    previewVC.delegate = self;
                    previewVC.modelArray = self.previewArray;
                    previewVC.manager = self.manager;
                    previewVC.currentModelIndex = currentIndex;
                    self.navigationController.delegate = previewVC;
                    [self.navigationController pushViewController:previewVC animated:YES];
                }
            }
        }
    }
}
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[HXPhotoViewCell class]]) {
        [(HXPhotoViewCell *)cell cancelRequest];
    }
}
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if ([kind isEqualToString:UICollectionElementKindSectionFooter]) {
        if (self.manager.configuration.showBottomPhotoDetail) {
            HXPhotoViewSectionFooterView *footerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"sectionFooterId" forIndexPath:indexPath];
            footerView.textColor = self.manager.configuration.photoListBottomPhotoCountTextColor;
            footerView.bgColor = self.manager.configuration.photoListViewBgColor;
            footerView.photoCount = self.photoCount;
            footerView.videoCount = self.videoCount;
            self.footerView = footerView;
            return footerView;
        }
    }
    return nil;
}
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeZero;
}
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    return self.manager.configuration.showBottomPhotoDetail ? CGSizeMake(self.view.hx_w, 50) : CGSizeZero;
}
- (UIViewController *)previewViewControlerWithIndexPath:(NSIndexPath *)indexPath {
    HXPhotoViewCell *cell = (HXPhotoViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
    if (!cell || cell.model.type == HXPhotoModelMediaTypeCamera || cell.model.isICloud) {
        return nil;
    }
    if (cell.model.networkPhotoUrl) {
        if (cell.model.downloadError) {
            return nil;
        }
        if (!cell.model.downloadComplete) {
            return nil;
        }
    }
    HXPhotoModel *_model = cell.model;
    HXPhoto3DTouchViewController *vc = [[HXPhoto3DTouchViewController alloc] init];
    vc.model = _model;
    vc.indexPath = indexPath;
    vc.image = cell.imageView.image;
    vc.modalPresentationCapturesStatusBarAppearance = YES;
    HXWeakSelf
    vc.downloadImageComplete = ^(HXPhoto3DTouchViewController *vc, HXPhotoModel *model) {
        if (!model.loadOriginalImage) {
            HXPhotoViewCell *myCell = (HXPhotoViewCell *)[weakSelf.collectionView cellForItemAtIndexPath:vc.indexPath];
            if (myCell) {
                [myCell resetNetworkImage];
            }
        }
    };
    vc.preferredContentSize = _model.previewViewSize;
    return vc;
}
- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
    if (!indexPath) {
        return nil;
    }
    if (![[self.collectionView cellForItemAtIndexPath:indexPath] isKindOfClass:[HXPhotoViewCell class]]) {
        return nil;
    }
    HXPhotoViewCell *cell = (HXPhotoViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
    if (!cell || cell.model.type == HXPhotoModelMediaTypeCamera || cell.model.isICloud) {
        return nil;
    }
    if (cell.model.networkPhotoUrl) {
        if (cell.model.downloadError) {
            return nil;
        }
        if (!cell.model.downloadComplete) {
            return nil;
        }
    }
    //设置突出区域
    previewingContext.sourceRect = [self.collectionView cellForItemAtIndexPath:indexPath].frame;
    return  [self previewViewControlerWithIndexPath:indexPath];
}
- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    [self pushPreviewControler:viewControllerToCommit];
}
- (void)pushPreviewControler:(UIViewController *)viewController {
    HXPhoto3DTouchViewController *vc = (HXPhoto3DTouchViewController *)viewController;
    HXPhotoViewCell *cell = (HXPhotoViewCell *)[self.collectionView cellForItemAtIndexPath:vc.indexPath];
    if (!self.manager.configuration.singleSelected) {
        HXPhotoPreviewViewController *previewVC = [[HXPhotoPreviewViewController alloc] init];
        if (HX_IOS9Earlier) {
            previewVC.photoViewController = self;
        }
        previewVC.delegate = self;
        previewVC.modelArray = self.previewArray;
        previewVC.manager = self.manager;
#if HasSDWebImage
        cell.model.tempImage = vc.sdImageView.image;
#elif HasYYKitOrWebImage
        cell.model.tempImage = vc.animatedImageView.image;
#else
        cell.model.tempImage = vc.imageView.image;
#endif
        NSInteger currentIndex = [self.previewArray indexOfObject:cell.model];
        previewVC.currentModelIndex = currentIndex;
        self.navigationController.delegate = previewVC;
        [self.navigationController pushViewController:previewVC animated:NO];
    }else {
        if (!self.manager.configuration.singleJumpEdit) {
            HXPhotoPreviewViewController *previewVC = [[HXPhotoPreviewViewController alloc] init];
            if (HX_IOS9Earlier) {
                previewVC.photoViewController = self;
            }
            previewVC.delegate = self;
            previewVC.modelArray = self.previewArray;
            previewVC.manager = self.manager;
#if HasSDWebImage
            cell.model.tempImage = vc.sdImageView.image;
#elif HasYYKitOrWebImage
            cell.model.tempImage = vc.animatedImageView.image;
#else
            cell.model.tempImage = vc.imageView.image;
#endif
            NSInteger currentIndex = [self.previewArray indexOfObject:cell.model];
            previewVC.currentModelIndex = currentIndex;
            self.navigationController.delegate = previewVC;
            [self.navigationController pushViewController:previewVC animated:NO];
        }else {
            if (cell.model.subType == HXPhotoModelMediaSubTypePhoto) {
                if (self.manager.configuration.useWxPhotoEdit) {
//                    HX_PhotoEditViewController *vc = [[HX_PhotoEditViewController alloc] initWithConfiguration:self.manager.configuration.photoEditConfigur];
//                    vc.photoModel = cell.model;
//                    vc.delegate = self;
//                    vc.onlyCliping = YES;
//                    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
//                    vc.modalPresentationCapturesStatusBarAppearance = YES;
//                    [self presentViewController:vc animated:NO completion:nil];
                }else {
                    HXPhotoEditViewController *vc = [[HXPhotoEditViewController alloc] init];
                    vc.model = cell.model;
                    vc.delegate = self;
                    vc.manager = self.manager;
                    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
                    vc.modalPresentationCapturesStatusBarAppearance = YES;
                    [self presentViewController:vc animated:NO completion:nil];
                }
            }else {
                HXPhotoPreviewViewController *previewVC = [[HXPhotoPreviewViewController alloc] init];
                if (HX_IOS9Earlier) {
                    previewVC.photoViewController = self;
                }
                previewVC.delegate = self;
                previewVC.modelArray = self.previewArray;
                previewVC.manager = self.manager;
#if HasSDWebImage
                cell.model.tempImage = vc.sdImageView.image;
#elif HasYYKitOrWebImage
                cell.model.tempImage = vc.animatedImageView.image;
#else
                cell.model.tempImage = vc.imageView.image;
#endif
                NSInteger currentIndex = [self.previewArray indexOfObject:cell.model];
                previewVC.currentModelIndex = currentIndex;
                self.navigationController.delegate = previewVC;
                [self.navigationController pushViewController:previewVC animated:NO];
            }
        }
    }
}
#pragma mark - < HXPhotoViewCellDelegate >
- (void)photoViewCellRequestICloudAssetComplete:(HXPhotoViewCell *)cell {
    if (cell.model.dateCellIsVisible) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self dateItem:cell.model] inSection:0];
        if (indexPath) {
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        }
        [self.manager addICloudModel:cell.model];
    }
}
- (void)photoViewCell:(HXPhotoViewCell *)cell didSelectBtn:(UIButton *)selectBtn {
    if (selectBtn.selected) {
        if (cell.model.type != HXPhotoModelMediaTypeCameraVideo && cell.model.type != HXPhotoModelMediaTypeCameraPhoto) {
            cell.model.thumbPhoto = nil;
            cell.model.previewPhoto = nil;
        }
        [self.manager beforeSelectedListdeletePhotoModel:cell.model];
        cell.model.selectIndexStr = @"";
        cell.selectMaskLayer.hidden = YES;
        selectBtn.selected = NO;
    }else {
        NSString *str = [self.manager maximumOfJudgment:cell.model];
        if (str) {
            if ([str isEqualToString:@"selectVideoBeyondTheLimitTimeAutoEdit"]) {
                [self jumpVideoEditWithModel:cell.model];
                return;
            }else {
//                for (HXPhotoViewCell *visibleCell in _collectionView.visibleCells) {
//
//                    [self.manager beforeSelectedListdeletePhotoModel:visibleCell.model];
//                    visibleCell.model.selectIndexStr = @"";
//                    if (cell.selectBtn.selected) {
//                        cell.selectBtn.selected = NO;
//                        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self dateItem:visibleCell.model] inSection:0];
//
//                        [self.collectionView reloadItemsAtIndexPaths: @[indexPath]];
//                    }
////                    if (!visibleCell.selectMaskLayer.hidden) {
////                        visibleCell.selectMaskLayer.hidden = YES;
////                    }
//                }
//                [self.view hx_showImageHUDText:str];
            }
        }
        if (cell.model.type != HXPhotoModelMediaTypeCameraVideo && cell.model.type != HXPhotoModelMediaTypeCameraPhoto) {
            cell.model.thumbPhoto = cell.imageView.image;
        }
        [self.manager beforeSelectedListAddPhotoModel:cell.model];
//        cell.selectMaskLayer.hidden = NO;
//        selectBtn.selected = YES;
////        [selectBtn setTitle:cell.model.selectIndexStr forState:UIControlStateSelected];
//        CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
//        anim.duration = 0.25;
//        anim.values = @[@(1.2),@(0.8),@(1.1),@(0.9),@(1.0)];
//        [selectBtn.layer addAnimation:anim forKey:@""];
    }
    
    NSMutableArray *indexPathList = [NSMutableArray array];
//    if (!selectBtn.selected) {
//        NSInteger index = 0;
//        for (HXPhotoModel *model in [self.manager selectedArray]) {
//            model.selectIndexStr = [NSString stringWithFormat:@"%ld",index + 1];
//            if (model.currentAlbumIndex == self.albumModel.index) {
//                if (model.dateCellIsVisible) {
//                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self dateItem:model] inSection:0];
//                    [indexPathList addObject:indexPath];
//                }
//            }
//            index++;
//        }
////        if (indexPathList.count > 0) {
////            [self.collectionView reloadItemsAtIndexPaths:indexPathList];
////        }
//    }
    
//    if (self.manager.videoSelectedType == HXPhotoManagerVideoSelectedTypeSingle) {
//        for (UICollectionViewCell *tempCell in self.collectionView.visibleCells) {
//            if ([tempCell isKindOfClass:[HXPhotoViewCell class]]) {
//                if ([(HXPhotoViewCell *)tempCell model].subType == HXPhotoModelMediaSubTypeVideo) {
//                    [indexPathList addObject:[self.collectionView indexPathForCell:tempCell]];
//                }
//            }
//        }
//        if (indexPathList.count) {
//            [self.collectionView reloadItemsAtIndexPaths:indexPathList];
//        }
//    }else {
//        if (!selectBtn.selected) {
//            if (indexPathList.count) {
//                [self.collectionView reloadItemsAtIndexPaths:indexPathList];
//            }
//        }
//    }
    
    self.bottomView.selectCount = [self.manager selectedCount];
    if ([self.delegate respondsToSelector:@selector(photoViewControllerDidChangeSelect:selected:)]) {
        [self.delegate photoViewControllerDidChangeSelect:cell.model selected:selectBtn.selected];
    }
}
#pragma mark - < HXPhotoPreviewViewControllerDelegate >
- (void)photoPreviewCellDownloadImageComplete:(HXPhotoPreviewViewController *)previewController model:(HXPhotoModel *)model {
    if (model.dateCellIsVisible && !model.loadOriginalImage) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self dateItem:model] inSection:0];
        HXPhotoViewCell *cell = (HXPhotoViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        if (cell) {
            [cell resetNetworkImage];
        }
    }
}
- (void)photoPreviewDownLoadICloudAssetComplete:(HXPhotoPreviewViewController *)previewController model:(HXPhotoModel *)model {
    if (model.iCloudRequestID) {
        [[PHImageManager defaultManager] cancelImageRequest:model.iCloudRequestID];
    }
    if (model.dateCellIsVisible) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self dateItem:model] inSection:0];
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
    }
    [self.manager addICloudModel:model];
}
- (void)photoPreviewControllerDidSelect:(HXPhotoPreviewViewController *)previewController model:(HXPhotoModel *)model {
    NSMutableArray *indexPathList = [NSMutableArray array];
    if (model.currentAlbumIndex == self.albumModel.index) {
        [indexPathList addObject:[NSIndexPath indexPathForItem:[self dateItem:model] inSection:0]];
    }
    if (!model.selected) {
        NSInteger index = 0;
        for (HXPhotoModel *subModel in [self.manager selectedArray]) {
            subModel.selectIndexStr = [NSString stringWithFormat:@"%ld",index + 1];
            if (subModel.currentAlbumIndex == self.albumModel.index && subModel.dateCellIsVisible) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self dateItem:subModel] inSection:0];
                [indexPathList addObject:indexPath];
            }
            index++;
        }
    }
    
    if (self.manager.videoSelectedType == HXPhotoManagerVideoSelectedTypeSingle) {
        for (UICollectionViewCell *tempCell in self.collectionView.visibleCells) {
            if ([tempCell isKindOfClass:[HXPhotoViewCell class]]) {
                if ([(HXPhotoViewCell *)tempCell model].subType == HXPhotoModelMediaSubTypeVideo &&
                    [(HXPhotoViewCell *)tempCell model] != model) {
                    [indexPathList addObject:[self.collectionView indexPathForCell:tempCell]];
                }
            }
        }
    }
    if (indexPathList.count) {
        [self.collectionView reloadItemsAtIndexPaths:indexPathList];
    }
    
    self.bottomView.selectCount = [self.manager selectedCount];
    if ([self.delegate respondsToSelector:@selector(photoViewControllerDidChangeSelect:selected:)]) {
        [self.delegate photoViewControllerDidChangeSelect:model selected:model.selected];
    }
}
- (void)photoPreviewControllerDidDone:(HXPhotoPreviewViewController *)previewController {
    [self photoBottomViewDidDoneBtn];
}
- (void)photoPreviewDidEditClick:(HXPhotoPreviewViewController *)previewController model:(HXPhotoModel *)model beforeModel:(HXPhotoModel *)beforeModel {
    if (model.subType == HXPhotoModelMediaSubTypePhoto) {
        if (self.manager.configuration.useWxPhotoEdit) {
            [self.collectionView reloadData];
            [self.bottomView requestPhotosBytes];
            return;
        }
    }
    model.currentAlbumIndex = self.albumModel.index;
    
    [self photoPreviewControllerDidSelect:nil model:beforeModel];
    [self collectionViewAddModel:model beforeModel:beforeModel];
    
//    [self photoBottomViewDidDoneBtn];
}
- (void)photoPreviewSingleSelectedClick:(HXPhotoPreviewViewController *)previewController model:(HXPhotoModel *)model {
    [self.manager beforeSelectedListAddPhotoModel:model];
    [self photoBottomViewDidDoneBtn];
}
#pragma mark - < HX_PhotoEditViewControllerDelegate >
- (void)photoEditingController:(HX_PhotoEditViewController *)photoEditingVC didFinishPhotoEdit:(HXPhotoEdit *)photoEdit photoModel:(HXPhotoModel *)photoModel {
    if (self.manager.configuration.singleSelected) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
        self.isNewEditDismiss = YES;
        [self.manager beforeSelectedListAddPhotoModel:photoModel];
        [self photoBottomViewDidDoneBtn];
        return;
    }
    [self.collectionView reloadData];
    [self.bottomView requestPhotosBytes];
}
#pragma mark - < HXPhotoEditViewControllerDelegate >
- (void)photoEditViewControllerDidClipClick:(HXPhotoEditViewController *)photoEditViewController beforeModel:(HXPhotoModel *)beforeModel afterModel:(HXPhotoModel *)afterModel {
    if (self.manager.configuration.singleSelected) {
        [self.manager beforeSelectedListAddPhotoModel:afterModel];
        [self photoBottomViewDidDoneBtn];
        return;
    }
    [self.manager beforeSelectedListdeletePhotoModel:beforeModel];
    
    [self photoPreviewControllerDidSelect:nil model:beforeModel];
    
    afterModel.currentAlbumIndex = self.albumModel.index;
    [self.manager beforeListAddCameraTakePicturesModel:afterModel];
    [self collectionViewAddModel:afterModel beforeModel:beforeModel];
}
#pragma mark - < HXVideoEditViewControllerDelegate >
- (void)videoEditViewControllerDidDoneClick:(HXVideoEditViewController *)videoEditViewController beforeModel:(HXPhotoModel *)beforeModel afterModel:(HXPhotoModel *)afterModel {
    [self photoEditViewControllerDidClipClick:nil beforeModel:beforeModel afterModel:afterModel];
    if (afterModel.needHideSelectBtn && !self.manager.configuration.singleSelected) {
        self.isNewEditDismiss = YES;
        [self.manager beforeSelectedListAddPhotoModel:afterModel];
        [self photoBottomViewDidDoneBtn];
    }
}
#pragma mark - < HXPhotoBottomViewDelegate >
- (void)photoBottomViewDidPreviewBtn {
    if (self.navigationController.topViewController != self || [self.manager selectedCount] == 0) {
        return;
    }
    HXPhotoPreviewViewController *previewVC = [[HXPhotoPreviewViewController alloc] init];
    if (HX_IOS9Earlier) {
        previewVC.photoViewController = self;
    }
    previewVC.delegate = self;
    previewVC.modelArray = [NSMutableArray arrayWithArray:[self.manager selectedArray]];
    previewVC.manager = self.manager;
    previewVC.currentModelIndex = 0;
    previewVC.selectPreview = YES;
    self.navigationController.delegate = previewVC;
    [self.navigationController pushViewController:previewVC animated:YES];
}
- (void)photoBottomViewDidDoneBtn {
    if (self.manager.configuration.requestImageAfterFinishingSelection) {
        if ([self.navigationController.viewControllers.lastObject isKindOfClass:[HXPhotoPreviewViewController class]]) {
            self.navigationController.navigationBar.userInteractionEnabled = NO;
        }
        if (self.manager.configuration.albumShowMode == HXPhotoAlbumShowModePopup) {
            if (self.manager.configuration.photoListTitleView) {
                self.navigationController.navigationItem.titleView.userInteractionEnabled = NO;
            }else {
                self.albumTitleView.userInteractionEnabled = NO;
            }
        }
        self.navigationController.viewControllers.lastObject.view.userInteractionEnabled = NO;
        [self.navigationController.viewControllers.lastObject.view hx_showLoadingHUDText:nil];
        HXWeakSelf
        BOOL requestOriginal = self.manager.original;
        if (self.manager.configuration.hideOriginalBtn) {
            requestOriginal = self.manager.configuration.requestOriginalImage;
        }
        if (requestOriginal) {
            [self.manager.selectedArray hx_requestImageSeparatelyWithOriginal:requestOriginal completion:^(NSArray<UIImage *> * _Nullable imageArray, NSArray<HXPhotoModel *> * _Nullable errorArray) {
                if (!weakSelf) {
                    return;
                }
                [weakSelf afterFinishingGetVideoURL];
            }];
        }else {
            [self.manager.selectedArray hx_requestImageWithOriginal:requestOriginal completion:^(NSArray<UIImage *> * _Nullable imageArray, NSArray<HXPhotoModel *> * _Nullable errorArray) {
                if (!weakSelf) {
                    return;
                }
                [weakSelf afterFinishingGetVideoURL];
            }];
        }
        return;
    }
    [self dismissVC];
}
- (void)afterFinishingGetVideoURL {
    NSArray *videoArray = self.manager.selectedVideoArray;
    if (videoArray.count) {
        BOOL requestOriginal = self.manager.original;
        if (self.manager.configuration.hideOriginalBtn) {
            requestOriginal = self.manager.configuration.requestOriginalImage;
        }
        HXWeakSelf
        __block NSInteger videoCount = videoArray.count;
        __block NSInteger videoIndex = 0;
        BOOL endOriginal = self.manager.configuration.exportVideoURLForHighestQuality ? requestOriginal : NO;
        for (HXPhotoModel *pm in videoArray) {
            [pm exportVideoWithPresetName:endOriginal ? AVAssetExportPresetHighestQuality : AVAssetExportPresetMediumQuality startRequestICloud:nil iCloudProgressHandler:nil exportProgressHandler:nil success:^(NSURL * _Nullable videoURL, HXPhotoModel * _Nullable model) {
                if (!weakSelf) {
                    return;
                }
                videoIndex++;
                if (videoIndex == videoCount) {
                    [weakSelf dismissVC];
                }
            } failed:^(NSDictionary * _Nullable info, HXPhotoModel * _Nullable model) {
                if (!weakSelf) {
                    return;
                }
                videoIndex++;
                if (videoIndex == videoCount) {
                    [weakSelf dismissVC];
                }
            }];
        }
    }else {
        [self dismissVC];
    }
}
- (void)dismissVC {
    [self.manager selectedListTransformAfter];
    if (self.manager.configuration.albumShowMode == HXPhotoAlbumShowModePopup) {
        if (self.manager.configuration.photoListChangeTitleViewSelected) {
            self.manager.configuration.photoListChangeTitleViewSelected(NO);
        }
        if (self.manager.configuration.photoListTitleView) {
            self.navigationItem.titleView.userInteractionEnabled = YES;
        }else {
            self.albumTitleView.userInteractionEnabled = YES;
        }
    }
    self.navigationController.navigationBar.userInteractionEnabled = YES;
    self.navigationController.viewControllers.lastObject.view.userInteractionEnabled = YES;
    [self.navigationController.viewControllers.lastObject.view hx_handleLoading];
    [self cleanSelectedList];
    self.manager.selectPhotoing = NO;
    BOOL selectPhotoFinishDismissAnimated = self.manager.selectPhotoFinishDismissAnimated;
    if (self.isNewEditDismiss || [self.presentedViewController isKindOfClass:[HX_PhotoEditViewController class]] || [self.presentedViewController isKindOfClass:[HXVideoEditViewController class]]) {
        [self.presentingViewController dismissViewControllerAnimated:selectPhotoFinishDismissAnimated completion:^{
            if ([self.delegate respondsToSelector:@selector(photoViewControllerFinishDismissCompletion:)]) {
                [self.delegate photoViewControllerFinishDismissCompletion:self];
            }
        }];
    }else {
        [self dismissViewControllerAnimated:selectPhotoFinishDismissAnimated completion:^{
            if ([self.delegate respondsToSelector:@selector(photoViewControllerFinishDismissCompletion:)]) {
                [self.delegate photoViewControllerFinishDismissCompletion:self];
            }
        }];
    }
}
- (void)photoBottomViewDidEditBtn {
    HXPhotoModel *model = self.manager.selectedArray.firstObject;
    if (model.networkPhotoUrl) {
        if (model.downloadError) {
            [self.view hx_showImageHUDText:[NSBundle hx_localizedStringForKey:@"下载失败"]];
            return;
        }
        if (!model.downloadComplete) {
            [self.view hx_showImageHUDText:[NSBundle hx_localizedStringForKey:@"照片正在下载"]];
            return;
        }
    }
    if (model.type == HXPhotoModelMediaTypePhotoGif ||
        model.cameraPhotoType == HXPhotoModelMediaTypeCameraPhotoTypeNetWorkGif) {
        if (model.photoEdit) {
            [self jumpEditViewControllerWithModel:model];
        }else {
            HXWeakSelf
            hx_showAlert(self, [NSBundle hx_localizedStringForKey:@"编辑后，GIF将会变为静态图，确定继续吗？"], nil, [NSBundle hx_localizedStringForKey:@"取消"], [NSBundle hx_localizedStringForKey:@"确定"], nil, ^{
                [weakSelf jumpEditViewControllerWithModel:model];
            });
        }
        return;
    }
    if (model.type == HXPhotoModelMediaTypeLivePhoto) {
        if (model.photoEdit) {
            [self jumpEditViewControllerWithModel:model];
        }else {
            HXWeakSelf
            hx_showAlert(self, [NSBundle hx_localizedStringForKey:@"编辑后，LivePhoto将会变为静态图，确定继续吗？"], nil, [NSBundle hx_localizedStringForKey:@"取消"], [NSBundle hx_localizedStringForKey:@"确定"], nil, ^{
                [weakSelf jumpEditViewControllerWithModel:model];
            });
        }
        return;
    }
    [self jumpEditViewControllerWithModel:model];
}
- (void)jumpEditViewControllerWithModel:(HXPhotoModel *)model {
    if (model.subType == HXPhotoModelMediaSubTypePhoto) {
        if (self.manager.configuration.replacePhotoEditViewController) {
#pragma mark - < 替换图片编辑 >
            if (self.manager.configuration.shouldUseEditAsset) {
                self.manager.configuration.shouldUseEditAsset(self, NO,self.manager, model);
            }
            HXWeakSelf
            self.manager.configuration.usePhotoEditComplete = ^(HXPhotoModel *beforeModel, HXPhotoModel *afterModel) {
                [weakSelf photoEditViewControllerDidClipClick:nil beforeModel:beforeModel afterModel:afterModel];
            };
        }else {
            if (self.manager.configuration.useWxPhotoEdit) {
                HX_PhotoEditViewController *vc = [[HX_PhotoEditViewController alloc] initWithConfiguration:self.manager.configuration.photoEditConfigur];
                vc.photoModel = self.manager.selectedPhotoArray.firstObject;
                vc.delegate = self;
                vc.supportRotation = YES;
                vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
                vc.modalPresentationCapturesStatusBarAppearance = YES;
                [self presentViewController:vc animated:YES completion:nil];
            }else {
                HXPhotoEditViewController *vc = [[HXPhotoEditViewController alloc] init];
                vc.isInside = YES;
                vc.model = self.manager.selectedPhotoArray.firstObject;
                vc.delegate = self;
                vc.manager = self.manager;
                vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
                vc.modalPresentationCapturesStatusBarAppearance = YES;
                [self presentViewController:vc animated:YES completion:nil];
            }
        }
    }else if (model.subType == HXPhotoModelMediaSubTypeVideo) {
        if (self.manager.configuration.replaceVideoEditViewController) {
#pragma mark - < 替换视频编辑 >
            if (self.manager.configuration.shouldUseEditAsset) {
                self.manager.configuration.shouldUseEditAsset(self, NO, self.manager, model);
            }
            HXWeakSelf
            self.manager.configuration.useVideoEditComplete = ^(HXPhotoModel *beforeModel, HXPhotoModel *afterModel) {
                [weakSelf photoEditViewControllerDidClipClick:nil beforeModel:beforeModel afterModel:afterModel];
            };
        }else {
            [self jumpVideoEditWithModel:self.manager.selectedVideoArray.firstObject];
        }
    }
}
- (void)jumpVideoEditWithModel:(HXPhotoModel *)model {
    HXVideoEditViewController *vc = [[HXVideoEditViewController alloc] init];
    vc.model = model;
    vc.delegate = self;
    vc.manager = self.manager;
    vc.isInside = YES;
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalPresentationCapturesStatusBarAppearance = YES;
    [self presentViewController:vc animated:YES completion:nil];
}
- (void)cleanSelectedList {
    NSArray *allList;
    NSArray *photoList;
    NSArray *videoList;
    BOOL isOriginal;
    if (!self.manager.configuration.singleSelected) {
        allList = self.manager.afterSelectedArray.copy;
        photoList = self.manager.afterSelectedPhotoArray.copy;
        videoList = self.manager.afterSelectedVideoArray.copy;
        isOriginal = self.manager.afterOriginal;
    }else {
        allList = self.manager.selectedArray.copy;
        photoList = self.manager.selectedPhotoArray.copy;
        videoList = self.manager.selectedVideoArray.copy;
        isOriginal = self.manager.original;
    }
    if ([self.delegate respondsToSelector:@selector(photoViewController:didDoneAllList:photos:videos:original:)]) {
        [self.delegate photoViewController:self
                                didDoneAllList:allList
                                        photos:photoList
                                        videos:videoList
                                      original:isOriginal];
    }
    if (self.doneBlock) {
        self.doneBlock(allList, photoList, videoList, isOriginal, self, self.manager);
    } 
}

#pragma mark - PHPhotoLibraryChangeObserver
//- (void)photoLibraryDidChange:(PHChange *)changeInstance {
//    PHFetchResultChangeDetails *collectionChanges = [changeInstance changeDetailsForFetchResult:self.albumModel.assetResult];
//    if (collectionChanges) {
//        if ([collectionChanges hasIncrementalChanges]) {
//            if (collectionChanges.removedObjects.count > 0) {
//
//            }
//        }
//    }
//}
#pragma mark - < 懒加载 >
- (UILabel *)authorizationLb {
    if (!_authorizationLb) {
        _authorizationLb = [[UILabel alloc] initWithFrame:CGRectMake(0, 200, self.view.hx_w, 100)];
        _authorizationLb.text = [NSBundle hx_localizedStringForKey:@"无法访问照片\n请点击这里前往设置中允许访问照片"];
        _authorizationLb.textAlignment = NSTextAlignmentCenter;
        _authorizationLb.numberOfLines = 0;
        UIColor *authorizationColor = self.manager.configuration.authorizationTipColor;
        _authorizationLb.textColor = [HXPhotoCommon photoCommon].isDark ? [UIColor whiteColor] : authorizationColor;
        _authorizationLb.font = [UIFont systemFontOfSize:15];
        _authorizationLb.userInteractionEnabled = YES;
        [_authorizationLb addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(goSetup)]];
    }
    return _authorizationLb;
}
- (void)goSetup {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}
- (UIView *)albumBgView {
    if (!_albumBgView) {
        _albumBgView = [[UIView alloc] initWithFrame:self.view.bounds];
        _albumBgView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5f];
        [_albumBgView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didAlbumBgViewClick)]];
        _albumBgView.hidden = YES;
    }
    return _albumBgView;
}
- (void)didAlbumBgViewClick {
    if (self.manager.configuration.photoListChangeTitleViewSelected) {
        self.manager.configuration.photoListChangeTitleViewSelected(NO);
    }else {
        [self.albumTitleView deSelect];
    }
}
- (HXAlbumlistView *)albumView {
    if (!_albumView) {
        _albumView = [[HXAlbumlistView alloc] initWithManager:self.manager];
        HXWeakSelf
        _albumView.didSelectRowBlock = ^(HXAlbumModel *model) {
            if (weakSelf.manager.configuration.photoListChangeTitleViewSelected) {
                weakSelf.manager.configuration.photoListChangeTitleViewSelected(NO);
                [weakSelf albumTitleViewDidAction:NO];
            }else {
                [weakSelf.albumTitleView deSelect];
            }
            if (weakSelf.albumModel == model ||
                [weakSelf.albumModel.localIdentifier isEqualToString:model.localIdentifier]) {
                return;
            }
            weakSelf.albumModel = model;
            if (weakSelf.manager.configuration.updatePhotoListTitle) {
                weakSelf.manager.configuration.updatePhotoListTitle(model.albumName);
            }else {
                weakSelf.albumTitleView.model = model;
            }
            [weakSelf.view hx_showLoadingHUDText:nil];
            weakSelf.collectionViewReloadCompletion = NO;
            [weakSelf startGetAllPhotoModel];
        };
    }
    return _albumView;
}
- (HXAlbumTitleView *)albumTitleView {
    if (!_albumTitleView) {
        _albumTitleView = [[HXAlbumTitleView alloc] initWithManager:self.manager];
        HXWeakSelf
        _albumTitleView.didTitleViewBlock = ^(BOOL selected) {
            [weakSelf albumTitleViewDidAction:selected];
        };
    }
    return _albumTitleView;
}
- (void)albumTitleViewDidAction:(BOOL)selected {
    if (!self.allArray.count) {
        return;
    }
    if (selected) {
        if (!self.firstDidAlbumTitleView) {
            [self.albumView refreshCamearCount];
            self.firstDidAlbumTitleView = YES;
        }
        self.albumBgView.hidden = NO;
        self.albumBgView.alpha = 0;
        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        CGFloat navBarHeight = hxNavigationBarHeight;
        if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
            navBarHeight = hxNavigationBarHeight;
        }else if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft){
            if ([UIApplication sharedApplication].statusBarHidden) {
                navBarHeight = self.navigationController.navigationBar.hx_h;
            }else {
                navBarHeight = self.navigationController.navigationBar.hx_h + 20;
            }
        }
        [self.albumView selectCellScrollToCenter];
        if (self.manager.configuration.singleSelected) {
            [UIView animateWithDuration:0.1 delay:0.15 options:0 animations:^{
                self.albumView.alpha = 1;
            } completion:nil];
        }
        [UIView animateWithDuration:0.25 animations:^{
            self.albumBgView.alpha = 1;
            self.albumView.hx_y = navBarHeight;
        }];
    }else {
        if (self.manager.configuration.singleSelected) {
            [UIView animateWithDuration:0.1 animations:^{
                self.albumView.alpha = 0;
            }];
        }
        [UIView animateWithDuration:0.25 animations:^{
            self.albumBgView.alpha = 0;
            self.albumView.hx_y = -CGRectGetMaxY(self.albumView.frame);
        } completion:^(BOOL finished) {
            if (!selected) {
                self.albumBgView.hidden = YES;
            }
        }];
    }
}
- (HXPhotoBottomView *)bottomView {
    if (!_bottomView) {
        _bottomView = [[HXPhotoBottomView alloc] initWithFrame:CGRectMake(0, self.view.hx_h - 50 - hxBottomMargin, self.view.hx_w, 50 + hxBottomMargin)];
        _bottomView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _bottomView.manager = self.manager;
        _bottomView.delegate = self;
    }
    return _bottomView;
}
- (UICollectionView *)collectionView {
    if (!_collectionView) {
        CGFloat collectionHeight = self.view.hx_h;
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, self.view.hx_w, collectionHeight) collectionViewLayout:self.flowLayout];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _collectionView.alwaysBounceVertical = YES;
        [_collectionView registerClass:[HXPhotoViewCell class] forCellWithReuseIdentifier:@"HXPhotoViewCellID"];
        [_collectionView registerClass:[HXPhotoCameraViewCell class] forCellWithReuseIdentifier:@"HXPhotoCameraViewCellId"];
//        [_collectionView registerClass:[HXPhotoViewSectionHeaderView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"sectionHeaderId"];
        [_collectionView registerClass:[HXPhotoViewSectionFooterView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"sectionFooterId"];
        
#ifdef __IPHONE_11_0
        if (@available(iOS 11.0, *)) {
//            if ([self hx_navigationBarWhetherSetupBackground]) {
//                self.navigationController.navigationBar.translucent = YES;
//            }
            _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
#else
        if ((NO)) {
#endif
        } else {
//            if ([self hx_navigationBarWhetherSetupBackground]) {
//                self.navigationController.navigationBar.translucent = YES;
//            }
            self.automaticallyAdjustsScrollViewInsets = NO;
        }
    }
    return _collectionView;
}
- (UICollectionViewFlowLayout *)flowLayout {
    if (!_flowLayout) {
        _flowLayout = [[UICollectionViewFlowLayout alloc] init];
        _flowLayout.minimumLineSpacing = 6;
        _flowLayout.minimumInteritemSpacing = 6;
//        _flowLayout.sectionInset = UIEdgeInsetsMake(0.5, 0, 0.5, 0);
    }
    return _flowLayout;
}
@end
@interface HXPhotoCameraViewCell ()
@property (strong, nonatomic) UIButton *cameraBtn;
@property (strong, nonatomic) HXCustomCameraController *cameraController;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (strong, nonatomic) UIVisualEffectView *effectView;
@property (strong, nonatomic) UIView *previewView;
@property (strong, nonatomic) UIImageView *tempCameraView;
@end
    
@implementation HXPhotoCameraViewCell
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            if ([HXPhotoCommon photoCommon].isDark) {
                self.cameraBtn.selected = YES;
            }else {
                self.cameraBtn.selected = self.startSession;
            }
        }
    }
#endif
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}
- (void)setupUI  {
    self.startSession = NO;
    [self.contentView addSubview:self.previewView];
    [self.contentView addSubview:self.cameraBtn];
    if ([HXPhotoCommon photoCommon].isDark) {
        self.cameraBtn.selected = YES;
    }
}
- (void)setCameraImage:(UIImage *)cameraImage {
    _cameraImage = cameraImage;
    if (self.startSession) return;
    if (![UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeCamera]) {
        return;
    }
    if ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] != AVAuthorizationStatusAuthorized) {
        return;
    }
    if (cameraImage) {
        self.tempCameraView.image = cameraImage;
        [self.previewView addSubview:self.tempCameraView];
        [self.previewView addSubview:self.effectView];
        self.cameraSelected = YES;
        self.cameraBtn.selected = YES;
    }
}

- (void)starRunning {
    if (![UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeCamera]) {
        return;
    }
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus != AVAuthorizationStatusAuthorized) {
        return;
    }
    if (self.startSession) {
        return;
    }
    self.startSession = YES;
    HXWeakSelf
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (granted) {
            [weakSelf initSession];
        }
    }];
}
- (void)initSession {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.cameraController initSeesion];
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.cameraController.captureSession];
        HXWeakSelf
        [self.cameraController setupPreviewLayer:self.previewLayer startSessionCompletion:^(BOOL success) {
            if (!weakSelf) {
                return;
            }
            if (success) {
                [weakSelf.cameraController.captureSession startRunning];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.previewView.layer insertSublayer:weakSelf.previewLayer atIndex:0];
                    weakSelf.previewLayer.frame = weakSelf.bounds;
                    weakSelf.cameraBtn.selected = YES;
                    if (weakSelf.tempCameraView.image) {
                        if (weakSelf.cameraSelected) {
                            [UIView animateWithDuration:0.25 animations:^{
                                weakSelf.tempCameraView.alpha = 0;
                                weakSelf.effectView.effect = nil;
                            } completion:^(BOOL finished) {
                                [weakSelf.tempCameraView removeFromSuperview];
                                [weakSelf.effectView removeFromSuperview];
                            }];
                        }
                    }
                });
            }
        }];
    });
}
- (void)stopRunning {
    if (![UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeCamera]) {
        return;
    }
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus != AVAuthorizationStatusAuthorized) {
        return;
    }
    if (!_cameraController) {
        return;
    }
    [self.cameraController stopSession];
}
    
- (void)setModel:(HXPhotoModel *)model {
    _model = model;
    if (!model.thumbPhoto) {
        model.thumbPhoto = [UIImage hx_imageNamed:model.cameraNormalImageNamed];
    }
    if (!model.previewPhoto) {
        model.previewPhoto = [UIImage hx_imageNamed:model.cameraPreviewImageNamed];
    }
    [self.cameraBtn setImage:model.thumbPhoto forState:UIControlStateNormal];
    [self.cameraBtn setImage:model.previewPhoto forState:UIControlStateSelected];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.cameraBtn.frame = self.bounds;
    self.previewView.frame = self.bounds;
//    self.previewLayer.frame = self.bounds;
    self.effectView.frame = self.bounds;
    self.tempCameraView.frame = self.bounds;
}
- (void)willRemoveSubview:(UIView *)subview {
    [super willRemoveSubview:subview];
    [subview.layer removeAllAnimations];
}
- (void)dealloc {
    [self stopRunning];
}
- (UIButton *)cameraBtn {
    if (!_cameraBtn) {
        _cameraBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _cameraBtn.userInteractionEnabled = NO;
    }
    return _cameraBtn;
}
- (UIVisualEffectView *)effectView {
    if (!_effectView) {
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        _effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
    }
    return _effectView;
}
- (UIView *)previewView {
    if (!_previewView) {
        _previewView = [[UIView alloc] init];
    }
    return _previewView;
}
- (HXCustomCameraController *)cameraController {
    if (!_cameraController) {
        _cameraController = [[HXCustomCameraController alloc] init];
    }
    return _cameraController;
}
- (UIImageView *)tempCameraView {
    if (!_tempCameraView) {
        _tempCameraView = [[UIImageView alloc] init];
        _tempCameraView.contentMode = UIViewContentModeScaleAspectFill;
        _tempCameraView.clipsToBounds = YES;
    }
    return _tempCameraView;
}
@end
@interface HXPhotoViewCell ()
@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UIView *maskView;
@property (copy, nonatomic) NSString *localIdentifier;
@property (assign, nonatomic) PHImageRequestID requestID;
@property (assign, nonatomic) PHImageRequestID iCloudRequestID;
@property (strong, nonatomic) UILabel *stateLb;
@property (strong, nonatomic) CAGradientLayer *bottomMaskLayer;
@property (strong, nonatomic) UIImageView *iCloudIcon;
@property (strong, nonatomic) CALayer *iCloudMaskLayer;
@property (strong, nonatomic) HXCircleProgressView *progressView;
@property (strong, nonatomic) CALayer *videoMaskLayer;
@property (strong, nonatomic) UIView *highlightMaskView;
@property (strong, nonatomic) UIImageView *editTipIcon;
@property (strong, nonatomic) UIImageView *videoIcon;
@end

@implementation HXPhotoViewCell
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
//            self.selectMaskLayer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5].CGColor;

            UIColor *cellSelectedTitleColor;
            UIColor *cellSelectedBgColor;
            if ([HXPhotoCommon photoCommon].isDark) {
                cellSelectedTitleColor = self.darkSelectedTitleColor;
                cellSelectedBgColor = self.darkSelectBgColor;
            }else {
                cellSelectedTitleColor = self.selectedTitleColor;
                cellSelectedBgColor = self.selectBgColor;
            }

            if ([cellSelectedBgColor isEqual:[UIColor whiteColor]] && !cellSelectedTitleColor) {
                [self.selectBtn setTitleColor:[UIColor blackColor] forState:UIControlStateSelected];
            }else {
                [self.selectBtn setTitleColor:cellSelectedTitleColor forState:UIControlStateSelected];
            }
//            self.selectBtn.tintColor = cellSelectedBgColor;
        }
    }
#endif
}
- (void)willRemoveSubview:(UIView *)subview {
    [super willRemoveSubview:subview];
    [subview.layer removeAllAnimations];
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}
- (void)setupUI {
    [self.contentView addSubview:self.imageView];
    [self.contentView addSubview:self.maskView];
    [self.contentView addSubview:self.highlightMaskView];
    [self.contentView addSubview:self.progressView];
}
- (void)bottomViewPrepareAnimation {
    [self.maskView.layer removeAllAnimations];
    self.maskView.alpha = 0;
}
- (void)bottomViewStartAnimation {
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.maskView.alpha = 1;
    } completion:nil];
}
- (void)setSingleSelected:(BOOL)singleSelected {
    _singleSelected = singleSelected;
    if (singleSelected) {
        if (self.selectBtn.superview) {
            [self.selectBtn removeFromSuperview];
        }
    }
}
- (void)resetNetworkImage {
    if (self.model.networkPhotoUrl &&
        self.model.type == HXPhotoModelMediaTypeCameraPhoto) {
        self.model.loadOriginalImage = YES;
        self.model.previewViewSize = CGSizeZero;
        self.model.endImageSize = CGSizeZero;
        HXWeakSelf
        [self.imageView hx_setImageWithModel:self.model original:YES progress:nil completed:^(UIImage *image, NSError *error, HXPhotoModel *model) {
            if (weakSelf.model == model) {
                if (image.images.count) {
                    weakSelf.imageView.image = nil;
                    weakSelf.imageView.image = image.images.firstObject;
                }else {
                    weakSelf.imageView.image = image;
                }
            }
        }];
    }
}
- (void)setModel:(HXPhotoModel *)model clearImage:(BOOL)clearImage {
    _model = model;
    if (clearImage) {
        self.imageView.image = nil;
    }
    self.maskView.hidden = YES;
}
- (void)setModelDataWithHighQuality:(BOOL)highQuality completion:(void (^)(HXPhotoViewCell *))completion {
    HXPhotoModel *model = self.model;
    self.videoIcon.hidden = YES;
    self.editTipIcon.hidden = model.photoEdit ? NO : YES;
    self.progressView.hidden = YES;
    self.progressView.progress = 0;
    self.maskView.hidden = !self.imageView.image;
    self.localIdentifier = model.asset.localIdentifier;
    if (model.photoEdit) {
        self.imageView.image = model.photoEdit.editPreviewImage;
        self.maskView.hidden = NO;
        if (completion) {
            completion(self);
        }
        self.requestID = 0;
    }else {
        HXWeakSelf
        if (model.type == HXPhotoModelMediaTypeCamera ||
            model.type == HXPhotoModelMediaTypeCameraPhoto ||
            model.type == HXPhotoModelMediaTypeCameraVideo) {
            if (model.thumbPhoto.images.count) {
                self.imageView.image = nil;
                self.imageView.image = model.thumbPhoto.images.firstObject;
            }else {
                self.imageView.image = model.thumbPhoto;
            }
            if (model.networkPhotoUrl) {
                self.progressView.hidden = model.downloadComplete;
                CGFloat progress = (CGFloat)model.receivedSize / model.expectedSize;
                self.progressView.progress = progress;
                if (model.downloadComplete && !model.downloadError) {
                    self.maskView.hidden = NO;
                    if (model.previewPhoto.images.count) {
                        self.imageView.image = nil;
                        self.imageView.image = model.previewPhoto.images.firstObject;
                    }else {
                        self.imageView.image = model.previewPhoto;
                    }
                    if (completion) {
                        completion(self);
                    }
                }else {
                    [self.imageView hx_setImageWithModel:model original:NO progress:^(CGFloat progress, HXPhotoModel *model) {
                        if (weakSelf.model == model) {
                            weakSelf.progressView.progress = progress;
                        }
                    } completed:^(UIImage *image, NSError *error, HXPhotoModel *model) {
                        if (weakSelf.model == model) {
                            if (error != nil) {
                                [weakSelf.progressView showError];
                            }else {
                                if (image) {
                                    weakSelf.maskView.hidden = NO;
                                    if (image.images.count) {
                                        weakSelf.imageView.image = nil;
                                        weakSelf.imageView.image = image.images.firstObject;
                                    }else {
                                        weakSelf.imageView.image = image;
                                    }
                                    weakSelf.progressView.progress = 1;
                                    weakSelf.progressView.hidden = YES;
                                }
                            }
                        }
                        if (completion) {
                            completion(weakSelf);
                        }
                    }];
                }
            }else {
                self.maskView.hidden = NO;
                if (completion) {
                    completion(self);
                }
            }
            self.requestID = 0;
        }else {
            int32_t imageRequestID;
            if (highQuality) {
                imageRequestID = [self.model highQualityRequestThumbImageWithSize:[HXPhotoCommon photoCommon].requestSize completion:^(UIImage * _Nullable image, HXPhotoModel * _Nullable model, NSDictionary * _Nullable info) {
                    if ([[info objectForKey:PHImageCancelledKey] boolValue]) {
                        return;
                    }
                    if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                        weakSelf.maskView.hidden = NO;
                        weakSelf.imageView.image = image;
                    }
                    BOOL isDegraded = [[info objectForKey:PHImageResultIsDegradedKey] boolValue];
                    if (!isDegraded) {
                        weakSelf.requestID = 0;
                    }
                    if (completion) {
                        completion(weakSelf);
                    }
                }];
            }else {
                imageRequestID = [weakSelf.model requestThumbImageCompletion:^(UIImage *image, HXPhotoModel *model, NSDictionary *info) {
                    if ([[info objectForKey:PHImageCancelledKey] boolValue]) {
                        return;
                    }
                    if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                        weakSelf.maskView.hidden = NO;
                        weakSelf.imageView.image = image;
                    }
                    BOOL isDegraded = [[info objectForKey:PHImageResultIsDegradedKey] boolValue];
                    if (!isDegraded) {
                        weakSelf.requestID = 0;
                    }
                    if (completion) {
                        completion(weakSelf);
                    }
                }];
            }
            if (imageRequestID && self.requestID && imageRequestID != self.requestID) {
                [[PHImageManager defaultManager] cancelImageRequest:self.requestID];
            }
            self.requestID = imageRequestID;
        }
    }
    if (model.type == HXPhotoModelMediaTypePhotoGif && !model.photoEdit) {
        self.stateLb.text = @"GIF";
        self.stateLb.hidden = NO;
        self.bottomMaskLayer.hidden = NO;
    }else if (model.type == HXPhotoModelMediaTypeLivePhoto && !model.photoEdit) {
        self.stateLb.text = @"Live";
        self.stateLb.hidden = NO;
        self.bottomMaskLayer.hidden = NO;
    }else {
        if (model.subType == HXPhotoModelMediaSubTypeVideo) {
            self.stateLb.text = model.videoTime;
            self.stateLb.hidden = NO;
            self.videoIcon.hidden = NO;
            self.bottomMaskLayer.hidden = NO;
        }else {
            if ((model.cameraPhotoType == HXPhotoModelMediaTypeCameraPhotoTypeNetWorkGif ||
                 model.cameraPhotoType == HXPhotoModelMediaTypeCameraPhotoTypeLocalGif) && !model.photoEdit) {
                self.stateLb.text = @"GIF";
                self.stateLb.hidden = NO;
                self.bottomMaskLayer.hidden = NO;
            }else if ((model.cameraPhotoType == HXPhotoModelMediaTypeCameraPhotoTypeLocalLivePhoto ||
                       model.cameraPhotoType == HXPhotoModelMediaTypeCameraPhotoTypeNetWorkLivePhoto) && !model.photoEdit) {
                self.stateLb.text = @"Live";
                self.stateLb.hidden = NO;
                self.bottomMaskLayer.hidden = NO;
            }else {
                self.stateLb.hidden = YES;
                if (model.photoEdit) {
                    self.bottomMaskLayer.hidden = NO;
                }else {
                    self.bottomMaskLayer.hidden = YES;
                }
            }
        }
    }
    self.selectMaskLayer.hidden = !model.selected;
//    self.selectBtn.selected = model.selected;
//    [self.selectBtn setImage:[UIImage imageNamed:@"circleSelected"] forState:UIControlStateSelected];
//    [self.selectBtn setTitle:model.selectIndexStr forState:UIControlStateSelected];
    
    self.iCloudIcon.hidden = !model.isICloud;
    self.iCloudMaskLayer.hidden = !model.isICloud;
    
    // 当前是否需要隐藏选择按钮
    if (model.needHideSelectBtn) {
        self.selectBtn.hidden = YES;
        self.selectBtn.userInteractionEnabled = NO;
    }else {
        self.selectBtn.hidden = model.isICloud;
        self.selectBtn.userInteractionEnabled = !model.isICloud;
    }
    
    if (model.isICloud) {
        self.videoMaskLayer.hidden = YES;
        self.userInteractionEnabled = YES;
    }else {
        // 当前是否需要隐藏选择按钮
        if (model.needHideSelectBtn) {
            // 当前视频是否不可选
            self.videoMaskLayer.hidden = !model.videoUnableSelect;
        }else {
            self.videoMaskLayer.hidden = YES;
            self.userInteractionEnabled = YES;
        }
    }
    
    if (model.iCloudDownloading) {
        if (model.isICloud) {
            self.progressView.hidden = NO;
            self.highlightMaskView.hidden = NO;
            self.progressView.progress = model.iCloudProgress;
            [self startRequestICloudAsset];
        }else {
            model.iCloudDownloading = NO;
            self.progressView.hidden = YES;
            self.highlightMaskView.hidden = YES;
        }
    }else {
        self.highlightMaskView.hidden = YES;
    }
}
- (void)setSelectBgColor:(UIColor *)selectBgColor {
    _selectBgColor = selectBgColor;
    if ([HXPhotoCommon photoCommon].isDark) {
        selectBgColor = self.darkSelectBgColor;
    }
//    self.selectBtn.tintColor = selectBgColor;
    if ([selectBgColor isEqual:[UIColor whiteColor]] && !self.selectedTitleColor) {
        [self.selectBtn setTitleColor:[UIColor blackColor] forState:UIControlStateSelected];
    }
}
- (void)setSelectedTitleColor:(UIColor *)selectedTitleColor {
    _selectedTitleColor = selectedTitleColor;
    if ([HXPhotoCommon photoCommon].isDark) {
        selectedTitleColor = self.darkSelectedTitleColor;
    }
    [self.selectBtn setTitleColor:selectedTitleColor forState:UIControlStateSelected];
}
- (void)startRequestICloudAsset {
    self.progressView.progress = 0;
    self.iCloudIcon.hidden = YES;
    self.iCloudMaskLayer.hidden = YES;
    HXWeakSelf
    if (self.model.type == HXPhotoModelMediaTypeVideo) {
        self.iCloudRequestID = [self.model requestAVAssetStartRequestICloud:^(PHImageRequestID iCloudRequestId, HXPhotoModel *model) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                weakSelf.progressView.hidden = NO;
                weakSelf.highlightMaskView.hidden = NO;
                weakSelf.iCloudRequestID = iCloudRequestId;
            }
        } progressHandler:^(double progress, HXPhotoModel *model) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                weakSelf.progressView.hidden = NO;
                weakSelf.highlightMaskView.hidden = NO;
                weakSelf.progressView.progress = progress;
            }
        } success:^(AVAsset *avAsset, AVAudioMix *audioMix, HXPhotoModel *model, NSDictionary *info) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                weakSelf.model.isICloud = NO;
                weakSelf.progressView.progress = 1;
                weakSelf.highlightMaskView.hidden = YES;
                weakSelf.iCloudRequestID = 0;
                if ([weakSelf.delegate respondsToSelector:@selector(photoViewCellRequestICloudAssetComplete:)]) {
                    [weakSelf.delegate photoViewCellRequestICloudAssetComplete:weakSelf];
                }
            }
        } failed:^(NSDictionary *info, HXPhotoModel *model) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                [weakSelf downloadError:info];
            }
        }];
    }else if (self.model.type == HXPhotoModelMediaTypeLivePhoto){
        self.iCloudRequestID = [self.model requestLivePhotoWithSize:CGSizeMake(self.model.previewViewSize.width * 1.5, self.model.previewViewSize.height * 1.5) startRequestICloud:^(PHImageRequestID iCloudRequestId, HXPhotoModel *model) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                weakSelf.progressView.hidden = NO;
                weakSelf.highlightMaskView.hidden = NO;
                weakSelf.iCloudRequestID = iCloudRequestId;
            }
        } progressHandler:^(double progress, HXPhotoModel *model) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                weakSelf.progressView.hidden = NO;
                weakSelf.highlightMaskView.hidden = NO;
                weakSelf.progressView.progress = progress;
            }
        } success:^(PHLivePhoto *livePhoto, HXPhotoModel *model, NSDictionary *info) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                weakSelf.model.isICloud = NO;
                weakSelf.progressView.progress = 1;
                weakSelf.highlightMaskView.hidden = YES;
                weakSelf.iCloudRequestID = 0;
                if ([weakSelf.delegate respondsToSelector:@selector(photoViewCellRequestICloudAssetComplete:)]) {
                    [weakSelf.delegate photoViewCellRequestICloudAssetComplete:weakSelf];
                }
            }
        } failed:^(NSDictionary *info, HXPhotoModel *model) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                [weakSelf downloadError:info];
            }
        }];
    }else {
        self.iCloudRequestID = [self.model requestImageDataStartRequestICloud:^(PHImageRequestID iCloudRequestId, HXPhotoModel *model) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                weakSelf.progressView.hidden = NO;
                weakSelf.highlightMaskView.hidden = NO;
                weakSelf.iCloudRequestID = iCloudRequestId;
            }
        } progressHandler:^(double progress, HXPhotoModel *model) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                weakSelf.progressView.hidden = NO;
                weakSelf.highlightMaskView.hidden = NO;
                weakSelf.progressView.progress = progress;
            }
        } success:^(NSData *imageData, UIImageOrientation orientation, HXPhotoModel *model, NSDictionary *info) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                weakSelf.model.isICloud = NO;
                weakSelf.highlightMaskView.hidden = YES;
                weakSelf.progressView.progress = 1;
                weakSelf.iCloudRequestID = 0;
                if ([weakSelf.delegate respondsToSelector:@selector(photoViewCellRequestICloudAssetComplete:)]) {
                    [weakSelf.delegate photoViewCellRequestICloudAssetComplete:weakSelf];
                }
            }
        } failed:^(NSDictionary *info, HXPhotoModel *model) {
            if ([weakSelf.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                [weakSelf downloadError:info];
            }
        }];
    }
}
- (void)downloadError:(NSDictionary *)info {
    if (![[info objectForKey:PHImageCancelledKey] boolValue]) {
        [[self hx_viewController].view hx_showImageHUDText:[NSBundle hx_localizedStringForKey:@"下载失败，请重试！"]];
    }
    self.highlightMaskView.hidden = YES;
    self.progressView.hidden = YES;
    self.progressView.progress = 0;
    self.iCloudIcon.hidden = !self.model.isICloud;
    self.iCloudMaskLayer.hidden = !self.model.isICloud;
}
- (void)cancelRequest {
#if HasYYWebImage
//    [self.imageView yy_cancelCurrentImageRequest];
#elif HasYYKit
//    [self.imageView cancelCurrentImageRequest];
#elif HasSDWebImage
//    [self.imageView sd_cancelCurrentAnimationImagesLoad];
#endif
    if (self.requestID) {
        [[PHImageManager defaultManager] cancelImageRequest:self.requestID];
        self.requestID = 0;
    }
    if (self.iCloudRequestID) {
        [[PHImageManager defaultManager] cancelImageRequest:self.iCloudRequestID];
        self.iCloudRequestID = 0;
    }
}
- (void)didSelectClick:(UIButton *)button {
//    if (self.model.type == HXPhotoModelMediaTypeCamera) {
//        return;
//    }
//    if (self.model.isICloud) {
//        return;
//    }
//    if ([self.delegate respondsToSelector:@selector(photoViewCell:didSelectBtn:)]) {
//        [self.delegate photoViewCell:self didSelectBtn:button];
//    }
}
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.highlightMaskView.hidden = !highlighted;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.imageView.frame = self.bounds;
    self.maskView.frame = self.bounds;
    self.stateLb.frame = CGRectMake(0, self.hx_h - 18, self.hx_w - 7, 18);
    self.bottomMaskLayer.frame = CGRectMake(0, self.hx_h - 25, self.hx_w, 27);
    self.selectBtn.hx_x = self.hx_w - self.selectBtn.hx_w - 12;
    self.selectBtn.hx_y = 12;
    self.selectMaskLayer.frame = self.bounds;
    self.iCloudMaskLayer.frame = self.bounds;
    self.iCloudIcon.hx_x = self.hx_w - 3 - self.iCloudIcon.hx_w;
    self.iCloudIcon.hx_y = 3;
    self.progressView.center = CGPointMake(self.hx_w / 2, self.hx_h / 2);
    self.videoMaskLayer.frame = self.bounds;
    self.highlightMaskView.frame = self.bounds;
    self.editTipIcon.hx_x = 7;
    self.editTipIcon.hx_y = self.hx_h - 4 - self.editTipIcon.hx_h;
    self.videoIcon.hx_x = 7;
    self.videoIcon.hx_y = self.hx_h - 4 - self.videoIcon.hx_h;
    self.stateLb.hx_centerY = self.videoIcon.hx_centerY;
}
- (void)dealloc {
    self.delegate = nil;
    self.model.dateCellIsVisible = NO;
}
#pragma mark - < 懒加载 >
- (UIView *)highlightMaskView {
    if (!_highlightMaskView) {
        _highlightMaskView = [[UIView alloc] initWithFrame:self.bounds];
//        _highlightMaskView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5f];
        _highlightMaskView.hidden = YES;
    }
    return _highlightMaskView;
}
- (HXCircleProgressView *)progressView {
    if (!_progressView) {
        _progressView = [[HXCircleProgressView alloc] init];
        _progressView.hidden = YES;
    }
    return _progressView;
}
- (UIImageView *)editTipIcon {
    if (!_editTipIcon) {
        _editTipIcon = [[UIImageView alloc] initWithImage:[UIImage hx_imageNamed:@"hx_photo_edit_show_tip"]];
        _editTipIcon.hx_size = _editTipIcon.image.size;
    }
    return _editTipIcon;
}
- (UIImageView *)videoIcon {
    if (!_videoIcon) {
        _videoIcon = [[UIImageView alloc] initWithImage:[UIImage hx_imageNamed:@"hx_photo_asset_video_icon"]];
        _videoIcon.hx_size = _videoIcon.image.size;
    }
    return _videoIcon;
}
- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
    }
    return _imageView;
}
- (UIView *)maskView {
    if (!_maskView) {
        _maskView = [[UIView alloc] init];
        [_maskView.layer addSublayer:self.bottomMaskLayer];
        [_maskView.layer addSublayer:self.selectMaskLayer];
        [_maskView.layer addSublayer:self.iCloudMaskLayer];
        [_maskView.layer addSublayer:self.videoMaskLayer];
        [_maskView addSubview:self.iCloudIcon];
        [_maskView addSubview:self.stateLb];
        [_maskView addSubview:self.selectBtn];
        [_maskView addSubview:self.editTipIcon];
        [_maskView addSubview:self.videoIcon];
    }
    return _maskView;
}
- (UIImageView *)iCloudIcon {
    if (!_iCloudIcon) {
        _iCloudIcon = [[UIImageView alloc] initWithImage:[UIImage hx_imageNamed:@"hx_yunxiazai"]];
        _iCloudIcon.hx_size = _iCloudIcon.image.size;
    }
    return _iCloudIcon;
}
- (CALayer *)selectMaskLayer {
    if (!_selectMaskLayer) {
        _selectMaskLayer = [CALayer layer];
        _selectMaskLayer.hidden = YES;
//        _selectMaskLayer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5].CGColor;
    }
    return _selectMaskLayer;
}
- (CALayer *)iCloudMaskLayer {
    if (!_iCloudMaskLayer) {
        _iCloudMaskLayer = [CALayer layer];
        _iCloudMaskLayer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3].CGColor;
    }
    return _iCloudMaskLayer;
}
- (CALayer *)videoMaskLayer {
    if (!_videoMaskLayer) {
        _videoMaskLayer = [CALayer layer];
        _videoMaskLayer.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7].CGColor;
    }
    return _videoMaskLayer;
}
- (UILabel *)stateLb {
    if (!_stateLb) {
        _stateLb = [[UILabel alloc] init];
        _stateLb.textColor = [UIColor whiteColor];
        _stateLb.textAlignment = NSTextAlignmentRight;
        _stateLb.font = [UIFont hx_mediumSFUITextOfSize:13];
    }
    return _stateLb;
}
- (CAGradientLayer *)bottomMaskLayer {
    if (!_bottomMaskLayer) {
        _bottomMaskLayer = [CAGradientLayer layer];
        _bottomMaskLayer.colors = @[
                                    (id)[[UIColor blackColor] colorWithAlphaComponent:0].CGColor ,
                                    (id)[[UIColor blackColor] colorWithAlphaComponent:0.15].CGColor ,
                                    (id)[[UIColor blackColor] colorWithAlphaComponent:0.35].CGColor ,
                                    (id)[[UIColor blackColor] colorWithAlphaComponent:0.6].CGColor
                                    ];
        _bottomMaskLayer.startPoint = CGPointMake(0, 0);
        _bottomMaskLayer.endPoint = CGPointMake(0, 1);
        _bottomMaskLayer.locations = @[@(0.15f),@(0.35f),@(0.6f),@(0.9f)];
        _bottomMaskLayer.borderWidth  = 0.0;
    }
    return _bottomMaskLayer;
}
- (UIButton *)selectBtn {
    if (!_selectBtn) {
        _selectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        
        [_selectBtn setImage:[UIImage hx_imageNamed:@"circleNormal"] forState:UIControlStateNormal];
//        [_selectBtn setBackgroundImage:[UIImage hx_imageNamed:@"circleNormal"] forState:UIControlStateNormal];
//        UIImage *bgImage = [[UIImage hx_imageNamed:@"circleNormal"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
//        [_selectBtn setBackgroundImage:bgImage forState:UIControlStateSelected];
        [_selectBtn setImage:[UIImage hx_imageNamed:@"circleSelected"] forState:UIControlStateSelected];

//        [_selectBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        _selectBtn.titleLabel.font = [UIFont hx_mediumPingFangOfSize:16];
        _selectBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
        _selectBtn.hx_size = CGSizeMake(22, 22);// _selectBtn.currentBackgroundImage.size;
        [_selectBtn addTarget:self action:@selector(didSelectClick:) forControlEvents:UIControlEventTouchUpInside];
//        [_selectBtn hx_setEnlargeEdgeWithTop:0 right:0 bottom:15 left:15];
    }
    return _selectBtn;
}
@end

@interface HXPhotoViewSectionHeaderView ()
@property (strong, nonatomic) UILabel *dateLb;
@property (strong, nonatomic) UILabel *subTitleLb;
@property (strong, nonatomic) UIToolbar *bgView;
@end

@implementation HXPhotoViewSectionHeaderView
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self setChangeState:self.changeState];
        }
    }
#endif
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        [self setChangeState:self.changeState];
    }
    return self;
}
- (void)setupUI {
    [self addSubview:self.bgView];
    [self addSubview:self.dateLb];
    [self addSubview:self.subTitleLb];
}
- (void)setChangeState:(BOOL)changeState {
    _changeState = changeState;
    if (self.translucent) {
        self.bgView.translucent = changeState;
    }
    if (self.suspensionBgColor) {
        self.translucent = NO;
    }
    if (changeState) {
//        if (self.translucent) {
            self.bgView.alpha = 1;
//        }
        if (self.suspensionTitleColor) {
            self.dateLb.textColor = self.suspensionTitleColor;
            self.subTitleLb.textColor = self.suspensionTitleColor;
        }
        if (self.suspensionBgColor) {
            self.bgView.barTintColor = self.suspensionBgColor;
        }else {
            self.bgView.barTintColor = nil;
        }
    }else {
        if (!self.translucent) {
            self.bgView.barTintColor = [HXPhotoCommon photoCommon].isDark ? [UIColor blackColor] : [UIColor whiteColor];
        }
//        if (self.translucent) {
            self.bgView.alpha = 0;
//        }
        self.dateLb.textColor = [HXPhotoCommon photoCommon].isDark ? [UIColor whiteColor] : [UIColor blackColor];
        if ([HXPhotoCommon photoCommon].isDark) {
            self.subTitleLb.textColor = [UIColor whiteColor];
        }else {
            self.subTitleLb.textColor = [UIColor colorWithRed:140.f / 255.f green:140.f / 255.f blue:140.f / 255.f alpha:1];
        }
    }
}
- (void)setTranslucent:(BOOL)translucent {
    _translucent = translucent;
    if (!translucent) {
        self.bgView.translucent = YES;
        self.bgView.barTintColor = [HXPhotoCommon photoCommon].isDark ? [UIColor blackColor] : [UIColor whiteColor];
    }
}
- (void)setModel:(HXPhotoDateModel *)model {
    _model = model;
    if (model.location) {
        if (model.hasLocationTitles) {
            [self updateDateData];
        }else {
            self.dateLb.frame = CGRectMake(8, 0, self.hx_w - 16, 50);
            self.dateLb.text = model.dateString;
            self.subTitleLb.hidden = YES;
            HXWeakSelf
            [HXPhotoTools getDateLocationDetailInformationWithModel:model completion:^(CLPlacemark * _Nullable placemark, HXPhotoDateModel *model, NSError * _Nullable error) {
                if (!error) {
                    if (placemark.locality) {
                        NSString *province = placemark.administrativeArea;
                        NSString *city = placemark.locality;
                        NSString *area = placemark.subLocality;
                        NSString *street = placemark.thoroughfare;
                        NSString *subStreet = placemark.subThoroughfare;
                        if (area) {
                            model.locationTitle = [NSString stringWithFormat:@"%@ ﹣ %@",city,area];
                        }else {
                            model.locationTitle = [NSString stringWithFormat:@"%@",city];
                        }
                        if (street) {
                            if (subStreet) {
                                model.locationSubTitle = [NSString stringWithFormat:@"%@・%@%@",model.dateString,street,subStreet];
                            }else {
                                model.locationSubTitle = [NSString stringWithFormat:@"%@・%@",model.dateString,street];
                            }
                        }else if (province) {
                            model.locationSubTitle = [NSString stringWithFormat:@"%@・%@",model.dateString,province];
                        }else {
                            model.locationSubTitle = [NSString stringWithFormat:@"%@・%@",model.dateString,city];
                        }
                    }else {
                        NSString *province = placemark.administrativeArea;
                        model.locationSubTitle = [NSString stringWithFormat:@"%@・%@",model.dateString,province];
                        model.locationTitle = province;
                    }
                    model.locationError = NO;
                }else {
                    model.locationError = YES;
                }
                if (weakSelf.model == model) {
                    weakSelf.model.hasLocationTitles = YES;
                    [weakSelf updateDateData];
                }
            }];
        }
    }else {
        self.dateLb.frame = CGRectMake(8, 0, self.hx_w - 16, 50);
        self.dateLb.text = model.dateString;
        self.subTitleLb.hidden = YES;
    }
}
- (void)updateDateData {
    if (self.model.locationError) {
        self.dateLb.frame = CGRectMake(8, 0, self.hx_w - 16, 50);
        self.subTitleLb.hidden = YES;
        self.dateLb.text = self.model.dateString;
    }else {
        if (self.model.locationSubTitle) {
            self.dateLb.frame = CGRectMake(8, 4, self.hx_w - 16, 30);
            self.subTitleLb.frame = CGRectMake(8, 28, self.hx_w - 16, 20);
            self.subTitleLb.hidden = NO;
            self.subTitleLb.text = self.model.locationSubTitle;
        }else {
            self.dateLb.frame = CGRectMake(8, 0, self.hx_w - 16, 50);
            self.subTitleLb.hidden = YES;
        }
        self.dateLb.text = self.model.locationTitle;
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.bgView.frame = self.bounds;
}
- (UILabel *)dateLb {
    if (!_dateLb) {
        _dateLb = [[UILabel alloc] init];
        _dateLb.font = [UIFont hx_boldPingFangOfSize:16];
    }
    return _dateLb;
}
- (UIToolbar *)bgView {
    if (!_bgView) {
        _bgView = [[UIToolbar alloc] init];
        _bgView.translucent = NO;
        _bgView.clipsToBounds = YES;
    }
    return _bgView;
}
- (UILabel *)subTitleLb {
    if (!_subTitleLb) {
        _subTitleLb = [[UILabel alloc] init];
        _subTitleLb.font = [UIFont hx_regularPingFangOfSize:12];
    }
    return _subTitleLb;
}
@end

@interface HXPhotoViewSectionFooterView ()
@property (strong, nonatomic) UILabel *titleLb;
@end

@implementation HXPhotoViewSectionFooterView
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            if ([HXPhotoCommon photoCommon].isDark) {
                self.backgroundColor = [UIColor colorWithRed:0.075 green:0.075 blue:0.075 alpha:1];
            }else {
                self.backgroundColor = self.bgColor;
            }
            [self setVideoCount:self.videoCount];
        }
    }
#endif
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}
- (void)setupUI {
    if ([HXPhotoCommon photoCommon].isDark) {
        self.backgroundColor = [UIColor colorWithRed:0.075 green:0.075 blue:0.075 alpha:1];
    }else {
        self.backgroundColor = self.bgColor;
    }
    [self addSubview:self.titleLb];
}
- (void)setVideoCount:(NSInteger)videoCount {
    _videoCount = videoCount;
    UIColor *textColor = [HXPhotoCommon photoCommon].isDark ? [UIColor whiteColor] : self.textColor;
    NSDictionary *dict = @{NSFontAttributeName : [UIFont hx_mediumSFUITextOfSize:15] ,
                           NSForegroundColorAttributeName : textColor
                           };
    
    NSAttributedString *photoCountStr = [[NSAttributedString alloc] initWithString:[@(self.photoCount).stringValue hx_countStrBecomeComma] attributes:dict];
    
    NSAttributedString *videoCountStr = [[NSAttributedString alloc] initWithString:[@(videoCount).stringValue hx_countStrBecomeComma] attributes:dict];
    
    
    if (self.photoCount > 0 && videoCount > 0) {
        NSString *photoStr;
        if (self.photoCount > 1) {
            photoStr = @"Photos";
        }else {
            photoStr = @"Photo";
        }
        NSString *videoStr;
        if (videoCount > 1) {
            videoStr = @"Videos";
        }else {
            videoStr = @"Video";
        }
        NSMutableAttributedString *atbStr = [[NSMutableAttributedString alloc] init];
        NSAttributedString *photoAtbStr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@、",[NSBundle hx_localizedStringForKey:photoStr]] attributes:dict];
        [atbStr appendAttributedString:photoCountStr];
        [atbStr appendAttributedString:photoAtbStr];
        
        NSAttributedString *videoAtbStr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@",[NSBundle hx_localizedStringForKey:videoStr]] attributes:dict];
        [atbStr appendAttributedString:videoCountStr];
        [atbStr appendAttributedString:videoAtbStr];

        self.titleLb.attributedText = atbStr;
    }else if (self.photoCount > 0) {
        NSString *photoStr;
        if (self.photoCount > 1) {
            photoStr = @"Photos";
        }else {
            photoStr = @"Photo";
        }
        NSMutableAttributedString *atbStr = [[NSMutableAttributedString alloc] init];
        NSAttributedString *photoAtbStr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@",[NSBundle hx_localizedStringForKey:photoStr]] attributes:dict];
        [atbStr appendAttributedString:photoCountStr];
        [atbStr appendAttributedString:photoAtbStr];
        
        
        self.titleLb.attributedText = atbStr;
    }else {
        NSString *videoStr;
        if (videoCount > 1) {
            videoStr = @"Videos";
        }else {
            videoStr = @"Video";
        }
        NSMutableAttributedString *atbStr = [[NSMutableAttributedString alloc] init];
        
        NSAttributedString *videoAtbStr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@",[NSBundle hx_localizedStringForKey:videoStr]] attributes:dict];
        [atbStr appendAttributedString:videoCountStr];
        [atbStr appendAttributedString:videoAtbStr];
        
        self.titleLb.attributedText = atbStr;
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.titleLb.frame = CGRectMake(0, 0, self.hx_w, 50);
}
- (UILabel *)titleLb {
    if (!_titleLb) {
        _titleLb = [[UILabel alloc] init];
        _titleLb.textAlignment = NSTextAlignmentCenter;
    }
    return _titleLb;
}
@end

@interface HXPhotoBottomView ()
@property (strong, nonatomic) UIButton *previewBtn;
@property (strong, nonatomic) UIButton *editBtn;
@property (strong, nonatomic) UIActivityIndicatorView *loadingView;
@property (strong, nonatomic) UIColor *barTintColor;
@end

@implementation HXPhotoBottomView
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self setManager:self.manager];
            [self setSelectCount:self.selectCount];
        }
    }
#endif
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}
- (void)setupUI {
    [self addSubview:self.bgView];
//    [self addSubview:self.previewBtn];
    [self addSubview:self.originalBtn];
    [self addSubview:self.doneBtn];
    [self addSubview:self.editBtn];
    [self changeDoneBtnFrame];
}
- (void)setManager:(HXPhotoManager *)manager {
    _manager = manager;
    self.bgView.translucent = manager.configuration.bottomViewTranslucent;
    self.barTintColor = manager.configuration.bottomViewBgColor;
    self.bgView.barStyle = manager.configuration.bottomViewBarStyle;
    self.originalBtn.hidden = self.manager.configuration.hideOriginalBtn;
    if (manager.type == HXPhotoManagerSelectedTypePhoto) {
        self.editBtn.hidden = !manager.configuration.photoCanEdit;
    }else if (manager.type == HXPhotoManagerSelectedTypeVideo) {
        self.editBtn.hidden = !manager.configuration.videoCanEdit;
    }else {
        if (!manager.configuration.videoCanEdit && !manager.configuration.photoCanEdit) {
            self.editBtn.hidden = YES;
        }
    }
    self.originalBtn.selected = self.manager.original;
    
    UIColor *themeColor;
    UIColor *selectedTitleColor;
    UIColor *originalBtnImageTintColor;
    if ([HXPhotoCommon photoCommon].isDark) {
        themeColor = [UIColor whiteColor];
        originalBtnImageTintColor = themeColor;
        selectedTitleColor = [UIColor whiteColor];
        self.bgView.barTintColor = [UIColor blackColor];
    }else {
        self.bgView.barTintColor = self.barTintColor;
        themeColor = self.manager.configuration.themeColor;
        if (self.manager.configuration.originalBtnImageTintColor) {
            originalBtnImageTintColor = self.manager.configuration.originalBtnImageTintColor;
        }else {
            originalBtnImageTintColor = themeColor;
        }
        if (self.manager.configuration.bottomDoneBtnTitleColor) {
            selectedTitleColor = self.manager.configuration.bottomDoneBtnTitleColor;
        }else {
            selectedTitleColor = self.manager.configuration.selectedTitleColor;
        }
    }
    
    [self.previewBtn setTitleColor:themeColor forState:UIControlStateNormal];
    [self.previewBtn setTitleColor:[themeColor colorWithAlphaComponent:0.5] forState:UIControlStateDisabled];
    
    [self.originalBtn setTitleColor:themeColor forState:UIControlStateNormal];
    [self.originalBtn setTitleColor:[themeColor colorWithAlphaComponent:0.5] forState:UIControlStateDisabled];
    
    UIImageRenderingMode rederingMode = self.manager.configuration.changeOriginalTinColor ? UIImageRenderingModeAlwaysTemplate : UIImageRenderingModeAlwaysOriginal;
    UIImage *originalNormalImage = [[UIImage hx_imageNamed:self.manager.configuration.originalNormalImageName] imageWithRenderingMode:rederingMode];
    UIImage *originalSelectedImage = [[UIImage hx_imageNamed:self.manager.configuration.originalSelectedImageName] imageWithRenderingMode:rederingMode];
    [self.originalBtn setImage:originalNormalImage forState:UIControlStateNormal];
    [self.originalBtn setImage:originalSelectedImage forState:UIControlStateSelected];
    self.originalBtn.imageView.tintColor = originalBtnImageTintColor;
    
    [self.editBtn setTitleColor:themeColor forState:UIControlStateNormal];
    [self.editBtn setTitleColor:[themeColor colorWithAlphaComponent:0.5] forState:UIControlStateDisabled];
    
    if ([themeColor isEqual:[UIColor whiteColor]]) {
        [self.doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
//        [self.doneBtn setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.3] forState:UIControlStateDisabled];
    }
    if (selectedTitleColor) {
        [self.doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
//        [self.doneBtn setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.3] forState:UIControlStateDisabled];
    }
    if (self.manager.configuration.showOriginalBytesLoading) {
        self.loadingView.color = themeColor;
    }
}
- (void)setSelectCount:(NSInteger)selectCount {
    _selectCount = selectCount;
    if (selectCount <= 0) {
        self.previewBtn.enabled = NO;
        self.doneBtn.enabled = NO;
        [self.doneBtn setTitle:[NSBundle hx_localizedStringForKey:@"完成"] forState:UIControlStateNormal];
        self.doneBtn.titleLabel.font = [UIFont fontWithName:@"PingFangSC-Medium" size:16];
    }else {

        self.previewBtn.enabled = YES;
        self.doneBtn.enabled = YES;
        if (self.manager.configuration.doneBtnShowDetail) {
            if (!self.manager.configuration.selectTogether) {
                if (self.manager.selectedPhotoCount > 0) {
                    NSInteger maxCount = self.manager.configuration.photoMaxNum > 0 ? self.manager.configuration.photoMaxNum : self.manager.configuration.maxNum;
//                    [self.doneBtn setTitle:[NSString stringWithFormat:@"%@(%ld/%ld)",[NSBundle hx_localizedStringForKey:@"完成"],(long)selectCount,(long)maxCount] forState:UIControlStateNormal];
                }else {
                    NSInteger maxCount = self.manager.configuration.videoMaxNum > 0 ? self.manager.configuration.videoMaxNum : self.manager.configuration.maxNum;
//                    [self.doneBtn setTitle:[NSString stringWithFormat:@"%@(%ld/%ld)",[NSBundle hx_localizedStringForKey:@"完成"],(long)selectCount,(long)maxCount] forState:UIControlStateNormal];
                }
            }else {
//                [self.doneBtn setTitle:[NSString stringWithFormat:@"%@(%ld/%lu)",[NSBundle hx_localizedStringForKey:@"完成"],(long)selectCount,(unsigned long)self.manager.configuration.maxNum] forState:UIControlStateNormal];
            }
        }else {
//            [self.doneBtn setTitle:[NSString stringWithFormat:@"%@(%ld)",[NSBundle hx_localizedStringForKey:@"完成"],(long)selectCount] forState:UIControlStateNormal];
        }
    }
    UIColor *themeColor = self.manager.configuration.bottomDoneBtnBgColor ?: self.manager.configuration.themeColor;
    UIColor *doneBtnDarkBgColor = self.manager.configuration.bottomDoneBtnDarkBgColor ?: [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1];
    UIColor *doneBtnBgColor = [UIColor colorWithRed:123/255.0 green:196/255.0 blue:55/255.0 alpha:1];//[HXPhotoCommon photoCommon].isDark ? doneBtnDarkBgColor : themeColor;
    UIColor *doneBtnEnabledBgColor = [UIColor colorWithRed:214/255.0 green:214/255.0 blue:214/255.0 alpha:1];// self.manager.configuration.bottomDoneBtnEnabledBgColor ?: [doneBtnBgColor colorWithAlphaComponent:0.5];
    self.doneBtn.backgroundColor = self.doneBtn.enabled ? doneBtnBgColor : doneBtnEnabledBgColor;
    
    if (!self.manager.configuration.selectTogether) {
        if (self.manager.selectedPhotoArray.count) {
            self.editBtn.enabled = self.manager.configuration.photoCanEdit;
        }else if (self.manager.selectedVideoArray.count) {
            self.editBtn.enabled = self.manager.configuration.videoCanEdit;
        }else {
            self.editBtn.enabled = NO;
        }
    }else {
        if (self.manager.selectedArray.count) {
            HXPhotoModel *model = self.manager.selectedArray.firstObject;
            if (model.subType == HXPhotoModelMediaSubTypePhoto) {
                self.editBtn.enabled = self.manager.configuration.photoCanEdit;
            }else {
                self.editBtn.enabled = self.manager.configuration.videoCanEdit;
            }
        }else {
            self.editBtn.enabled = NO;
        }
    }
    [self changeDoneBtnFrame];
    [self requestPhotosBytes];
}
- (void)requestPhotosBytes {
    if (!self.manager.configuration.showOriginalBytes) { 
        return;
    }
    if (self.originalBtn.selected) {
        if (self.manager.configuration.showOriginalBytesLoading) {
            [self resetOriginalBtn];
            [self updateLoadingViewWithHidden:NO];
        }
        HXWeakSelf
        [self.manager requestPhotosBytesWithCompletion:^(NSString *totalBytes, NSUInteger totalDataLengths) {
            if (weakSelf.manager.configuration.showOriginalBytesLoading) {
                [weakSelf updateLoadingViewWithHidden:YES];
            }
            if (totalDataLengths > 0) {
                [weakSelf.originalBtn setTitle:[NSString stringWithFormat:@"%@(%@)",[NSBundle hx_localizedStringForKey:@"原图"], totalBytes] forState:UIControlStateNormal];
            }else {
                [weakSelf.originalBtn setTitle:[NSBundle hx_localizedStringForKey:@"原图"] forState:UIControlStateNormal];
            }
            [weakSelf updateOriginalBtnFrame];
        }];
    }else {
        if (self.manager.configuration.showOriginalBytesLoading) {
            [self updateLoadingViewWithHidden:YES];
        }
        [self resetOriginalBtn];
    }
}
- (void)resetOriginalBtn {
    [self.manager.dataOperationQueue cancelAllOperations];
    [self.originalBtn setTitle:[NSBundle hx_localizedStringForKey:@"原图"] forState:UIControlStateNormal];
    [self updateOriginalBtnFrame];
}
- (void)changeDoneBtnFrame {
    CGFloat width = self.doneBtn.titleLabel.hx_getTextWidth;
//    self.doneBtn.hx_w = width + 20;
    if (self.doneBtn.hx_w < 60) {
        self.doneBtn.hx_w = 60;
    }
    self.doneBtn.hx_x = self.hx_w - self.doneBtn.hx_w;
}
- (void)updateOriginalBtnFrame {
    if (self.editBtn.hidden) {
        self.originalBtn.frame = CGRectMake(CGRectGetMaxX(self.previewBtn.frame) + 10, 0, 30, 50);
        
    }else {
        self.originalBtn.frame = CGRectMake(CGRectGetMaxX(self.editBtn.frame) + 10, 0, 30, 50);
    }
    self.originalBtn.hx_w = self.originalBtn.titleLabel.hx_getTextWidth + 30;
    if (CGRectGetMaxX(self.originalBtn.frame) > self.doneBtn.hx_x - 25) {
        CGFloat w = self.doneBtn.hx_x - 5 - self.originalBtn.hx_x;
        self.originalBtn.hx_w = w < 0 ? 30 : w;
    }
    
    self.originalBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 5 , 0, 0);
}
- (void)updateLoadingViewWithHidden:(BOOL)hidden {
    if (hidden && self.loadingView.hidden) {
        return;
    }
    if (!hidden && !self.loadingView.hidden) {
        return;
    }
    self.loadingView.hx_x = CGRectGetMaxX(self.originalBtn.frame) - 5;
    self.loadingView.hx_centerY = self.originalBtn.hx_h / 2;
    if (hidden) {
        [self.loadingView stopAnimating];
    }else {
        [self.loadingView startAnimating];
    }
    self.loadingView.hidden = hidden;
}
- (void)didDoneBtnClick {
    if ([self.delegate respondsToSelector:@selector(photoBottomViewDidDoneBtn)]) {
        [self.delegate photoBottomViewDidDoneBtn];
    }
}
- (void)didPreviewClick {
    if ([self.delegate respondsToSelector:@selector(photoBottomViewDidPreviewBtn)]) {
        [self.delegate photoBottomViewDidPreviewBtn];
    }
}
- (void)didEditBtnClick {
    if ([self.delegate respondsToSelector:@selector(photoBottomViewDidEditBtn)]) {
        [self.delegate photoBottomViewDidEditBtn];
    }
}
- (void)didOriginalClick:(UIButton *)button {
    button.selected = !button.selected;
    [self requestPhotosBytes];
    [self.manager setOriginal:button.selected]; 
}
- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.bgView.frame = self.bounds;
    self.previewBtn.frame = CGRectMake(12, 0, 0, 50);
    self.previewBtn.hx_w = self.previewBtn.titleLabel.hx_getTextWidth;
    self.previewBtn.center = CGPointMake(self.previewBtn.center.x, 25);
    
    self.editBtn.frame = CGRectMake(CGRectGetMaxX(self.previewBtn.frame) + 10, 0, 0, 50);
    self.editBtn.hx_w = self.editBtn.titleLabel.hx_getTextWidth;
    
    self.doneBtn.frame = CGRectMake(0, 0, 110, 52);
    self.doneBtn.center = CGPointMake(self.doneBtn.center.x, 25);
    [self changeDoneBtnFrame];
    
    [self updateOriginalBtnFrame];
}
- (UIToolbar *)bgView {
    if (!_bgView) {
        _bgView = [[UIToolbar alloc] init];
    }
    return _bgView;
}
- (UIButton *)previewBtn {
    if (!_previewBtn) {
        _previewBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_previewBtn setTitle:[NSBundle hx_localizedStringForKey:@"预览"] forState:UIControlStateNormal];
        _previewBtn.titleLabel.font = [UIFont systemFontOfSize:16];
        _previewBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_previewBtn addTarget:self action:@selector(didPreviewClick) forControlEvents:UIControlEventTouchUpInside];
        _previewBtn.enabled = NO;
    }
    return _previewBtn;
}
- (UIButton *)doneBtn {
    if (!_doneBtn) {
        _doneBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_doneBtn setTitle:[NSBundle hx_localizedStringForKey:@"完成"] forState:UIControlStateNormal];
        _doneBtn.titleLabel.font = [UIFont hx_mediumPingFangOfSize:16];
        [_doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
//        [_doneBtn setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.5] forState:UIControlStateDisabled];
//        _doneBtn.layer.cornerRadius = 3;
        _doneBtn.enabled = NO;
        [_doneBtn addTarget:self action:@selector(didDoneBtnClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _doneBtn;
}
- (UIButton *)originalBtn {
    if (!_originalBtn) {
        _originalBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_originalBtn setTitle:[NSBundle hx_localizedStringForKey:@"原图"] forState:UIControlStateNormal];
        [_originalBtn addTarget:self action:@selector(didOriginalClick:) forControlEvents:UIControlEventTouchUpInside];
        _originalBtn.titleLabel.font = [UIFont systemFontOfSize:16];
        _originalBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    }
    return _originalBtn;
}
- (UIButton *)editBtn {
    if (!_editBtn) {
        _editBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_editBtn setTitle:[NSBundle hx_localizedStringForKey:@"编辑"] forState:UIControlStateNormal];
        _editBtn.titleLabel.font = [UIFont systemFontOfSize:16];
        _editBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_editBtn addTarget:self action:@selector(didEditBtnClick) forControlEvents:UIControlEventTouchUpInside];
        _editBtn.enabled = NO;
    }
    return _editBtn;
}
- (UIActivityIndicatorView *)loadingView {
    if (!_loadingView) {
        _loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _loadingView.hidden = YES;
        [self addSubview:_loadingView];
    }
    return _loadingView;
}
@end
