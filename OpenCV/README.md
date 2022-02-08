# OpencvQueen

<font color=red size=3>Set of **Extensions** and **Custom control** for standard types and classes.</font>  
<font color=red>Just like Doraemon’s pocket, has an endless variety of props for us to use.</font>

---

- [x] OpenCV: Hough correction, feature extraction, image processing package, morphological processing, filter processing, photo restoration, etc.

### <a id="Catalogue list"></a>Catalogue list ###
- **[OpenCV](#OpenCV)**

### Methods and Functions
- <a id="OpenCV"></a>Opencv picture processing.

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

### CocoaPods
- If you want use this framework.☠️

```
pod 'OpencvQueen'
```

----

#### Ex
* <font color=red size=4>Download demo please execute first `pod install`</font>

### Remarks

> The general process is almost like this, the Demo is also written in great detail, you can check it out for yourself.🎷
>
> [**OpencvQueenDemo**](https://github.com/yangKJ/MetalQueen)
>
> Tip: If you find it helpful, please help me with a star. If you have any questions or needs, you can also issue.
>
> Thanks.🎇

### About the author
- 🎷 **E-mail address: [yangkj310@gmail.com](yangkj310@gmail.com) 🎷**
- 🎸 **GitHub address: [yangKJ](https://github.com/yangKJ) 🎸**

-----

### License
OpencvQueen is available under the [MIT](LICENSE) license. See the [LICENSE](LICENSE) file for more info.

-----
