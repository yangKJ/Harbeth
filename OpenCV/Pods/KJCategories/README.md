# KJCategories

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/yangKJ/KJCategories)
[![Releases Compatible](https://img.shields.io/github/release/yangKJ/KJCategories.svg?style=flat&label=Releases&colorA=28a745&&colorB=4E4E4E)](https://github.com/yangKJ/KJCategories/releases)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/KJCategories.svg?style=flat&label=CocoaPods&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/KJCategories)
[![Platform](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS-4E4E4E.svg?colorA=28a745)](#installation)

<p align="left">
<img src="https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/5ce8643f68c74fc2be80b22204268f65~tplv-k3u1fbpfcp-watermark.image?" width="800" hspace="1px">
</p>

<font color=red size=3>Set of **Extensions** and **Custom control** for standard types and classes.</font>  
<font color=red>Just like Doraemon’s pocket, has an endless variety of props for us to use.</font>

English | [简体中文](https://github.com/yangKJ/KJCategories/blob/master/README_CN.md)

---

- [x] OpenCV: Hough correction, feature extraction, image processing package, morphological processing, filter processing, photo restoration, etc.
- [x] NSArray: Related processing of the elements in the array, etc.
- [x] NSDate: Time transformation, etc.
- [x] UIButton: Emitter animation, image and text mixing, click event encapsulation, expanded click field, time interval limit, countdown, click particle effect, etc.
- [x] UIView: Gesture package, rounded corner gradient, Xib attribute, basic animation package, etc.
- [x] UITextView: Expand the input box, limit the number of words, cancel processing, get the internal hyperlink of the text, etc.
- [x] UITextField: Placeholder color, line, graphic processing, etc.
- [x] UILabel: Rich text, fast display text position, etc.
- [x] UIImage: Screenshot and cropping, image compression, mask processing, image stitching, image size processing, filter rendering, flooding algorithm, etc.
- [x] UIImage: QR code, barcode generation, dynamic image playback, watermark processing, etc.
- [x] NSObject: GCD, asynchronous timer, resident thread, thread keep alive, runtime methods, etc.
- [x] NSString: Hash crypto, mathematical operators, unit conversion, etc.
- [x] Other: Gradient slider, Open screen particle animation, projection and shadow, etc.

##### Encapsulation exception Handling [KJExceptionDemo](https://github.com/yangKJ/KJExceptionDemo)
##### Quick creation of chained UI controls [ChainThen](https://github.com/yangKJ/ChainThen)

### <a id="Catalogue list"></a>Catalogue list ###
- **[OpenCV](#OpenCV)**
- **[NSArray](#NSArray)**
- **[NSDate](#NSDate)**
- **[NSDictionary](#NSDictionary)**
- **[NSObject](#NSObject)**
- **[NSString](#NSString)**
- **[UIButton](#UIButton)**
- **[UIColor](#UIColor)**
- **[UIDevice](#UIDevice)**
- **[UIImage](#UIImage)**
- **[UILabel](#UILabel)**
- **[UISlider](#UISlider)**
- **[UITextField](#UITextField)**
- **[UITextView](#UITextView)**
- **[UIView](#UIView)**
- **[UIViewController](#UIViewController)**

### Methods and Functions
#### <a id="OpenCV"></a>OpenCV ####
- Opencv picture processing.

| Name | Signatures | 
| :---- | ---- |
| Picture Tile | kj_opencvTiledRows:cols: |
| Four-point perspective image based on perspective | kj_opencvWarpPerspectiveWithKnownPoints:size: |
| Eliminate image highlights | kj_opencvIlluminationChangeBeta:alpha: |
| Picture Blending | kj_opencvBlendImage:alpha: |
| Adjust picture brightness and contrast | kj_opencvChangeContrast:luminance: |
| Modify the color of the picture channel value | kj_opencvChangeR:g:b: |
| Blur processing | kj_opencvBlurX:y: |
| Gaussian Blur | kj_opencvGaussianBlurX:y: |
| Median Blur | kj_opencvMedianBlurksize: |
| Gaussian Bilateral Blur | kj_opencvBilateralFilterBlurRadio:sigma: |
| Custom linear blur | kj_opencvCustomBlurksize: |
| Morphology operations | kj_opencvMorphology:element: |
| Remove watermark | kj_opencvInpaintImage: |
| Picture repair, effect enhancement processing | kj_opencvRepairImage |
| Cut out the largest inner rectangular area | kj_opencvCutMaxRegionImage |
| Feature extraction | kj_opencvFeatureExtractionFromSobel |
| Hough line judgment and correction | kj_opencvHoughLinesCorrectTextImageFillColor: |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="NSArray"></a>NSArray ####
- Related processing of the elements in the array.

| Name | Signatures | 
| ---- | ---- | 
| Is it empty| isEmpty | 
| Filter data | kj_detectArray: | 
| Multidimensional array data | kj_detectManyDimensionArray: | 
| Search data | kj_searchObject: | 
| Map | kj_mapArray: | 
| Insert data to the destination | kj_insertObject: | 
| Array calculation intersection | kj_arrayIntersectionWithOtherArray: | 
| Array calculation difference| kj_arrayMinusWithOtherArray: | 
| Randomly Disorganize Array | kj_disorganizeArray | 
| Delete the same element in the array| kj_delArrayEquelObj | 
| Binary Search| kj_binarySearchTarget: | 
| Bubble Sort| kj_bubbleSort | 
| Insert Sort | kj_insertSort | 
| Selection Sort| kj_selectionSort | 

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="NSDate"></a>NSDate ####
- Time transformation.

| Name | Signatures | 
| ---- | ---- | 
| Convert date to local time | kj_localeDate |
| Time string conversion NSDate | kj_dateFromString: |
| Time string to NSDate | kj_dateFromString:format: |
| Get the current timestamp | kj_currentTimetampWithMsec: |
| Timestamp to time | kj_timeWithTimestamp:format: |
| Get the UTC timestamp of the specified time | kj_timeStampUTCWithTimeString: |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="NSDictionary"></a>NSDictionary ####
- Dictionary common methods.

| Name | Signatures |
| ---- | ---- |
| Is it empty | isEmpty |
| Convert to Josn String | jsonString |
| Whether to include a key | kj_containsKey: |
| Dictionary keys in ascending order | kj_keysSorted |
| Dictionary key name descending order | kj_keySortDescending |
| Quickly traverse the dictionary | kj_applyDictionaryValue: |
| Mapping | kj_mapDictionary: |
| Merge | kj_mergeDictionary: |
| Selector | kj_pickForKeys: |
| Remover | kj_omitForKeys: |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="UIView"></a>UIView ####
- Advanced Edition Rounded Corners and Border Extension.

| Name | Signatures |
| ---- | ---- |
| Bezier Fillet | bezierRadius |
| Shadow Offset | shadowOffset |
| Shadow Opacity | shadowOpacity |
| Shadow Width | shadowWidth |
| Shadow rounded corners | shadowRadius |
| Shadow Color | shadowColor |
| Corner Radius | cornerRadius |
| Border Width | borderWidth |
| Border Color | borderColor |
| Image properties | viewImage |
| Top Controller | topViewController |
| Current Controller | viewController |
| Current Controller | kj_currentViewController |
| View created by Xib | kj_viewFromXib |
| View created by Xib | kj_viewFromXibWithFrame: |
| Fillet radius | kj_radius |
| Rounded corner orientation | kj_rectCorner |
| Border Color | kj_borderColor |
| Border width | kj_borderWidth |
| Border Orientation | kj_borderOrientation |
| Size | size |
| Location | origin |
| x coordinate | x |
| y coordinate | y |
| Width | width |
| Height | height |
| Center point x | centerX |
| Center point y | centerY |
| Left distance | left |
| Right distance | right |
| Top distance | top |
| Bottom distance | bottom |
| x + width | maxX |
| y + height | Property |maxY |
| After Masonry layout x | masonry_x |
| After Masonry layout y | masonry_y |
| Masonry width after layout | masonry_width |
| Masonry height after layout | masonry_height |
| Center the view in its parent view | kj_centerToSuperview |
| Distance from the right of the parent view | kj_rightToSuperview: |
| Distance from the bottom of the parent view | kj_bottomToSuperview: |
| Get the highest Y of the subview | kj_subviewMaxY |
| Get the highest X of the subview | kj_subviewMaxX |
| Find Subview | kj_FindSubviewRecursively: |
| Remove all subviews | kj_removeAllSubviews |
| Hide/Show all subviews | kj_hideSubviews:operation: |
| Child controls handle gesture events | kj_childHitTest:withEvent: |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="UITextView"></a>UITextView ####
- UITextView undo processing, equivalent to command + z, limit processing.

| Name | Signatures |
| ---- | ---- |
| Whether to enable the undo function | kOpenBackout |
| Cancel input | kj_textViewBackout |
| Placeholder text | placeHolder |
| Placeholder Label | placeHolderLabel |
| Limit word count | limitCount |
| Right margin of restricted area | limitMargin |
| Restricted area height | limitHeight |
| Statistics limit the number of words Label | limitLabel |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="UITextField"></a>UITextField ####
- UITextField input box extension, placeholder, quick setting account password box.

| Name | Signatures |
| ---- | ---- |
| Set the bottom border line color | bottomLineColor |
| Placeholder Color | placeholderColor |
| PlaceholderFontSize | placeholderFontSize |
| Maximum Length | maxLength |
| Clear text to dark text switch | securePasswords |
| Maximum character length reached | kMaxLengthBolck |
| Text editing moment callback | kTextEditingChangedBolck |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="UILabel"></a>UILabel ####
- UILabel add long press copy function, Get text position and size.

| Name | Signatures |
| ---- | ---- |
| Can copy | copyable |
| Remove copy long press gesture | kj_removeCopyLongPressGestureRecognizer |
| Set the display position of the text content | customTextAlignment |
| Get width | kj_calculateWidth |
| Get height | kj_calculateHeightWithWidth: |
| Get height, specify line height | kj_calculateHeightWithWidth:OneLineHeight: |
| The text line spacing between Ranges | kj_AttributedStringTextLineSpace: |
| Text size between ranges | kj_AttributedStringTextFont:Range: |
| Text color between Ranges | kj_AttributedStringTextColor:Range: |
| Text size and color between Ranges | kj_AttributedStringTextFont:TextColor:Range: |
| Text related attributes between Ranges | kj_AttributedStringTextAttributes:Range: |
| Rich text text size | kj_AttributedStringTextFont:Loc:Len: |
| Rich text text color | kj_AttributedStringTextColor:Loc:Len: |
| Rich text text size and color | kj_AttributedStringTextFont:TextColor:Loc:Len: |
| Rich text related attributes | kj_AttributedStringTextAttributes:Loc:Len: |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="UIImage"></a>UIImage ####
- QR code and barcode generator, image size, screenshot and crop processing, Picture cropper.

| Name | Signatures |
| ---- | ---- |
| Convert a string to a barcode | kj_barCodeImageWithContent: |
| Generate QR Code | kj_QRCodeImageWithContent:codeImageSize: |
| Generate QR Code with Specified Color | kj_QRCodeImageWithContent:codeImageSize:color: |
| Generate barcode | kj_barcodeImageWithContent:codeImageSize: |
| Generate barcode with specified color | kj_barcodeImageWithContent:codeImageSize:color: |
| Change the image size, bitmap mode | kj_bitmapChangeImageSize: |
| Change the internal pixel color of the image | kj_changeImagePixelColor: |
| Get network image size | kj_imageSizeWithURL: |
| Scale the image by scale | kj_scaleImage: |
| Scale the image with a fixed width | kj_scaleWithFixedWidth: |
| Scale the image with a fixed height | kj_scaleWithFixedHeight: |
| Change the image size proportionally | kj_cropImageWithAnySize: |
| Reduce the image size proportionally | kj_zoomImageWithMaxSize: |
| Do not pull up the filling image | kj_fitImageWithSize: |
| Screenshot of the current view | kj_captureScreen: |
| Specified location screen capture | kj_captureScreen:Rect: |
| Customized quality screenshots, quality multiples | kj_captureScreen:Rect:Quality: |
| Capture the current screen | kj_captureScreenWindow |
| Capture the long image of the scroll view | kj_captureScreenWithScrollView:ContentOffset: |
| Cut out the transparent part around the picture | kj_cutImageRoundAlphaZero: |
| Irregular graphics cutting | kj_anomalyCaptureImageWithView:BezierPath: |
| Polygon Cut Image | kj_polygonCaptureImageWithImageView:PointArray: |
| Specified area crop | kj_cutImageWithImage:Frame: |
| quartz 2d to achieve cropping | kj_quartzCutImageWithImage:Frame: |
| Image path clipping, clipping path "outside" part | kj_captureOuterImage:BezierPath:Rect: |
| Image path clipping, clipping path "within" part | kj_captureInnerImage:BezierPath:Rect: |
| Picture Rotation | kj_rotateInRadians: |
| Specified color linear blur | kj_blurImageWithTintColor: |
| Linear blur, keep transparent area | kj_linearBlurryImageBlur: |
| Blur processing | kj_blurImageWithRadius:Color:MaskImage: |
| Equalization calculation | kj_equalizationImage |
| Erosion | kj_erodeImage |
| Form expansion| kj_dilateImage |
| Multiple erosion | kj_erodeImageWithIterations: |
| Multiple expansion of form | kj_dilateImageWithIterations: |
| Gradient | kj_gradientImageWithIterations: |
| Top Hat Computing | kj_tophatImageWithIterations: |
| Black Hat Computing | kj_blackhatImageWithIterations: |
| Convolution processing | kj_convolutionImageWithKernel: |
| Sharpen | kj_sharpenImage |
| Relief | kj_embossImage |
| Gauss | kj_gaussianImage |
| Edge Detection | kj_marginImage |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="UIDevice"></a>UIDevice ####
- UIDevice system related operations.

| Name | Signatures |
| ---- | ---- |
| App version number | appCurrentVersion |
| App Name | appName |
| Mobile UUID | deviceID |
| Get App Icon | appIcon |
| Get launch page image | launchImage |
| System startup map cache path | launchImageCachePath |
| Launch Image Backup File Path | launchImageBackupPath |
| Generate launch image | kj_launchImageWithPortrait:Dark: |
| Generate launch diagram | kj_launchImageWithStoryboard:Portrait:Dark: |
| Comparison version number | kj_comparisonVersion: |
| Jump to the specified URL | kj_openURL: |
| Call AppStore | kj_skipToAppStoreWithAppid: |
| Call the built-in browser safari | kj_skipToSafari |
| Call the built-in Mail | kj_skipToMail |
| Whether to switch to speaker | kj_changeLoudspeaker: |
| Save to Album | kj_savedPhotosAlbumWithImage:Complete: |
| System comes with sharing | kj_shareActivityWithItems:ViewController:Complete: |
| Switch Root View Controller | kj_changeRootViewController:Complete: |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="UIColor"></a>UIColor ####
- UIColor related extension.

| Name | Signatures |
| ---- | ---- |
| UIColor to hexadecimal string | kj_hexString |
| Hexadecimal string to UIColor | kj_colorWithHexString: |
| red | red |
| green | green |
| blue | blue |
| alpha | alpha |
| Hue | hue |
| Saturation | saturation |
| Brightness | light |
| Get the RGBA corresponding to the color | kj_colorGetRGBA |
| Get the average value of colors | kj_averageColors: |
| Vertical gradient color | kj_gradientVerticalToColor:height: |
| Horizontal gradient color | kj_gradientAcrossToColor:width: |
| Get the color of a specified point on the image | kj_colorAtImage:Point: |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="UIButton"></a>UIButton ####
- UIButton click event block, mixed graphics and text, enlarge click.

| Name | Signatures |
| ---- | ---- |
| Add click event | kj_addAction: |
| Click Event Interval | timeInterval |
| Expand the unified click field | enlargeClick |
| Graphic style | layoutType |
| Picture and text spacing | padding |
| The spacing of the graphic borders | periphery |
| Picture and text spacing | kj_contentLayout:padding: |
| Picture and text spacing | kj_contentLayout:padding:periphery: |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="UISlider"></a>UISlider ####
- Rainbow gradient color slider.

| Name | Signatures |
| ---- | ---- |
| Color array | colors |
| Location information corresponding to each color | locations |
| Color height | colorHeight |
| Border Width | borderWidth |
| Border Color | borderColor |
| Callback processing time | timeSpan |
| Current progress, for external kvo | progress |
| Moving block | movingWithTimeSpan:withBlock: |
| Moved block | moveEndBlock: |
| Reset UI | updateUI |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

#### <a id="UIViewController"></a> UIViewController ####
- Switch view controller.

| Name | Signatures |
| ---- | ---- |
| Jump back to the specified controller | kj_popTargetViewController:complete: |
| Switch Root View Controller | kj_changeRootViewController: |

☝ **[Return to the catalogue list](#Catalogue list)** ☝

### CocoaPods Install

```
Example import core module:
- pod 'KJCategories'

Example import UIBezierPath:
- pod 'KJCategories/UIKit/UIBezierPath'

Example import NSArray:
- pod 'KJCategories/Foundation/NSArray'

Example import opencv2 picture processing:
- pod 'KJCategories/Opencv'

Example import GradientSlider:
- pod 'KJCategories/Customized/GradientSlider'
```

----

#### Ex
* <font color=red size=4>Download demo please execute first `pod install`</font>

## License

KJCategories is available under the MIT license. See the LICENSE file for more info.
