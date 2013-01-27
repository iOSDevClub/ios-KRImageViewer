//
//  KRImageViewer.m
//
//  ilovekalvar@gmail.com
//
//  Created by Kuo-Ming Lin on 2012/11/07.
//  Copyright (c) 2012年 Kuo-Ming Lin. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "KRImageViewer.h"
#import "KRImageOperation.h"
#import "KRImageScrollView.h"


static CGFloat _backgroundViewBlackColor = 0.0f;
static NSInteger krLoadingViewTag   = 1799;
static NSInteger krLoadingButtonTag = 1800;
static NSInteger krBrowseButtonTag  = 1801;

@interface KRImageViewer (){
    UIPanGestureRecognizer *_panGestureRecognizer;
    NSOperationQueue *_operationQueues;
    UIView *_backgroundView;
    UIView *_dragView;
    UIScrollView *_scrollView;
    //要顯示的圖片 [imageID] = imageURL;
    NSMutableDictionary *_caches;
    NSMutableArray *_sortedKeys;
    NSMutableDictionary *_imageInfos;
}

@property (nonatomic, assign) CGPoint _orignalPoints;
@property (nonatomic, assign) CGPoint _matchPoints;
@property (nonatomic, retain) UIPanGestureRecognizer *_panGestureRecognizer;
@property (nonatomic, assign) UIView *_gestureView;
@property (nonatomic, retain) NSOperationQueue *_operationQueues;
@property (nonatomic, retain) UIView *_backgroundView;
@property (nonatomic, retain) UIView *_dragView;
@property (nonatomic, retain) UIScrollView *_scrollView;
@property (nonatomic, retain) NSMutableDictionary *_caches;
@property (nonatomic, retain) NSMutableArray *_sortedKeys;
@property (nonatomic, retain) NSMutableDictionary *_imageInfos;
@property (nonatomic, assign) BOOL _isCancelled;

@end

@interface KRImageViewer (fixDrages)

-(void)_initWithVars;
-(void)_resetViewVars;
-(void)_setupBackgroundView;
-(void)_setupDragView;
-(void)_allocPanGesture;
-(void)_addViewDragGesture;
-(void)_removeViewDragGesture;
-(void)_moveView:(UIView *)_targetView toX:(CGFloat)_toX toY:(CGFloat)_toY;
-(CGFloat)_dragDisapperInstance;
-(void)_hideDoneButton;
-(void)_displayDoneButton;
-(void)_handleDrag:(UIPanGestureRecognizer*)_panGesture;
//
-(void)_resortKeys;
-(void)_cancelAllOperations;
-(void)_downloadImageURLs:(NSDictionary *)_urls;
-(void)_resetBackgroundViewAlpha;
//
-(void)_scrollViewRemoveAllSubviews;
-(void)_setupScrollView;
-(void)_setupImagesInScrollView;
//
-(void)_browseImages;
-(void)_removeBrowser:(id)sender;
-(void)_removeAllViews;
//
-(CGFloat)_statusBarHeight;
-(void)_startLoading;
-(void)_stopLoading;
-(void)_appearStatus:(BOOL)_isAppear;
//
-(NSInteger)_currentPage;
-(NSInteger)_currentIndex;
-(void)_scrollToPage:(NSInteger)_toPage;
//
-(NSDictionary *)_sortDictionary:(NSDictionary *)_formatedDatas ascending:(BOOL)_isAsc;
-(BOOL)_isInt:(NSString*)_string;
-(void)_refreshCaches;
-(void)_disapperAsSuckEffect;
//
-(NSInteger)_findOperationCacheMode;
-(void)_cancelAndClose:(id)sender;
//
-(UIImage *)_imageNameNoCache:(NSString *)_imageName;
-(NSString *)_findImageIndexWithId:(NSString *)_imageId;

@end

@implementation KRImageViewer (fixDrages)

-(void)_initWithVars{
    if( self.maxConcurrentOperationCount <= 0 ){
        //一次只處理 n 個 Operation
        self.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
    }
    self.sideInstance = 0.0f;
    self.durations    = 0.2f;
    _operationQueues  = [[NSOperationQueue alloc] init];
    _caches           = [[NSMutableDictionary alloc] initWithCapacity:0];
    _sortedKeys       = [[NSMutableArray alloc] initWithCapacity:0];
    _imageInfos       = [[NSMutableDictionary alloc] initWithCapacity:0];
    self.dragDisapperMode      = krImageViewerDisapperAfterMiddle;
    self.allowOperationCaching = YES;
    self.statusBarHidden       = YES;
    self.scrollToPage          = 0;
    self.maximumZoomScale      = 2.0f;
    self.minimumZoomScale      = 1.0f;
    self.zoomScale             = 2.0f;
    self.clipsToBounds         = YES;
    self._isCancelled          = NO;
    self.timeout               = 60.0f;
}

-(void)_resetViewVars{
    [self _setupBackgroundView];
    [self _setupDragView];
    [self _setupScrollView];
    if( self._dragView ){
        self._gestureView   = self._dragView;
        self._orignalPoints = self._gestureView.center;
        [self _resetMatchPoints];
    }
}

-(void)_setupBackgroundView{
    if( !_backgroundView ){
        _backgroundView = [[UIView alloc] init];
    }
    if( self.view ){
        [self._backgroundView setFrame:self.view.frame];
    }
    [self._backgroundView setBackgroundColor:[UIColor clearColor]];
    [self._backgroundView setBackgroundColor:[UIColor colorWithRed:_backgroundViewBlackColor
                                                             green:_backgroundViewBlackColor
                                                              blue:_backgroundViewBlackColor
                                                             alpha:0.9f]];
}

-(void)_setupDragView{
    if( !_dragView ){
        _dragView = [[UIView alloc] init];
    }
    if( self.view ){
        [self._dragView setFrame:self.view.frame];
    }
    [self._dragView setBackgroundColor:[UIColor clearColor]];
}

-(void)_resetMatchPoints{
    /*
     * 因為不允許左右移動，所以 X 軸幾乎不會動
     * 如果現在的 X 軸與原始的 X 軸不相等，代表畫面上的 View 有變動
     */
    //修正誤差
    CGFloat _xOffset = 0.0f;
    if( self._gestureView.center.x != self._orignalPoints.x ){
        _xOffset = self._gestureView.center.x - self._orignalPoints.x;
    }
    self._matchPoints = CGPointMake(self._orignalPoints.x + _xOffset, self._orignalPoints.y);
}

-(void)_allocPanGesture{
    if( _panGestureRecognizer ) return;
    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                    action:@selector(_handleDrag:)];
}

-(void)_addViewDragGesture{
    [self._gestureView addGestureRecognizer:self._panGestureRecognizer];
}

-(void)_removeViewDragGesture{
    [self._gestureView removeGestureRecognizer:self._panGestureRecognizer];
}

-(void)_moveView:(UIView *)_targetView
             toX:(CGFloat)_toX
             toY:(CGFloat)_toY
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:self.durations];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationBeginsFromCurrentState:YES];
    _targetView.frame = CGRectMake(_toX,
                                   _toY,
                                   _targetView.frame.size.width,
                                   _targetView.frame.size.height);
    [UIView commitAnimations];
}

-(CGFloat)_dragDisapperInstance{
    CGFloat _screenHeight = self._gestureView.frame.size.height;
    CGFloat _disapperInstance = 0.0f;
    switch ( self.dragDisapperMode ) {
        case krImageViewerDisapperAfterMiddle:
            _disapperInstance = _screenHeight / 2;
            break;
        case krImageViewerDisapperAfter25Percent:
            _disapperInstance = _screenHeight * 0.25;
            break;
        case krImageViewerDisapperAfter10Percent:
            _disapperInstance = _screenHeight * 0.1;
            break;
        case krImageViewerDisapperNothing:
            // ... 
            break;
        default:
            break;
    }
    return _disapperInstance;
}

-(void)_hideDoneButton{
    [(UIButton *)[self._dragView viewWithTag:krBrowseButtonTag] setHidden:YES];
}

-(void)_displayDoneButton{
    [(UIButton *)[self._dragView viewWithTag:krBrowseButtonTag] setHidden:NO];
}

/*
 * 拖拉的動作，待修 !
 */
-(void)_handleDrag:(UIPanGestureRecognizer *)_panGesture
{
    //目前手勢 View 的中心位置
    CGPoint center      = _panGesture.view.center;
    //手勢在目前 View 上的觸碰點
    CGPoint translation = [_panGesture translationInView:_panGesture.view];
    //當前作用 View 的位置
    CGPoint viewCenter  = self._gestureView.frame.origin;
    //判斷是否需重設原比對用的 X 座標值
    [self _resetMatchPoints];
    
//  NSLog(@"o.x : %f", self._matchPoints.x);
//  NSLog(@"v.x : %f", viewCenter.x);
//  NSLog(@"center.y : %f", center.y);
//  NSLog(@"o.y : %f", self._matchPoints.y);
//  NSLog(@"center.x : %f", center.x);
//  NSLog(@"trans.x : %f\n\n", translation.x);
    
    switch (self.dragMode) {
        case krImageViewerModeOfTopToBottom:
            /*
             * 只允許往下移動
             */
            if( translation.y < 0 && viewCenter.y <= 0 ) return;
            //拖拉移動
            if (_panGesture.state == UIGestureRecognizerStateChanged) {
                if( center.x == self._matchPoints.x ){
                    center = CGPointMake(self._matchPoints.x, center.y + translation.y);
                    _panGesture.view.center = center;
                    [_panGesture setTranslation:CGPointZero inView:_panGesture.view];
                    [self _hideDoneButton];
                    //代表沒移動
                    if( center.y == self._matchPoints.y ){
                        [self _appearStatus:NO];
                    }else{
                        [self _appearStatus:YES];
                    }
                    [self _resetBackgroundViewAlpha];
                }
            }
            //結束觸碰
            if(_panGesture.state == UIGestureRecognizerStateEnded){
                CGFloat _screenHeight = self._gestureView.frame.size.height;
                CGFloat _moveDistance = _screenHeight - self.sideInstance;
                [self _appearStatus:NO];
                [self _displayDoneButton];
                //檢查 X 是否已過中線
                if( viewCenter.y > [self _dragDisapperInstance] ){
                    //打開
                    [self _moveView:self._gestureView toX:0.0f toY:_moveDistance];
                    //關閉 Viewer
                    [self stop];
                }else{
                    //回到原點
                    [self _moveView:self._gestureView toX:0.0f toY:0.0f];
                }
            }
            break;
        case krImageViewerModeOfBottomToTop:
            /*
             * 只允許往上移動
             */
            if( translation.y > 0 && viewCenter.y >= 0 ) return;
            //拖拉移動
            if (_panGesture.state == UIGestureRecognizerStateChanged) {
                if( center.x == self._matchPoints.x ){
                    center = CGPointMake(self._matchPoints.x, center.y + translation.y);
                    _panGesture.view.center = center;
                    [_panGesture setTranslation:CGPointZero inView:_panGesture.view];
                    [self _hideDoneButton];
                    //代表沒移動
                    if( center.y == self._matchPoints.y ){
                        [self _appearStatus:NO];
                    }else{
                        [self _appearStatus:YES];
                    }
                    [self _resetBackgroundViewAlpha];
                }
            }
            
            //結束觸碰
            if(_panGesture.state == UIGestureRecognizerStateEnded){
                CGFloat _screenHeight = self._gestureView.frame.size.height;
                CGFloat _moveDistance = -(_screenHeight - self.sideInstance);
                [self _appearStatus:NO];
                [self _displayDoneButton];
                //Open
                if( viewCenter.y < -( [self _dragDisapperInstance] ) ){
                    [self _moveView:self._gestureView toX:0.0f toY:_moveDistance];
                }else{
                    //Close
                    [self _moveView:self._gestureView toX:0.0f toY:0.0f];
                }
            }
            break;
        case krImageViewerModeOfBoth:
            //上下都能拖拉 ( 待修改 Code )
            if (_panGesture.state == UIGestureRecognizerStateChanged) {
                //if( center.x == self._matchPoints.x ){
                    center = CGPointMake(self._matchPoints.x, center.y + translation.y);
                    _panGesture.view.center = center;
                    [_panGesture setTranslation:CGPointZero inView:_panGesture.view];
                    [self _hideDoneButton];
                    if( center.y == self._matchPoints.y ){
                        [self _appearStatus:NO];
                    }else{
                        [self _appearStatus:YES];
                    }
                    [self _resetBackgroundViewAlpha];
                //}
            }
            if(_panGesture.state == UIGestureRecognizerStateEnded){
                CGFloat _screenHeight = self._gestureView.frame.size.height;
                CGFloat _moveDistance = -(_screenHeight - self.sideInstance);
                [self _appearStatus:NO];
                [self _displayDoneButton];
                if( viewCenter.y < -( [self _dragDisapperInstance] ) ){
                    [self _moveView:self._gestureView toX:0.0f toY:_moveDistance];
                }else{
                    [self _moveView:self._gestureView toX:0.0f toY:0.0f];
                }
            }
            break;
        default:
            //...
            break;
    }
}

-(void)_resortKeys{
    if( [self._caches count] > 0 ){
        NSDictionary *_sortedCaches = [self _sortDictionary:self._caches ascending:YES];
        [self._sortedKeys removeAllObjects];
        [self._sortedKeys addObjectsFromArray:[_sortedCaches objectForKey:@"keys"]];
    }
}

-(void)_cancelAllOperations{
    if( self._operationQueues.operationCount > 0 ){
        //self._isCancelled = YES;
        [self._operationQueues cancelAllOperations];
    }
}

/*
 * 下載來自 URL 的圖片
 */
-(void)_downloadImageURLs:(NSDictionary *)_urlInfos{
    [self _cancelAllOperations];
    [self _startLoading];
    //[self._caches removeAllObjects];
    NSInteger _total = [_urlInfos count];
    if( _total > 0 ){
        NSInteger _count = 0;
        for( NSString *_imageKey in _urlInfos ){
            ++_count;
            //如果有快取就不理會
            if( [self._caches objectForKey:_imageKey] ){
                if( _total == _count ){
                    [self _resortKeys];
                    [self start];
                    [self _stopLoading];
                    break;
                }
                continue;
            }
            NSString *_url = [_urlInfos objectForKey:_imageKey];
            //設定 NSOperation
            __block KRImageOperation *_operation = [[KRImageOperation alloc] initWithImageURL:_url];
            _operation.timeout   = self.timeout;
            _operation.cacheMode = [self _findOperationCacheMode];
            //使用 ^Block (設定完成時候的動作)
            [_operation setCompletionBlock:^{
                //寫入快取
                if( _operation.doneImage ){
                    [self._caches setObject:_operation.doneImage forKey:_imageKey];
                    _operation.doneImage = nil;
                }
                //全處理完了 + 是最後一筆
                if( _operationQueues.operationCount == 0 && _total == _count ){
                    //NSLog(@"isCancelled : %i", self._isCancelled);
                    //NSLog(@"wow : operationCount, total, count : %i, %i, %i", self._operationQueues.operationCount, _total, _count);
                    if( !self._isCancelled ){
                        [self _resortKeys];
                        [self start];
                        [self _stopLoading];
                    }
                }
            }];
            //寫入排程
            [_operationQueues addOperation:_operation];
            [_operation release];
        }
    }else{
        [self _stopLoading];
    }
}

-(void)_resetBackgroundViewAlpha{
    //計算比例
    CGFloat _offsetAlpha  = -0.2f;
    CGFloat _screenHeight = self._gestureView.frame.size.height;
    CGFloat _dragHeight   = self._dragView.frame.origin.y;
    CGFloat _diffInstance = fabsf( _dragHeight - _screenHeight );
    CGFloat _alpha        = (_diffInstance / _screenHeight);
    [self._backgroundView setBackgroundColor:[UIColor colorWithRed:_backgroundViewBlackColor
                                                             green:_backgroundViewBlackColor
                                                              blue:_backgroundViewBlackColor
                                                             alpha:_alpha + _offsetAlpha]];
    
}

/*
 * ScrollView
 */
-(void)_scrollViewRemoveAllSubviews{
    for(UIView *subview in [self._scrollView subviews]) {
        [subview removeFromSuperview];
    }
}

-(void)_setupScrollView{
    CGRect _frame = self.view.frame;
    if( !_scrollView ){
        //_frame.size.height = 400.0f;
        _scrollView = [[UIScrollView alloc] init];
    }
    [self._scrollView setFrame:_frame];
    //設定是否啟動分頁機制 : 如不啟動，則會一直滑動不停 ; 如啟動，會一格一格的分頁顯示
    [self._scrollView setPagingEnabled:YES];
    self._scrollView.showsHorizontalScrollIndicator = NO;
    self._scrollView.showsVerticalScrollIndicator   = NO;
    //Scale
    //CGFloat _maxScaleSize = 2.0f;
    self._scrollView.contentMode      = UIViewContentModeCenter;
//    self._scrollView.maximumZoomScale = 2.0f;
//    self._scrollView.minimumZoomScale = 1.0f;
//    self._scrollView.zoomScale        = _maxScaleSize;
//    self._scrollView.clipsToBounds    = YES;
    self._scrollView.delegate         = self;
    self._scrollView.backgroundColor  = [UIColor clearColor];
}

/*
 * 檢查這一支函式 ... 
 */
-(void)_setupImagesInScrollView{
    [self _scrollViewRemoveAllSubviews];
    CGRect _innerFrame = CGRectMake(0.0f,
                                    0.0f,
                                    self._scrollView.frame.size.width,
                                    self._scrollView.frame.size.height);
    for( NSString *_imageKey in self._sortedKeys ){
        UIImage *_image = [self._caches objectForKey:_imageKey];
        KRImageScrollView *_krImageScrollView = [[KRImageScrollView alloc] initWithFrame:_innerFrame];
        _krImageScrollView.maximumZoomScale = self.maximumZoomScale;
        _krImageScrollView.minimumZoomScale = self.minimumZoomScale;
        _krImageScrollView.zoomScale        = self.zoomScale;
        _krImageScrollView.clipsToBounds    = self.clipsToBounds;
        [_krImageScrollView displayImage:_image];
        [self._scrollView addSubview:_krImageScrollView];
        [_krImageScrollView release];
        _innerFrame.origin.x += _innerFrame.size.width;
    }
    [self._scrollView setContentSize:CGSizeMake(_innerFrame.origin.x, _innerFrame.size.height)];
}

/*
 * Test functions ( 待修正 )
 */
-(void)_browseImages{
    if( [self._caches count] > 0 ){
        [self _setupImagesInScrollView];
        [self _scrollToPage:self.scrollToPage];
        [self._dragView addSubview:self._scrollView];
        //
        UIButton *_button = [UIButton buttonWithType:UIButtonTypeCustom];
        [_button setFrame:CGRectMake(self._dragView.frame.size.width - 60.0f, 20.0f, 60.0f, 28.0f)];
        [_button setTag:krBrowseButtonTag];
        [_button setBackgroundColor:[UIColor clearColor]];
        [_button setBackgroundImage:[self _imageNameNoCache:@"btn_done.png"] forState:UIControlStateNormal];
        [_button setTitle:@"完成" forState:UIControlStateNormal];
        [_button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_button.titleLabel setFont:[UIFont boldSystemFontOfSize:14.0f]];
        [_button addTarget:self action:@selector(_removeBrowser:) forControlEvents:UIControlEventTouchUpInside];
        //
        [self._dragView addSubview:_button];
        //
        [self._backgroundView addSubview:self._dragView];
        [self.view addSubview:self._backgroundView];
    }
}

-(void)_removeBrowser:(id)sender{
    //[[(UIButton *)sender superview] removeFromSuperview];
    //[self _appearStatus:YES];
    //[self _removeAllViews];
    [self stop];
}

-(void)_removeAllViews{
    //Remove ImageView's images to release memories.
    for( UIView *_subview in self._backgroundView.subviews ){
        if( [_subview isKindOfClass:[UIImageView class]] ){
            UIImageView *_imageView = (UIImageView *)_subview;
            _imageView.image = nil;
            [_imageView removeFromSuperview];
        }
    }
    [[self._dragView viewWithTag:krBrowseButtonTag] removeFromSuperview];
    [self._backgroundView removeFromSuperview];
    [self._dragView removeFromSuperview];
    //[self.view removeFromSuperview];
}

-(CGFloat)_statusBarHeight{
    return [UIApplication sharedApplication].statusBarFrame.size.height;
}

//
-(void)_startLoading{
    UIView *_targetView = self.view;
    CGRect _frame = CGRectMake(0.0f, 0.0f, _targetView.frame.size.width, _targetView.frame.size.height);
    //
    UIView *_loadingBackgroundView = [[UIView alloc] initWithFrame:_frame];
    [_loadingBackgroundView setTag:krLoadingViewTag];
    [_loadingBackgroundView setBackgroundColor:[UIColor blackColor]];
    [_loadingBackgroundView setAlpha:0.5];
    //
    UIButton *_closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_closeButton setFrame:CGRectMake(_frame.size.width - 60.0f, [self _statusBarHeight], 60.0f, 28.0f)];
    [_closeButton setTag:krLoadingButtonTag];
    [_closeButton setBackgroundColor:[UIColor clearColor]];
    [_closeButton setBackgroundImage:[self _imageNameNoCache:@"btn_done.png"] forState:UIControlStateNormal];
    [_closeButton setTitle:@"取消" forState:UIControlStateNormal];
    [_closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_closeButton.titleLabel setFont:[UIFont boldSystemFontOfSize:14.0f]];
    [_closeButton addTarget:self action:@selector(_cancelAndClose:) forControlEvents:UIControlEventTouchUpInside];
    //
    [_targetView addSubview:_loadingBackgroundView];
    [_loadingBackgroundView release];
    [_targetView addSubview:_closeButton];
    //
    UIActivityIndicatorView *_loadingIndicator = [[UIActivityIndicatorView alloc]
                                                  initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _loadingIndicator.center = CGPointMake(_targetView.bounds.size.width / 2.0f,
                                           _targetView.bounds.size.height / 2.0f);
    [_loadingIndicator setColor:[UIColor whiteColor]];
    [_loadingIndicator startAnimating];
    [_targetView addSubview:_loadingIndicator];
    [_loadingIndicator release];
}

-(void)_stopLoading{
    UIView *_targetView = self.view;
    if( _targetView ){
        for(UIView *subview in [_targetView subviews]) {
            if([subview isKindOfClass:[UIActivityIndicatorView class]]) {
                [(UIActivityIndicatorView *)subview stopAnimating];
                [subview removeFromSuperview];
                break;
            }
        }
    }
    [[_targetView viewWithTag:krLoadingButtonTag] removeFromSuperview];
    [[_targetView viewWithTag:krLoadingViewTag] removeFromSuperview];
}

//隱藏或顯示狀態列
-(void)_appearStatus:(BOOL)_isAppear{
    //if( !self.statusBarHidden ) return;
    UIWindow *_mainWindow = [[UIApplication sharedApplication] keyWindow];
    if( !_isAppear ){
        if( _mainWindow ){
            UIView *_statusView =[[UIView alloc] initWithFrame:[[UIApplication sharedApplication] statusBarFrame]];
            [_statusView setBackgroundColor:[UIColor clearColor]];
            [_statusView setBackgroundColor:[UIColor blackColor]];
            [_statusView setTag:KR_STATUS_BAR_VIEW_TAG];
            [_mainWindow addSubview:_statusView];
            [_mainWindow sendSubviewToBack:_statusView];
            [_statusView release];
        }
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    }else{
        if( [_mainWindow viewWithTag:KR_STATUS_BAR_VIEW_TAG] ){
            [[_mainWindow viewWithTag:KR_STATUS_BAR_VIEW_TAG] removeFromSuperview];
        }
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }
    //self.statusBarHidden = !self.statusBarHidden;
}

-(NSInteger)_currentPage{
    CGFloat pageWidth = self._scrollView.frame.size.width;
    return floor(self._scrollView.contentOffset.x / pageWidth) + 1;
}

-(NSInteger)_currentIndex{
    CGFloat pageWidth = self._scrollView.frame.size.width;
    return floor((self._scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
}

-(void)_scrollToPage:(NSInteger)_toPage{
    NSInteger _scrollToIndex = _toPage > 0 ? _toPage - 1 : 0;
    if( [self._scrollView.subviews count] > 0 ){
        //取出 subviews
        CGRect _scrollToFrame  = [[self._scrollView.subviews objectAtIndex:_scrollToIndex] frame];
        [self._scrollView scrollRectToVisible:_scrollToFrame animated:NO];
    }
}

/*
 *
 * @排序字典陣列，可設定是 ASC 或 DESC 排序
 *   _formatedDatas 的資料必須要將用作排序的值當成資料陣列的 Key 才行 : _formatedDatas[sortKey] = datas，
 *   也就是會預設以字典陣列裡的鍵值作為排序的準則。
 *   回傳的字典陣列裡，會有 2 個陣列值 :
 *   _temps["keys"]   = 所有排序過後的原始 Key 陣列集合
 *   _temps["values"] = 所有排序過後的原始 資料 陣列集合
 *
 */
-(NSDictionary *)_sortDictionary:(NSDictionary *)_formatedDatas ascending:(BOOL)_isAsc{
    NSString *_keyName   = @"keys";
    NSString *_valueName = @"values";
    NSMutableDictionary *_temps = [NSMutableDictionary dictionaryWithCapacity:0];
    if( [_formatedDatas count] > 0 ){
        NSMutableArray *_keys   = [[NSMutableArray alloc] initWithCapacity:0];
        NSMutableArray *_values = [[NSMutableArray alloc] initWithCapacity:0];
        //針對 Key 先做 ASC 排序
        NSMutableArray *_tempSorts = [NSMutableArray arrayWithCapacity:0];
        //要排序比對的儲存 Key
        NSString *_sortKey = @"id";
        for( NSString *_key in _formatedDatas ){
            //字串轉 Integer，非數字會回傳 0
            //NSInteger _keyOfInt = [_key integerValue];
            NSMutableDictionary *_sorts = [[NSMutableDictionary alloc] initWithCapacity:0];
            //如果 _key 是數字型態，就轉化成 NSNumber 物件儲存
            if( [self _isInt:_key] ){
                [_sorts setObject:[NSNumber numberWithInteger:[_key integerValue]] forKey:_sortKey];
            }else{
                [_sorts setObject:_key forKey:_sortKey];
            }
            [_tempSorts addObject:_sorts];
            [_sorts release];
        }
        //設定排序規則，要以什麼「Key」為排序依據( 這裡設定取出陣列裡 Key 命名為 "id" 的值做排序 ), ascending ( ASC )
        NSSortDescriptor *_sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:_sortKey ascending:_isAsc];
        //依排序排則針對 _tempSorts 做排序的動作
        NSArray *_sorteds = [_tempSorts sortedArrayUsingDescriptors:[NSArray arrayWithObject:_sortDescriptor]];
        //依序取出內容值，放入 Keys 主鍵集合裡
        for( NSDictionary *_dicts in _sorteds ){
            [_keys addObject:[NSString stringWithFormat:@"%@", [_dicts objectForKey:_sortKey]]];
        }
        //依照排序好的 Keys 主鍵集合再依序取出所屬資料即完成整個排序動作
        for( NSString *_key in _keys ){
            //製作 UIPickerView 的資料
            [_values addObject:[_formatedDatas objectForKey:_key]];
        }
        [_temps setObject:_keys forKey:_keyName];
        [_temps setObject:_values forKey:_valueName];
        [_keys release];
        [_values release];
    }
    return _temps;
}

//判斷是否為純整數
-(BOOL)_isInt:(NSString*)_string{
    int _number;
    NSScanner *_scanner = [NSScanner scannerWithString:_string];
    return [_scanner scanInt:&_number] && [_scanner isAtEnd];
}

-(void)_refreshCaches{
    [self _cancelAllOperations];
    [self._caches removeAllObjects];
}

-(void)_disapperAsSuckEffect{
    //精靈消失效果
	CATransition *transition = [CATransition animation];
	transition.delegate = self;
	transition.duration = self.durations;
	transition.type     = @"suckEffect";
	transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	[[self.view layer] addAnimation:transition forKey:@"suckAnim"];
    [[self.view layer] display];
    //[self dismissViewControllerAnimated:YES completion:nil];
}

-(NSInteger)_findOperationCacheMode{
    return self.allowOperationCaching ? KRImageOperationAllowCache : KRImageOperationIgnoreCache;
}

-(void)_cancelAndClose:(id)sender{
    self._isCancelled = YES;
    [self _cancelAllOperations];
    [self _stopLoading];
    [self _appearStatus:YES];
    [self _removeViewDragGesture];
    [self _removeAllViews];
    [self _moveView:self._gestureView toX:0.0f toY:0.0f];
    //[self _removeBrowser:sender];
}

-(UIImage *)_imageNameNoCache:(NSString *)_imageName{
    return [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] bundlePath], _imageName]];
}

/*
 * @ 從 image_id 找出 Scroll to Page Index
 */
-(NSString *)_findImageIndexWithId:(NSString *)_imageId{
    NSInteger _index = 0;
    if( _imageId ){
        for( NSString *_key in self._sortedKeys ){
            if( [_key isEqualToString:_imageId] ){
                break;
            }
            ++_index;
        }
    }
    return [NSString stringWithFormat:@"%i", _index];
}

@end


@implementation KRImageViewer

@synthesize _orignalPoints;
@synthesize _matchPoints;
@synthesize _panGestureRecognizer;
@synthesize _gestureView;
@synthesize _operationQueues;
@synthesize _backgroundView;
@synthesize _dragView;
@synthesize _scrollView;
@synthesize _caches;
@synthesize _sortedKeys;
@synthesize _imageInfos;

@synthesize view;
@synthesize dragMode;
@synthesize dragDisapperMode;
@synthesize allowOperationCaching;
@synthesize sideInstance;
@synthesize durations;
@synthesize maxConcurrentOperationCount;
@synthesize statusBarHidden;
@synthesize scrollToPage;
@synthesize maximumZoomScale;
@synthesize minimumZoomScale;
@synthesize zoomScale;
@synthesize clipsToBounds;
@synthesize timeout;


-(id)init{
    self = [super init];
    if( self ){
        self.view     = nil;
        self.dragMode = krImageViewerModeOfTopToBottom;
        [self _initWithVars];
        [self _resetViewVars];
    }
    return self;
}

-(id)initWithParentView:(UIView *)_parentView dragMode:(krImageViewerModes)_dragMode{
    self = [super init];
    if( self ){
        self.view     = _parentView;
        self.dragMode = _dragMode;
        [self _initWithVars];
        [self _resetViewVars];
        [self _allocPanGesture];
    }
    return self;
}

-(id)initWithDragMode:(krImageViewerModes)_dragMode{
    self = [super init];
    if( self ){
        self.view     = nil;
        self.dragMode = _dragMode;
        [self _initWithVars];
        [self _resetViewVars];
        [self _allocPanGesture];
    }
    return self;
}

-(void)dealloc{
    //NSLog(@"KRImageViewer Dealloc");
    
    [view release];
    
    [self._caches removeAllObjects];
    self._caches = nil;
    [_caches release];
    
    [_sortedKeys release];
    [_imageInfos release];
    [_panGestureRecognizer release];
    
    self._operationQueues = nil;
    [_operationQueues release];
    [_backgroundView release];
    [_dragView release];
    
    [self _scrollViewRemoveAllSubviews];
    self._scrollView = nil;
    [_scrollView release];
    
    [super dealloc];
}

#pragma My Methods
-(void)cancel{
    [self _refreshCaches];
}

-(void)start{
    self._isCancelled = NO;
    [self _appearStatus:NO];
    [self _addViewDragGesture];
    [self _browseImages];
}

-(void)stop{
    [self _appearStatus:YES];
    [self _removeViewDragGesture];
    [self _disapperAsSuckEffect];
    [self _removeAllViews];
    //回原點
    [self _moveView:self._gestureView toX:0.0f toY:0.0f];
}

-(void)resetView:(UIView *)_parentView withDragMode:(krImageViewerModes)_dragMode{
    self.view     = _parentView;
    self.dragMode = _dragMode;
    [self _resetViewVars];
}

-(void)resetView:(UIView *)_parentView{
    [self resetView:_parentView withDragMode:self.dragMode];
}

-(void)refresh{
    [self _appearStatus:YES];
    [self _removeViewDragGesture];
    [self _removeAllViews];
    [self _initWithVars];
    [self _allocPanGesture];
    [self _refreshCaches];
}

-(void)pause{
    self._isCancelled = YES;
    [self _appearStatus:YES];
    //暫停佇列處理
    [self._operationQueues setSuspended:YES];
}

-(void)restart{
    self._isCancelled = NO;
    [self _appearStatus:NO];
    //繼續佇列處理
    [self._operationQueues setSuspended:NO];
}

-(void)preloadImageURLs:(NSDictionary *)_preloadImages{
    self._isCancelled = NO;
    self._operationQueues.maxConcurrentOperationCount = 1;
    for( NSString *_imageKey in _preloadImages ){
        NSString *_url = [_preloadImages objectForKey:_imageKey];
        __block KRImageOperation *_operation = [[KRImageOperation alloc] initWithImageURL:_url];
        _operation.timeout   = self.timeout;
        _operation.cacheMode = [self _findOperationCacheMode];
        [_operation setCompletionBlock:^{
            if( _operation.doneImage ){
                [self._caches setObject:_operation.doneImage forKey:_imageKey];
                _operation.doneImage = nil;
            }
            if( _operationQueues.operationCount == 0 ){
                [self _resortKeys];
            }
        }];
        [_operationQueues addOperation:_operation];
        [_operation release];
    }
}

-(void)browseAnImageURL:(NSString *)_imageURL{
    self._isCancelled = NO;
    [self _downloadImageURLs:[NSDictionary dictionaryWithObject:_imageURL forKey:@"0"]];
}

-(void)browseImageURLs:(NSDictionary *)_browseURLs{
    self._isCancelled = NO;
    self._operationQueues.maxConcurrentOperationCount = self.maxConcurrentOperationCount;
    [self _downloadImageURLs:_browseURLs];
}

-(void)browseImages:(NSArray *)_images{
    self._isCancelled = NO;
    [self._caches removeAllObjects];
    NSInteger _index = 0;
    for( UIImage *_image in _images ){
        [self._caches setObject:_image forKey:[NSString stringWithFormat:@"%i", _index]];
        ++_index;
    }
    [self _resortKeys];
    [self start];
    [self._caches removeAllObjects];
}

-(void)findImageIndexWithId:(NSString *)_imageId{
    self.scrollToPage = [[self _findImageIndexWithId:_imageId] integerValue];
}

-(void)findImageScrollPageWithId:(NSString *)_imageId{
    self.scrollToPage = [[self _findImageIndexWithId:_imageId] integerValue] + 1;
}

#pragma UIScrollView Delegate
-(void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)_subview{
    
}

-(UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView{
    return nil;
}

//縮放結束
-(void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)_subview atScale:(float)scale{

}



@end
