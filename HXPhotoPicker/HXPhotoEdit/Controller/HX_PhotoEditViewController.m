//
//  HX_PhotoEditViewController.m
//  photoEditDemo
//
//  Created by 洪欣 on 2020/6/20.
//  Copyright © 2020 洪欣. All rights reserved.
//

#import "HX_PhotoEditViewController.h"
#import "HX_PhotoEditBottomView.h"
#import "UIView+HXExtension.h"
#import "HXPhotoEditGraffitiColorView.h"
#import "HXPhotoEditMosaicView.h"
#import "HXPhotoEditChartletListView.h"
#import "HXPhotoEditTextView.h"
#import "HXPhotoDefine.h"
#import "HXPhotoEditImageView.h"
#import "HXPhotoEditStickerItem.h"
#import "HXPhotoEditingView.h"
#import "HXPhotoClippingView.h"
#import "HXPhotoEditClippingToolBar.h"
#import "UIImage+HXExtension.h"
#import "UIButton+HXExtension.h"
#import "HXMECancelBlock.h"
#import "UIColor+HXExtension.h"
#import "HXPhotoModel.h"
#import "HXPhotoEditTransition.h"
#import "HXPhotoTools.h"

#define HXGraffitiColorViewHeight 60.f
#define HXmosaicViewHeight 60.f

@interface HX_PhotoEditViewController ()<UIGestureRecognizerDelegate, HXPhotoEditingViewDelegate>
@property (strong, nonatomic) UIView *topMaskView;
@property (strong, nonatomic) CAGradientLayer *topMaskLayer;
@property (strong, nonatomic) UIView *bottomMaskView;
@property (strong, nonatomic) CAGradientLayer *bottomMaskLayer;
@property (strong, nonatomic) HX_PhotoEditBottomView *toolsView;
@property (strong, nonatomic) HXPhotoEditGraffitiColorView *graffitiColorView;
@property (strong, nonatomic) HXPhotoEditMosaicView *mosaicView;
@property (strong, nonatomic) UIButton *backBtn;
@property (strong, nonatomic) HXPhotoEditingView *editingView;
@property (weak, nonatomic) UITapGestureRecognizer *tap;
@property (strong, nonatomic) HXPhotoEditClippingToolBar *clippingToolBar;
@property (strong, nonatomic) UIButton *rotateBtn;
@property (nonatomic, strong, nullable) NSDictionary *editData;
@property (assign, nonatomic) PHContentEditingInputRequestID requestId;
@property (assign, nonatomic) CGFloat imageWidth;
@property (assign, nonatomic) CGFloat imageHeight;
@property (strong, nonatomic) HXPhotoModel *afterModel;
@property (assign, nonatomic) BOOL orientationDidChange;
@end

@implementation HX_PhotoEditViewController
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
}
- (instancetype)init {
    self = [super init];
    if (self) {
        self.transitioningDelegate = self;
        self.modalPresentationStyle = UIModalPresentationCustom;
    }
    return self;
}
- (instancetype)initWithConfiguration:(HXPhotoEditConfiguration *)configuration {
    self = [super init];
    if (self) {
        self.transitioningDelegate = self;
        self.modalPresentationStyle = UIModalPresentationCustom;
        self.configuration = configuration;
    }
    return self;
}
- (instancetype)initWithPhotoEdit:(HXPhotoEdit *)photoEdit
                    configuration:(HXPhotoEditConfiguration *)configuration {
    self = [super init];
    if (self) {
        self.transitioningDelegate = self;
        self.modalPresentationStyle = UIModalPresentationCustom;
        self.photoEdit = photoEdit;
        self.configuration = configuration;
    }
    return self;
}
- (instancetype)initWithEditImage:(UIImage *)editImage
                    configuration:(HXPhotoEditConfiguration *)configuration {
    self = [super init];
    if (self) {
        self.transitioningDelegate = self;
        self.modalPresentationStyle = UIModalPresentationCustom;
        self.editImage = editImage;
        self.configuration = configuration;
    }
    return self;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source{
    return [HXPhotoEditTransition transitionWithType:HXPhotoEditTransitionTypePresent model:self.photoModel];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed{
    return [HXPhotoEditTransition transitionWithType:HXPhotoEditTransitionTypeDismiss model:self.photoModel];
}
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
    return UIRectEdgeAll;
}

- (BOOL)shouldAutorotate {
    if (!self.supportRotation) {
        return NO;
    }
    if (self.configuration.supportRotation) {
        return YES;
    }
    return NO;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (!self.supportRotation) {
        return UIInterfaceOrientationMaskPortrait;
    }
    if (self.configuration.supportRotation) {
        return UIInterfaceOrientationMaskAll;
    }else {
        return UIInterfaceOrientationMaskPortrait;
    }
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.requestId) {
        [self.photoModel.asset cancelContentEditingInputRequest:self.requestId];
    }
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
}
- (BOOL)prefersStatusBarHidden {
    return YES;
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
    // Do any additional setup after loading the view.
    self.orientationDidChange = NO;
    [self setupUI];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationChanged:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationWillChanged:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    
    [self hiddenTopBottomView];
}
- (void)setupUI {
    if (!self.onlyCliping) {
        self.onlyCliping = self.configuration.onlyCliping;
    }
    self.backBtn.alpha = 0;
    self.clippingToolBar.alpha = 0;
    self.toolsView.alpha = 0;
    self.topMaskView.alpha = 0;
    self.bottomMaskView.alpha = 0;
    
    self.view.backgroundColor = [UIColor blackColor];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didBgViewClick)];
    tap.numberOfTapsRequired = 1;
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
    self.tap = tap;
    self.view.exclusiveTouch = YES;
    [self setupPhotoModel];
    [self.view addSubview:self.editingView];
    [self.view addSubview:self.bottomMaskView];
    if (self.onlyCliping) {
        [self.view addSubview:self.clippingToolBar];
        [self.view addSubview:self.rotateBtn];
        [self.editingView photoEditEnable:NO];
        self.tap.enabled = NO;
        self.clippingToolBar.userInteractionEnabled = YES;
        self.rotateBtn.userInteractionEnabled = YES;
    }else {
        [self.view addSubview:self.topMaskView];
        [self.topMaskView addSubview:self.backBtn];
        [self.view addSubview:self.toolsView];
        [self.view addSubview:self.clippingToolBar];
        [self.view addSubview:self.rotateBtn];
    }
}
- (void)deviceOrientationWillChanged:(NSNotification *)notify {
    if (self.editingView.clipping) {
        [self.toolsView endCliping];
        [self.editingView cancelClipping:NO];
    }
    [self.editingView resetRotateAngle];
    self.editingView.zoomScale = 1;
    self.editingView.clippingView.zoomScale = 1;
}
- (void)deviceOrientationChanged:(NSNotification *)notify {
    self.orientationDidChange = YES;
}
- (void)changeSubviewFrame {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat leftMargin = hxBottomMargin;
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        leftMargin = 0;
        self.backBtn.hx_x = 20;
        self.backBtn.hx_y = hxNavigationBarHeight - 20 - _backBtn.hx_h;
        self.clippingToolBar.frame = CGRectMake(0, self.view.hx_h - 50 - hxBottomMargin, self.view.hx_w, 50 + hxBottomMargin);
        self.toolsView.frame = CGRectMake(0, self.view.hx_h - 50 - hxBottomMargin, self.view.hx_w, 50 + hxBottomMargin);
        self.rotateBtn.hx_x = 25.f;
        
    }else if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft) {
        self.backBtn.hx_x = 20 + hxBottomMargin;
        self.backBtn.hx_y = 20;
        self.clippingToolBar.frame = CGRectMake(hxBottomMargin, self.view.hx_h - 50, self.view.hx_w - hxBottomMargin * 2, 50);
        self.toolsView.frame = CGRectMake(hxBottomMargin, self.view.hx_h - 50, self.view.hx_w - hxBottomMargin * 2, 50);
        self.rotateBtn.hx_x = 25 + hxBottomMargin;
    }
    self.rotateBtn.hx_y = self.clippingToolBar.hx_y - 70 + self.rotateBtn.hx_h;
    self.graffitiColorView.frame = CGRectMake(leftMargin, self.toolsView.hx_y - HXGraffitiColorViewHeight, self.view.hx_w - leftMargin * 2, HXGraffitiColorViewHeight);
    self.mosaicView.frame = CGRectMake(leftMargin, self.toolsView.hx_y - HXmosaicViewHeight, self.view.hx_w - leftMargin * 2, HXmosaicViewHeight);
    self.topMaskView.frame = CGRectMake(0, 0, HX_ScreenWidth, hxNavigationBarHeight);
    self.topMaskLayer.frame = CGRectMake(0, 0, HX_ScreenWidth, hxNavigationBarHeight + 30.f);

    self.bottomMaskView.frame = CGRectMake(0, HX_ScreenHeight - hxBottomMargin - 120, HX_ScreenWidth, hxBottomMargin + 120);
    self.bottomMaskLayer.frame = self.bottomMaskView.bounds;
    
    if (self.orientationDidChange) {
        self.editingView.frame = self.view.bounds;
        [self.editingView changeSubviewFrame];
        self.editingView.image = self.editImage;
        [self.editingView clearCoverage];
    }
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:NSClassFromString(@"HXPhotoEditStickerItemContentView")] ||
        touch.view == self.backBtn) {
        return NO;
    }
    if ([touch.view isDescendantOfView:self.editingView] ||
        touch.view == self.view ||
        touch.view == self.topMaskView) {
        return YES;
    }
    return NO;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}
- (void)setupPhotoModel {
    self.imageWidth = self.photoModel.imageSize.width;
    self.imageHeight = self.photoModel.imageSize.height;
    if (self.photoModel.photoEdit) {
        self.imageRequestComplete = YES;
        self.photoEdit = self.photoModel.photoEdit;
        self.editingView.image = self.editImage;
        [self setupPhotoData];
    }else {
        if (self.photoModel.asset) {
            [self requestImaegURL];
        }else {
            if (self.photoModel.thumbPhoto.images.count > 1) {
                self.editImage = self.photoModel.thumbPhoto.images.firstObject;
            }else {
                self.editImage = self.photoModel.thumbPhoto;
            }
            [self loadImageCompletion];
        }
    }
}
- (void)setupPhotoData {
    if (self.editData) {
        self.editingView.photoEditData = self.editData;
        self.graffitiColorView.undo = self.editingView.clippingView.imageView.drawView.canUndo;
        self.mosaicView.undo = self.editingView.clippingView.imageView.splashView.canUndo;
        self.editData = nil;
    }
}
- (void)requestImaegURL {
    HXWeakSelf
    self.requestId = [self.photoModel requestImageURLStartRequestICloud:^(PHContentEditingInputRequestID iCloudRequestId, HXPhotoModel *model) {
        weakSelf.requestId = iCloudRequestId;
    } progressHandler:nil success:^(NSURL *imageURL, HXPhotoModel *model, NSDictionary *info) {
        NSData *imageData = [NSData dataWithContentsOfFile:imageURL.relativePath];
        UIImage *image = [UIImage imageWithData:imageData];
        if (image.imageOrientation != UIImageOrientationUp) {
            image = [image hx_normalizedImage];
        }
        weakSelf.editImage = image;
        [weakSelf.view hx_handleLoading];
        [weakSelf loadImageCompletion];
    } failed:^(NSDictionary *info, HXPhotoModel *model) {
        [weakSelf requenstImage];
    }];
}
- (void)requenstImage {
    HXWeakSelf
    self.requestId = [self.photoModel requestPreviewImageWithSize:PHImageManagerMaximumSize startRequestICloud:^(PHImageRequestID iCloudRequestId, HXPhotoModel * _Nullable model) {
        weakSelf.requestId = iCloudRequestId;
    } progressHandler:nil success:^(UIImage * _Nullable image, HXPhotoModel * _Nullable model, NSDictionary * _Nullable info) {
        if (image.imageOrientation != UIImageOrientationUp) {
            image = [image hx_normalizedImage];
        }
        if (image.images.count > 1) {
            weakSelf.editImage = image.images.firstObject;
        }else {
            weakSelf.editImage = image;
        }
        [weakSelf.view hx_handleLoading];
        [weakSelf loadImageCompletion];
    } failed:^(NSDictionary * _Nullable info, HXPhotoModel * _Nullable model) {
        [weakSelf.view hx_handleLoading];
        [weakSelf loadImageCompletion];
    }];
}
- (void)loadImageCompletion {
    self.imageRequestComplete = YES;
    if (self.transitionCompletion) {
        self.editingView.image = self.editImage;
        [self setupPhotoData];
        if (self.onlyCliping) {
            [self.editingView setClipping:YES animated:YES];
            [UIView animateWithDuration:0.2 animations:^{
                self.rotateBtn.alpha = 1;
                self.clippingToolBar.alpha = 1;
            }];
        }
    }
}
- (CGRect)getImageFrame {
    CGFloat width = self.view.hx_w;
    CGFloat height = self.view.hx_h;
    CGFloat imgWidth = self.imageWidth;
    CGFloat imgHeight = self.imageHeight;
    imgHeight = width / imgWidth * imgHeight;
    CGFloat y = 0;
    if (imgHeight < height) {
        y = (height - imgHeight) / 2;
    }
    return CGRectMake(0, y, width, imgHeight);
}
- (CGRect)getDismissImageFrame {
    CGFloat screenScale = self.editingView.zoomScale;
    CGFloat width = self.editingView.clippingView.hx_w * screenScale;
    CGFloat height = self.editingView.clippingView.hx_h * screenScale;
    
    CGFloat imageX = (self.editingView.clipZoomView.hx_w / screenScale - self.editingView.clippingView.hx_w) / 2 * screenScale;
    CGFloat imageY = (self.editingView.clipZoomView.hx_h / screenScale - self.editingView.clippingView.hx_h) / 2 * screenScale;
    CGRect rect = [self.editingView convertRect:CGRectMake(imageX, imageY, width, height) toView:[UIApplication sharedApplication].keyWindow];
    return rect;
}
- (UIImage *)getCurrentImage {
    if (self.photoModel.photoEdit) {
        return self.photoModel.photoEdit.editPreviewImage;
    }
    return self.editImage;
}
- (void)hideImageView {
    self.editingView.hidden = YES;
}
- (void)completeTransition:(UIImage *)image {
    self.transitionCompletion = YES;
    self.editingView.hidden = NO;
    if (self.photoModel.photoEdit) {
        if (self.onlyCliping) {
            [self.editingView setClipping:YES animated:YES];
            [UIView animateWithDuration:0.2 animations:^{
                self.rotateBtn.alpha = 1;
                self.clippingToolBar.alpha = 1;
            }];
        }
        return;
    }
    if (self.imageRequestComplete) {
        [self loadImageCompletion];
    }else {
        self.editingView.image = image;
        [self.view hx_showLoadingHUDText:nil];
    }
}
- (void)hiddenTopBottomView {
    self.backBtn.hx_y = -self.backBtn.hx_h;
    self.clippingToolBar.hx_y = self.view.hx_h;
    self.toolsView.hx_y = self.view.hx_h;
    self.topMaskView.hx_y = -hxNavigationBarHeight;
    self.bottomMaskView.hx_y = self.view.hx_h;
}
- (void)showTopBottomView {
    [self changeSubviewFrame];
    self.backBtn.alpha = 1;
    if (self.onlyCliping) {
        self.clippingToolBar.alpha = 1;
    }
    self.toolsView.alpha = 1;
    self.topMaskView.alpha = 1;
    self.bottomMaskView.alpha = 1;
}
- (void)showBgViews {
    self.backBtn.userInteractionEnabled = YES;
    self.toolsView.userInteractionEnabled = YES;
    self.graffitiColorView.userInteractionEnabled = YES;
    self.mosaicView.userInteractionEnabled = YES;
    [UIView animateWithDuration:0.25 animations:^{
        self.backBtn.alpha = 1;
        self.toolsView.alpha = 1;
        self.graffitiColorView.alpha = 1;
        self.mosaicView.alpha = 1;
        self.topMaskView.alpha = 1;
        self.bottomMaskView.alpha = 1;
    }];
}
- (void)hideBgViews {
    self.backBtn.userInteractionEnabled = NO;
    self.toolsView.userInteractionEnabled = NO;
    self.graffitiColorView.userInteractionEnabled = NO;
    self.mosaicView.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.backBtn.alpha = 0;
        self.toolsView.alpha = 0;
        self.graffitiColorView.alpha = 0;
        self.mosaicView.alpha = 0;
        self.topMaskView.alpha = 0;
        self.bottomMaskView.alpha = 0;
    }];
}
- (void)didBgViewClick {
    [UIView cancelPreviousPerformRequestsWithTarget:self];
    if (self.toolsView.alpha != 1) {
        [self showBgViews];
    }else {
        [self hideBgViews];
    }
}
#pragma mark - HXPhotoEditingViewDelegate
/** 开始编辑目标 */
- (void)editingViewWillBeginEditing:(HXPhotoEditingView *)EditingView {
    [UIView animateWithDuration:0.25f animations:^{
        self.rotateBtn.alpha = 0.f;
    }];
}
/** 停止编辑目标 */
- (void)editingViewDidEndEditing:(HXPhotoEditingView *)EditingView {
    if (self.rotateBtn.userInteractionEnabled) {
        [UIView animateWithDuration:0.25f animations:^{
            self.rotateBtn.alpha = 1.f;
        }];
    }
    self.clippingToolBar.enableReset = self.editingView.canReset;
}
/** 进入剪切界面 */
- (void)editingViewDidAppearClip:(HXPhotoEditingView *)EditingView {
    self.clippingToolBar.enableReset = self.editingView.canReset;
}
- (void)setEditImage:(UIImage *)editImage {
    if (!self.photoEdit) {
        _editImage = HX_UIImageDecodedCopy(editImage);
    }
}
- (void)setPhotoEdit:(HXPhotoEdit *)photoEdit {
    _photoEdit = photoEdit;
    if (photoEdit) {
        _editImage = photoEdit.editImage;
        self.editData = photoEdit.editData;
    }
}
- (UIButton *)backBtn {
    if (!_backBtn) {
        _backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_backBtn setImage:[UIImage hx_imageNamed:@"hx_photo_edit_back"] forState:UIControlStateNormal];
        _backBtn.imageView.tintColor = [UIColor whiteColor];
        _backBtn.tintColor = [UIColor whiteColor];
        _backBtn.hx_size = _backBtn.currentImage.size;
        _backBtn.hx_x = 20;
        _backBtn.hx_y = hxNavigationBarHeight - 15 - _backBtn.hx_h;
        [_backBtn addTarget:self action:@selector(didBackClick) forControlEvents:UIControlEventTouchUpInside];
        [_backBtn hx_setEnlargeEdgeWithTop:20 right:20 bottom:20 left:20];
    }
    return _backBtn;
}
- (void)didBackClick {
    if (self.cancelBlock) {
        self.cancelBlock(self);
    }
    self.isCancel = YES;
    if (self.navigationController.viewControllers.count <= 1) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}
- (HX_PhotoEditBottomView *)toolsView {
    if (!_toolsView) {
        _toolsView = [HX_PhotoEditBottomView initView];
        _toolsView.themeColor = self.configuration.themeColor;
        _toolsView.frame = CGRectMake(0, self.view.hx_h - 50 - hxBottomMargin, self.view.hx_w, 50 + hxBottomMargin);
        HXWeakSelf
        _toolsView.didToolsBtnBlock = ^(NSInteger tag, BOOL isSelected) {
            [weakSelf.editingView.clippingView.imageView.stickerView removeSelectItem];
            if (tag == 0) {
                // 绘画
                [weakSelf.mosaicView removeFromSuperview];
                weakSelf.editingView.splashEnable = NO;
                weakSelf.editingView.drawEnable = isSelected;
                if (isSelected) {
                    weakSelf.editingView.clippingView.imageView.type = HXPhotoEditImageViewTypeDraw;
                    [weakSelf.view addSubview:weakSelf.graffitiColorView];
                }else {
                    weakSelf.editingView.clippingView.imageView.type = HXPhotoEditImageViewTypeNormal;
                    [weakSelf.graffitiColorView removeFromSuperview];
                }
            }else if (tag == 1) {
                // 贴图
                [HXPhotoEditChartletListView showEmojiViewWithModels:weakSelf.configuration.chartletModels completion:^(UIImage * _Nonnull image) {
                    HXPhotoEditStickerItem *item = [[HXPhotoEditStickerItem alloc] init];
                    item.image = image;
                    [weakSelf.editingView.clippingView.imageView.stickerView addStickerItem:item isSelected:YES];
                }];
            }else if (tag == 2) {
                // 文字
                [HXPhotoEditTextView showEitdTextViewWithConfiguration:weakSelf.configuration completion:^(HXPhotoEditTextModel * _Nonnull textModel) {
                    HXPhotoEditStickerItem *item = [[HXPhotoEditStickerItem alloc] init];
                    item.textModel = textModel;
                    [weakSelf.editingView.clippingView.imageView.stickerView addStickerItem:item isSelected:YES];
                }];
            }else if (tag == 3) {
                // 裁剪
                [weakSelf.editingView photoEditEnable:!isSelected];
                weakSelf.tap.enabled = !isSelected;
                weakSelf.clippingToolBar.userInteractionEnabled = isSelected;
                weakSelf.rotateBtn.userInteractionEnabled = isSelected;
                [UIView animateWithDuration:0.25 animations:^{
                    weakSelf.clippingToolBar.alpha = isSelected ? 1 : 0;
                    weakSelf.rotateBtn.alpha = weakSelf.clippingToolBar.alpha;
                }];
                if (isSelected) {
                    [weakSelf.editingView setClipping:YES animated:YES];
                    [weakSelf hideBgViews];
                    weakSelf.bottomMaskView.alpha = 1;
                }else {
                    [weakSelf showBgViews];
                }
            }else if (tag == 4) {
                // 马赛克
                weakSelf.editingView.drawEnable = NO;
                weakSelf.editingView.splashEnable = isSelected;
                weakSelf.editingView.clippingView.imageView.type = HXPhotoEditImageViewTypeNormal;
                [weakSelf.graffitiColorView removeFromSuperview];
                if (isSelected) {
                    weakSelf.editingView.clippingView.imageView.type = HXPhotoEditImageViewTypeSplash;
                    [weakSelf.view addSubview:weakSelf.mosaicView];
                }else {
                    weakSelf.editingView.clippingView.imageView.type = HXPhotoEditImageViewTypeNormal;
                    [weakSelf.mosaicView removeFromSuperview];
                }
            }
        };
        _toolsView.didDoneBtnBlock = ^{
            [weakSelf startEditImage];
        };
    }
    return _toolsView;
}
- (void)startEditImage {
    self.view.userInteractionEnabled = NO;
    [self.view hx_showLoadingHUDText:nil];
    __block HXPhotoEdit *photoEdit = nil;
    NSDictionary *data = [self.editingView photoEditData];
    HXWeakSelf
    void (^finishImage)(UIImage *) = ^(UIImage *image){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (data) {
                photoEdit = [[HXPhotoEdit alloc] initWithEditImage:weakSelf.editImage previewImage:image data:data];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.photoModel.photoEdit = photoEdit;
                weakSelf.photoModel.assetByte = 0;

                if (weakSelf.saveAlbum) {
                    UIImage *saveImage = photoEdit ? photoEdit.editPreviewImage : weakSelf.editImage;
                    [HXPhotoTools savePhotoToCustomAlbumWithName:weakSelf.albumName photo:saveImage location:weakSelf.location complete:^(HXPhotoModel *model, BOOL success) {
                        if (!success) {
                            model = [HXPhotoModel photoModelWithImage:saveImage];
                        }

                        if ([weakSelf.delegate respondsToSelector:@selector(photoEditingController:didFinishPhotoEdit:photoModel:)]) {
                            [weakSelf.delegate photoEditingController:weakSelf didFinishPhotoEdit:nil photoModel:model];
                        }
                        if (weakSelf.finishBlock) {
                            weakSelf.finishBlock(nil, model, weakSelf);
                        }
                        [weakSelf dissmissClick];
                    }];
                }else {
                    if ([weakSelf.delegate respondsToSelector:@selector(photoEditingController:didFinishPhotoEdit:photoModel:)]) {
                        [weakSelf.delegate photoEditingController:weakSelf didFinishPhotoEdit:photoEdit photoModel:weakSelf.photoModel];
                    }
                    if (weakSelf.finishBlock) {
                        weakSelf.finishBlock(photoEdit, weakSelf.photoModel, weakSelf);
                    }
                    [weakSelf dissmissClick];
                }
            });
        });
    };
    [weakSelf.editingView.clippingView.imageView.stickerView removeSelectItem];
    [weakSelf.editingView createEditImage:^(UIImage *editImage) {
        finishImage(editImage);
    }];
}
- (void)dissmissClick {
    [self.view hx_handleLoading];
    self.view.userInteractionEnabled = YES;
    if (self.navigationController.viewControllers.count <= 1) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}
- (HXPhotoEditGraffitiColorView *)graffitiColorView {
    if (!_graffitiColorView) {
        _graffitiColorView = [HXPhotoEditGraffitiColorView initView];
        _graffitiColorView.frame = CGRectMake(0, self.toolsView.hx_y - HXGraffitiColorViewHeight, self.view.hx_w, HXGraffitiColorViewHeight);
        _graffitiColorView.drawColors = self.configuration.drawColors;
        HXWeakSelf
        _graffitiColorView.selectColorBlock = ^(UIColor * _Nonnull color) {
            weakSelf.editingView.clippingView.imageView.drawView.lineColor = color;
        };
        _graffitiColorView.undoBlock = ^{
            [weakSelf.editingView.clippingView.imageView.drawView undo];
            weakSelf.graffitiColorView.undo = weakSelf.editingView.clippingView.imageView.drawView.canUndo;
        };
    }
    return _graffitiColorView;
}
- (HXPhotoEditMosaicView *)mosaicView {
    if (!_mosaicView) {
        _mosaicView = [HXPhotoEditMosaicView initView];
        _mosaicView.themeColor = self.configuration.themeColor;
        _mosaicView.frame = CGRectMake(0, self.toolsView.hx_y - HXmosaicViewHeight, self.view.hx_w, HXmosaicViewHeight);
        HXWeakSelf
        _mosaicView.didBtnBlock = ^(NSInteger tag) {
            if (tag == 0) {
                weakSelf.editingView.clippingView.imageView.splashView.state = HXPhotoEditSplashStateType_Mosaic;
            }else {
                weakSelf.editingView.clippingView.imageView.splashView.state = HXPhotoEditSplashStateType_Paintbrush;
            }
        };
        _mosaicView.undoBlock = ^{
            [weakSelf.editingView.clippingView.imageView.splashView undo];
            weakSelf.mosaicView.undo = weakSelf.editingView.clippingView.imageView.splashView.canUndo;
        };
    }
    return _mosaicView;
}
- (HXPhotoEditingView *)editingView {
    if (!_editingView) {
        _editingView = [[HXPhotoEditingView alloc] initWithFrame:self.view.bounds];
        _editingView.onlyCliping = self.onlyCliping;
        _editingView.configuration = self.configuration;
        _editingView.clippingDelegate = self;
        _editingView.clippingView.imageView.drawView.lineColor = self.configuration.drawColors.firstObject;
        _editingView.clippingView.imageView.drawView.lineWidth = self.configuration.lineWidth;
        if (self.configuration.aspectRatio != HXPhotoEditAspectRatioType_None) {
            _editingView.fixedAspectRatio = YES;
        }
        _editingView.defaultAspectRatioIndex = self.configuration.aspectRatio;
        _editingView.customRatioSize = self.configuration.customAspectRatio;
        HXWeakSelf
        /** 模糊 */
        _editingView.clippingView.imageView.splashView.splashBegan = ^{
            [weakSelf hideBgViews];
            [UIView cancelPreviousPerformRequestsWithTarget:weakSelf];
        };
        _editingView.clippingView.imageView.splashView.splashEnded = ^{
            weakSelf.mosaicView.undo = YES;
            [weakSelf performSelector:@selector(showBgViews) withObject:nil afterDelay:.5f];
        };
        _editingView.clippingView.imageView.drawView.beganDraw = ^{
            // 开始绘画
            [weakSelf hideBgViews];
            [UIView cancelPreviousPerformRequestsWithTarget:weakSelf];
        };
        _editingView.clippingView.imageView.drawView.endDraw = ^{
            // 结束绘画
            weakSelf.graffitiColorView.undo = YES;
            [weakSelf performSelector:@selector(showBgViews) withObject:nil afterDelay:.5f];
        };
        _editingView.clippingView.imageView.stickerView.touchBegan = ^(HXPhotoEditStickerItemView * _Nonnull itemView) {
            [weakSelf hideBgViews];
        };
        _editingView.clippingView.imageView.stickerView.touchEnded = ^(HXPhotoEditStickerItemView * _Nonnull itemView) {
            [weakSelf showBgViews];
        };
    }
    return _editingView;
}
- (HXPhotoEditClippingToolBar *)clippingToolBar {
    if (!_clippingToolBar) {
        _clippingToolBar = [HXPhotoEditClippingToolBar initView];
        _clippingToolBar.userInteractionEnabled = NO;
        _clippingToolBar.alpha = 0;
        _clippingToolBar.frame = CGRectMake(0, self.view.hx_h - 50 - hxBottomMargin, self.view.hx_w, 50 + hxBottomMargin);
        HXWeakSelf
        _clippingToolBar.didBtnBlock = ^(NSInteger tag) {
            if (tag == 0) {
                // 取消
                if (weakSelf.onlyCliping) {
                    [weakSelf didBackClick];
                    return;
                }
                [weakSelf.toolsView endCliping];
                [weakSelf.editingView cancelClipping:YES];
            }else if (tag == 1) {
                // 确认
                if (weakSelf.onlyCliping) {
                    [weakSelf startEditImage];
                    return;
                }
                [weakSelf.toolsView endCliping];
                [weakSelf.editingView setClipping:NO animated:YES];
            }else if (tag == 2) {
                // 还原
                [weakSelf.editingView reset];
                weakSelf.clippingToolBar.enableReset = weakSelf.editingView.canReset;
            }
        };
    }
    return _clippingToolBar;
}
- (UIButton *)rotateBtn {
    if (!_rotateBtn) {
        _rotateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_rotateBtn setImage:[UIImage hx_imageNamed:@"hx_photo_edit_clip_rotate"] forState:UIControlStateNormal];
        _rotateBtn.hx_size = _rotateBtn.currentImage.size;
        _rotateBtn.hx_x = 25.f;
        _rotateBtn.hx_y = self.clippingToolBar.hx_y - 70 + _rotateBtn.hx_h;
        _rotateBtn.tintColor = [UIColor whiteColor];
        [_rotateBtn addTarget:self action:@selector(didRotateBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        _rotateBtn.userInteractionEnabled = NO;
        _rotateBtn.alpha = 0;
        [_rotateBtn hx_setEnlargeEdgeWithTop:5 right:20 bottom:20 left:20];
    }
    return _rotateBtn;
}
- (void)didRotateBtnClick:(UIButton *)button {
    [self.editingView rotate];
    self.clippingToolBar.enableReset = self.editingView.canReset;
}
- (UIView *)topMaskView {
    if (!_topMaskView) {
        _topMaskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, HX_ScreenWidth, hxNavigationBarHeight)];
        self.topMaskLayer.frame = CGRectMake(0, 0, HX_ScreenWidth, hxNavigationBarHeight + 30.f);
        [_topMaskView.layer addSublayer:self.topMaskLayer];
    }
    return _topMaskView;
}
- (CAGradientLayer *)topMaskLayer {
    if (!_topMaskLayer) {
        _topMaskLayer = [CAGradientLayer layer];
        _topMaskLayer.colors = @[
                                    (id)[[UIColor blackColor] colorWithAlphaComponent:0].CGColor,
                                    (id)[[UIColor blackColor] colorWithAlphaComponent:0.3].CGColor
                                    ];
        _topMaskLayer.startPoint = CGPointMake(0, 1);
        _topMaskLayer.endPoint = CGPointMake(0, 0);
        _topMaskLayer.locations = @[@(0.15f),@(0.9f)];
        _topMaskLayer.borderWidth  = 0.0;
    }
    return _topMaskLayer;
}
- (UIView *)bottomMaskView {
    if (!_bottomMaskView) {
        _bottomMaskView = [[UIView alloc] initWithFrame:CGRectMake(0, HX_ScreenHeight - hxBottomMargin - 120, HX_ScreenWidth, hxBottomMargin + 120)];
        _bottomMaskView.userInteractionEnabled = NO;
        self.bottomMaskLayer.frame = _bottomMaskView.bounds;
        [_bottomMaskView.layer addSublayer:self.bottomMaskLayer];
    }
    return _bottomMaskView;;
}
- (CAGradientLayer *)bottomMaskLayer {
    if (!_bottomMaskLayer) {
        _bottomMaskLayer = [CAGradientLayer layer];
        _bottomMaskLayer.colors = @[
                                    (id)[[UIColor blackColor] colorWithAlphaComponent:0].CGColor,
                                    (id)[[UIColor blackColor] colorWithAlphaComponent:0.4].CGColor
                                    ];
        _bottomMaskLayer.startPoint = CGPointMake(0, 0);
        _bottomMaskLayer.endPoint = CGPointMake(0, 1);
        _bottomMaskLayer.locations = @[@(0),@(1.f)];
        _bottomMaskLayer.borderWidth  = 0.0;
    }
    return _bottomMaskLayer;
}
- (HXPhotoEditConfiguration *)configuration {
    if (!_configuration) {
        _configuration = [[HXPhotoEditConfiguration alloc] init];
    }
    return _configuration;
}
@end