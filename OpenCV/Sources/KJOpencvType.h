//
//  KJOpencvType.h
//  MetalQueen
//
//  Created by 77。 on 2021/3/20.
//

#ifndef KJOpencvType_h
#define KJOpencvType_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//  A ---- B
//  |      |
//  |      |
//  D ---- C
// Four points of perspective selection, the style is as above
typedef struct KJKnownPoints {
    CGPoint PointA;
    CGPoint PointB;
    CGPoint PointC;
    CGPoint PointD;
} KJKnownPoints;

// line, start -> end
typedef struct KJLine {
    CGPoint start;
    CGPoint end;
} KJLine;

NS_INLINE KJLine KJLineMake(CGPoint start, CGPoint end) {
    KJLine line;
    line.start = start;
    line.end = end;
    return line;
}

NS_INLINE CGPoint kPoint(CGFloat x, CGFloat y) {
    return CGPointMake(x, y);
}

/// Convert perspective point
NS_INLINE KJKnownPoints KJKnownPointsMake(CGPoint A, CGPoint B, CGPoint C, CGPoint D) {
    KJKnownPoints points;
    points.PointA = A;
    points.PointB = B;
    points.PointC = C;
    points.PointD = D;
    return points;
}

/// Morphological operation
typedef NS_ENUM(NSInteger, KJOpencvMorphologyStyle) {
    KJOpencvMorphologyStyleOPEN = 0,/// Open operation, first corroded and then expanded, small objects can be removed
    KJOpencvMorphologyStyleCLOSE,   /// Close operation, first expand and then corrode, can fill small holes
    KJOpencvMorphologyStyleGRADIENT,/// Morphology gradient, expansion minus corrosion
    KJOpencvMorphologyStyleTOPHAT,  /// Top hat, the difference between the source image and the open operation
    KJOpencvMorphologyStyleBLACKHAT /// Black hat, the difference between the closing operation and the source image
};

#endif /* KJOpencvType_h */

NS_ASSUME_NONNULL_END
