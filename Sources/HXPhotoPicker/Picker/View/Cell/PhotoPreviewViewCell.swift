//
//  PhotoPreviewViewCell.swift
//  HXPhotoPicker
//
//  Created by Silence on 2020/11/13.
//  Copyright © 2020 Silence. All rights reserved.
//

import UIKit
import Photos
import PhotosUI
import ImageIO

protocol PhotoPreviewViewCellDelegate: AnyObject {
    func cell(singleTap cell: PhotoPreviewViewCell)
    func cell(longPress cell: PhotoPreviewViewCell)
    func cell(requestSucceed cell: PhotoPreviewViewCell)
    func cell(requestFailed cell: PhotoPreviewViewCell)
    func photoCell(networkImagedownloadSuccess photoCell: PhotoPreviewViewCell)
    func photoCell(networkImagedownloadFailed photoCell: PhotoPreviewViewCell)
}

open class PhotoPreviewViewCell: UICollectionViewCell, UIScrollViewDelegate {
    
    public var photoAsset: PhotoAsset! {
        didSet {
            setupScrollViewContentSize()
            scrollContentView.photoAsset = photoAsset
        }
    }
    public var scrollView: UIScrollView!
    public var scrollContainerView: UIView! { scrollContentView }
    public var imageView: UIImageView { scrollContentView.imageView }
    public func showScrollContainerSubview() { scrollContentView.showOtherSubview() }
    public func hideScrollContainerSubview() { scrollContentView.hiddenOtherSubview() }
    
    weak var delegate: PhotoPreviewViewCellDelegate?
    
    var scrollContentView: PhotoPreviewContentViewProtocol!
    
    var statusBarShouldBeHidden = false
    var allowInteration: Bool = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initView() {
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 3
        scrollView.isMultipleTouchEnabled = true
        scrollView.scrollsToTop = false
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.alwaysBounceVertical = false
        scrollView.autoresizingMask = UIView.AutoresizingMask.init(arrayLiteral: .flexibleWidth, .flexibleHeight)
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        let singleTap = UITapGestureRecognizer.init(target: self, action: #selector(singleTap(tap:)))
        scrollView.addGestureRecognizer(singleTap)
        let doubleTap = UITapGestureRecognizer.init(target: self, action: #selector(doubleTap(tap:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.numberOfTouchesRequired = 1
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(doubleTap)
        scrollView.addSubview(scrollContentView)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressClick(longPress:)))
        scrollView.addGestureRecognizer(longPress)
        contentView.addSubview(scrollView)
    }
    
    func checkContentSize() {
        if !UIDevice.isPortrait {
            return
        }
        if scrollContentView.width != width {
            if UIDevice.isPad  {
                setupLandscapeContentSize()
            }else {
                setupPortraitContentSize()
            }
        }
    }
    func setupScrollViewContentSize() {
        scrollView.zoomScale = 1
        if UIDevice.isPortrait && !UIDevice.isPad {
            setupPortraitContentSize()
        }else {
            setupLandscapeContentSize()
        }
    }
    func setupPortraitContentSize() {
        let imageSize = photoAsset.imageSize
        let aspectRatio = width / imageSize.width
        var contentWidth: CGFloat
        var contentHeight: CGFloat
        var scrollContentView_x: CGFloat
        var scrollContentView_y: CGFloat
        if photoAsset.isHorizontalLongPicture {
            let showHeight = imageSize.height / imageSize.width * width
            let maximumZoomScale = height / showHeight
            scrollView.maximumZoomScale = maximumZoomScale
            contentWidth = width
            contentHeight = imageSize.height * aspectRatio
            scrollContentView_x = 0
            scrollContentView_y = (height - contentHeight) * 0.5
        } else if photoAsset.isVerticalLongPicture {
            scrollView.maximumZoomScale = 3
            contentWidth = width * 0.5
            contentHeight = imageSize.height * aspectRatio * 0.5
            scrollContentView_x = (width - contentWidth) * 0.5
            scrollContentView_y = 0
        } else {
            scrollView.maximumZoomScale = 3
            contentWidth = width
            contentHeight = imageSize.height * aspectRatio
            scrollContentView_x = 0
            scrollContentView_y = (height - contentHeight) * 0.5
        }
        scrollContentView.frame = CGRect(
            x: scrollContentView_x,
            y: scrollContentView_y,
            width: contentWidth,
            height: contentHeight
        )
        scrollView.contentSize = CGSize(
            width: max(contentWidth, width),
            height: max(contentHeight, height)
        )
    }
    func setupLandscapeContentSize() {
        let imageSize = photoAsset.imageSize
        let aspectRatio = height / imageSize.height
        var contentWidth = imageSize.width * aspectRatio
        var contentHeight = height
        if contentWidth > width {
            contentHeight = width / contentWidth * contentHeight
            contentWidth = width
            scrollContentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
            scrollView.contentSize = scrollContentView.size
        }else {
            scrollContentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
            scrollView.contentSize = size
        }
        scrollContentView.center = CGPoint(x: width * 0.5, y: height * 0.5)
        if imageSize.width >= imageSize.height * 2 {
            let showHeight = imageSize.height / imageSize.width * width
            let maximumZoomScale = height / showHeight
            scrollView.maximumZoomScale = maximumZoomScale
        } else {
            scrollView.maximumZoomScale = 3
        }
    }
    func requestPreviewAsset() {
        scrollContentView.requestPreviewAsset()
    }
    func cancelRequest() {
        scrollContentView.cancelRequest()
    }
    @objc func singleTap(tap: UITapGestureRecognizer) {
        delegate?.cell(singleTap: self)
    }
    @objc func doubleTap(tap: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1 {
            scrollView.maximumZoomScale = 3
            scrollView.setZoomScale(1, animated: true)
        }else {
            let imageSize = photoAsset.imageSize
            if imageSize.width >= imageSize.height * 2 {
                // 横长图：放大高度 = cell高度
                // 初始显示高度
                let showHeight = imageSize.height / imageSize.width * width
                // 放大倍数
                let maximumZoomScale = height / showHeight
                scrollView.maximumZoomScale = maximumZoomScale
                let touchPoint = tap.location(in: scrollContentView)
                let zoomWidth = width / maximumZoomScale
                let zoomHeight = height / maximumZoomScale
                scrollView.zoom(
                    to: CGRect(
                        x: touchPoint.x - zoomWidth / 2,
                        y: touchPoint.y - zoomHeight / 2,
                        width: zoomWidth,
                        height: zoomHeight
                    ),
                    animated: true
                )
            } else {
                // 放大倍数
                scrollView.maximumZoomScale = 3
                let maximumZoomScale: CGFloat = 2
                let touchPoint = tap.location(in: scrollContentView)
                let zoomWidth = width / maximumZoomScale
                let zoomHeight = height / maximumZoomScale
                scrollView.zoom(
                    to: CGRect(
                        x: touchPoint.x - zoomWidth / 2,
                        y: touchPoint.y - zoomHeight / 2,
                        width: zoomWidth,
                        height: zoomHeight
                    ),
                    animated: true
                )
            }
        }
    }
    @objc func longPressClick(longPress: UILongPressGestureRecognizer) {
        if longPress.state == .began {
            delegate?.cell(longPress: self)
        }
    }
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollContentView
    }
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = (scrollView.width > scrollView.contentSize.width) ?
            (scrollView.width - scrollView.contentSize.width) * 0.5 : 0.0
        let offsetY = (scrollView.height > scrollView.contentSize.height) ?
            (scrollView.height - scrollView.contentSize.height) * 0.5 : 0.0
        scrollContentView.center = CGPoint(
            x: scrollView.contentSize.width * 0.5 + offsetX,
            y: scrollView.contentSize.height * 0.5 + offsetY
        )
    }
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !scrollView.isTracking && scrollView.isDecelerating {
            allowInteration = false
        }
    }
//    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
//        if decelerate && scrollView.contentOffset.y >= -20 {
//            allowInteration = true
//        }
//    }
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y >= -40 {
            allowInteration = true
        }
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        if !scrollView.frame.equalTo(bounds) {
            scrollView.frame = bounds
        }
    }
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        cancelRequest()
    }
}
