// Copyright 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/uikit_ui_util.h"

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <stddef.h>
#include <stdint.h>
#import <UIKit/UIKit.h>
#include <cmath>

#include "base/ios/ios_util.h"
#include "base/logging.h"
#include "base/mac/foundation_util.h"
#include "ios/chrome/browser/experimental_flags.h"
#include "ios/chrome/browser/ui/ui_util.h"
#include "ui/base/l10n/l10n_util.h"
#include "ui/base/l10n/l10n_util_mac.h"
#include "ui/gfx/ios/uikit_util.h"
#include "ui/gfx/scoped_cg_context_save_gstate_mac.h"

namespace {

// Linearly interpolate between |a| and |b| by fraction |f|. Satisfies
// |Lerp(a,b,0) == a| and |Lerp(a,b,1) == b|.
CGFloat Lerp(CGFloat a, CGFloat b, CGFloat fraction) {
  return a * (1.0f - fraction) + b * fraction;
}

// Gets the RGBA components from a UIColor in RBG or monochrome color space.
void GetRGBA(UIColor* color, CGFloat* r, CGFloat* g, CGFloat* b, CGFloat* a) {
  switch (CGColorSpaceGetModel(CGColorGetColorSpace(color.CGColor))) {
    case kCGColorSpaceModelRGB: {
      BOOL success = [color getRed:r green:g blue:b alpha:a];
      DCHECK(success);
      return;
    }
    case kCGColorSpaceModelMonochrome: {
      const size_t componentsCount =
          CGColorGetNumberOfComponents(color.CGColor);
      DCHECK(componentsCount == 1 || componentsCount == 2);
      const CGFloat* components = CGColorGetComponents(color.CGColor);
      *r = components[0];
      *g = components[0];
      *b = components[0];
      *a = componentsCount == 1 ? 1 : components[1];
      return;
    }
    default:
      NOTREACHED() << "Unsupported color space.";
      return;
  }
}

}  // namespace

void SetA11yLabelAndUiAutomationName(UIView* element,
                                     int idsAccessibilityLabel,
                                     NSString* englishUiAutomationName) {
  [element setAccessibilityLabel:l10n_util::GetNSString(idsAccessibilityLabel)];
  [element setAccessibilityIdentifier:englishUiAutomationName];
}

void GetSizeButtonWidthToFit(UIButton* button) {
  // Resize the button's width to fit the new text, but keep the original
  // height. sizeToFit appears to ignore the image size, so re-add the size of
  // the button's image to the frame width.
  CGFloat buttonHeight = [button frame].size.height;
  CGFloat imageWidth = [[button imageView] frame].size.width;
  [button sizeToFit];
  CGRect newFrame = [button frame];
  newFrame.size.height = buttonHeight;
  newFrame.size.width += imageWidth;
  [button setFrame:newFrame];
}

void TranslateFrame(UIView* view, UIOffset offset) {
  if (!view)
    return;

  CGRect frame = [view frame];
  frame.origin.x = frame.origin.x + offset.horizontal;
  frame.origin.y = frame.origin.y + offset.vertical;
  [view setFrame:frame];
}

UIFont* GetUIFont(int fontFace, bool isBold, CGFloat fontSize) {
  NSString* fontFaceName;
  switch (fontFace) {
    case FONT_HELVETICA:
      fontFaceName = isBold ? @"Helvetica-Bold" : @"Helvetica";
      break;
    case FONT_HELVETICA_NEUE:
      fontFaceName = isBold ? @"HelveticaNeue-Bold" : @"HelveticaNeue";
      break;
    case FONT_HELVETICA_NEUE_LIGHT:
      // FONT_HELVETICA_NEUE_LIGHT does not support Bold.
      DCHECK(!isBold);
      fontFaceName = @"HelveticaNeue-Light";
      break;
    default:
      NOTREACHED();
      fontFaceName = @"Helvetica";
      break;
  }
  return [UIFont fontWithName:fontFaceName size:fontSize];
}

void AddBorderShadow(UIView* view, CGFloat offset, UIColor* color) {
  CGRect rect = CGRectInset(view.bounds, -offset, -offset);
  CGPoint waypoints[] = {
      CGPointMake(rect.origin.x, rect.origin.y),
      CGPointMake(rect.origin.x, rect.origin.y + rect.size.height),
      CGPointMake(rect.origin.x + rect.size.width,
                  rect.origin.y + rect.size.height),
      CGPointMake(rect.origin.x + rect.size.width, rect.origin.y),
      CGPointMake(rect.origin.x, rect.origin.y)};
  int numberOfWaypoints = sizeof(waypoints) / sizeof(waypoints[0]);
  CGMutablePathRef outline = CGPathCreateMutable();
  CGPathAddLines(outline, nullptr, waypoints, numberOfWaypoints);
  view.layer.shadowColor = [color CGColor];
  view.layer.shadowOpacity = 1.0;
  view.layer.shadowOffset = CGSizeZero;
  view.layer.shadowPath = outline;
  CGPathRelease(outline);
}

void AddRoundedBorderShadow(UIView* view, CGFloat radius, UIColor* color) {
  CGRect rect = view.bounds;
  CGMutablePathRef path = CGPathCreateMutable();
  CGFloat minX = CGRectGetMinX(rect);
  CGFloat midX = CGRectGetMidX(rect);
  CGFloat maxX = CGRectGetMaxX(rect);
  CGFloat minY = CGRectGetMinY(rect);
  CGFloat midY = CGRectGetMidY(rect);
  CGFloat maxY = CGRectGetMaxY(rect);
  CGPathMoveToPoint(path, nullptr, minX, midY);
  CGPathAddArcToPoint(path, nullptr, minX, minY, midX, minY, radius);
  CGPathAddArcToPoint(path, nullptr, maxX, minY, maxX, midY, radius);
  CGPathAddArcToPoint(path, nullptr, maxX, maxY, midX, maxY, radius);
  CGPathAddArcToPoint(path, nullptr, minX, maxY, minX, midY, radius);
  CGPathCloseSubpath(path);
  view.layer.shadowColor = [color CGColor];
  view.layer.shadowOpacity = 1.0;
  view.layer.shadowRadius = radius;
  view.layer.shadowOffset = CGSizeZero;
  view.layer.shadowPath = path;
  view.layer.borderWidth = 0.0;
  CGPathRelease(path);
}

UIImage* CaptureViewWithOption(UIView* view,
                               CGFloat scale,
                               CaptureViewOption option) {
  UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES /* opaque */,
                                         scale);
  if (base::ios::IsRunningOnIOS9OrLater() && option != kClientSideRendering) {
    [view drawViewHierarchyInRect:view.bounds
               afterScreenUpdates:option == kAfterScreenUpdate];
  } else {
    CGContext* context = UIGraphicsGetCurrentContext();
    [view.layer renderInContext:context];
  }
  UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

UIImage* CaptureView(UIView* view, CGFloat scale) {
  return CaptureViewWithOption(view, scale, kNoCaptureOption);
}

UIImage* GreyImage(UIImage* image) {
  DCHECK(image);
  // Grey images are always non-retina to improve memory performance.
  UIGraphicsBeginImageContextWithOptions(image.size, YES, 1.0);
  CGRect greyImageRect = CGRectMake(0, 0, image.size.width, image.size.height);
  [image drawInRect:greyImageRect blendMode:kCGBlendModeLuminosity alpha:1.0];
  UIImage* greyImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return greyImage;
}

UIColor* GetPrimaryActionButtonColor() {
  return UIColorFromRGB(0x2d6ada, 1.0);
}

UIColor* GetSettingsBackgroundColor() {
  CGFloat rgb = 237.0 / 255.0;
  return [UIColor colorWithWhite:rgb alpha:1];
}

BOOL ImageHasAlphaChannel(UIImage* image) {
  CGImageAlphaInfo info = CGImageGetAlphaInfo(image.CGImage);
  switch (info) {
    case kCGImageAlphaNone:
    case kCGImageAlphaNoneSkipLast:
    case kCGImageAlphaNoneSkipFirst:
      return NO;
    case kCGImageAlphaPremultipliedLast:
    case kCGImageAlphaPremultipliedFirst:
    case kCGImageAlphaLast:
    case kCGImageAlphaFirst:
    case kCGImageAlphaOnly:
      return YES;
  }
}

UIImage* ResizeImage(UIImage* image,
                     CGSize targetSize,
                     ProjectionMode projectionMode) {
  return ResizeImage(image, targetSize, projectionMode, NO);
}

UIImage* ResizeImage(UIImage* image,
                     CGSize targetSize,
                     ProjectionMode projectionMode,
                     BOOL opaque) {
  CGSize revisedTargetSize;
  CGRect projectTo;

  CalculateProjection([image size], targetSize, projectionMode,
                      revisedTargetSize, projectTo);

  if (CGRectEqualToRect(projectTo, CGRectZero))
    return nil;

  // Resize photo. Use UIImage drawing methods because they respect
  // UIImageOrientation as opposed to CGContextDrawImage().
  UIGraphicsBeginImageContextWithOptions(revisedTargetSize, opaque,
                                         image.scale);
  [image drawInRect:projectTo];
  UIImage* resizedPhoto = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return resizedPhoto;
}

UIImage* DarkenImage(UIImage* image) {
  UIColor* tintColor = [UIColor colorWithWhite:0.22 alpha:0.6];
  return BlurImage(image,
                   3.0,  // blurRadius,
                   tintColor,
                   1.8,  // saturationDeltaFactor
                   nil);
}

UIImage* BlurImage(UIImage* image,
                   CGFloat blurRadius,
                   UIColor* tintColor,
                   CGFloat saturationDeltaFactor,
                   UIImage* maskImage) {
  // This code is heavily inspired by the UIImageEffect sample project,
  // presented at WWDC and available from Apple.
  DCHECK(image.size.width >= 1 && image.size.height >= 1);
  DCHECK(image.CGImage);
  DCHECK(!maskImage || maskImage.CGImage);

  CGRect imageRect = {CGPointZero, image.size};
  UIImage* effectImage = nil;

  BOOL hasBlur = blurRadius > __FLT_EPSILON__;
  BOOL hasSaturationChange = fabs(saturationDeltaFactor - 1.) > __FLT_EPSILON__;
  if (hasBlur || hasSaturationChange) {
    UIGraphicsBeginImageContextWithOptions(image.size,
                                           NO,  // opaque.
                                           [[UIScreen mainScreen] scale]);
    CGContextRef effectInContext = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(effectInContext, 1.0, -1.0);
    CGContextTranslateCTM(effectInContext, 0, -image.size.height);
    CGContextDrawImage(effectInContext, imageRect, image.CGImage);

    vImage_Buffer effectInBuffer;
    effectInBuffer.data = CGBitmapContextGetData(effectInContext);
    effectInBuffer.width = CGBitmapContextGetWidth(effectInContext);
    effectInBuffer.height = CGBitmapContextGetHeight(effectInContext);
    effectInBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectInContext);

    UIGraphicsBeginImageContextWithOptions(image.size,
                                           NO,  // opaque.
                                           [[UIScreen mainScreen] scale]);
    CGContextRef effectOutContext = UIGraphicsGetCurrentContext();
    vImage_Buffer effectOutBuffer;
    effectOutBuffer.data = CGBitmapContextGetData(effectOutContext);
    effectOutBuffer.width = CGBitmapContextGetWidth(effectOutContext);
    effectOutBuffer.height = CGBitmapContextGetHeight(effectOutContext);
    effectOutBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectOutContext);

    // Those are swapped as effects are applied.
    vImage_Buffer* inBuffer = &effectInBuffer;
    vImage_Buffer* outBuffer = &effectOutBuffer;

    if (hasBlur) {
      // A description of how to compute the box kernel width from the Gaussian
      // radius (aka standard deviation) appears in the SVG spec:
      // http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
      //
      // For larger values of 's' (s >= 2.0), an approximation can be used:
      // Three successive box-blurs build a piece-wise quadratic convolution
      // kernel, which approximates the Gaussian kernel to within roughly 3%.
      //
      // let d = floor(s * 3*sqrt(2*pi)/4 + 0.5)
      //
      // ... if d is odd, use three box-blurs of size 'd', centered on the
      // output pixel.
      //
      CGFloat inputRadius = blurRadius * [[UIScreen mainScreen] scale];
      NSUInteger radius = floor(inputRadius * 3. * sqrt(2 * M_PI) / 4 + 0.5);
      if (radius % 2 != 1) {
        // force radius to be odd so that the three box-blur methodology works.
        radius += 1;
      }
      for (int i = 0; i < 3; ++i) {
        vImageBoxConvolve_ARGB8888(inBuffer,            // src.
                                   outBuffer,           // dst.
                                   nullptr,             // tempBuffer.
                                   0,                   // srcOffsetToROI_X.
                                   0,                   // srcOffsetToROI_Y
                                   radius,              // kernel_height
                                   radius,              // kernel_width
                                   0,                   // backgroundColor
                                   kvImageEdgeExtend);  // flags
        vImage_Buffer* temp = inBuffer;
        inBuffer = outBuffer;
        outBuffer = temp;
      }
    }
    if (hasSaturationChange) {
      CGFloat s = saturationDeltaFactor;
      CGFloat floatingPointSaturationMatrix[] = {
          0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0,
          0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0,
          0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0,
          0,                    0,                    0,  1 };
      const int32_t divisor = 256;
      NSUInteger matrixSize = sizeof(floatingPointSaturationMatrix) /
                              sizeof(floatingPointSaturationMatrix[0]);
      int16_t saturationMatrix[matrixSize];
      for (NSUInteger i = 0; i < matrixSize; ++i) {
        saturationMatrix[i] =
            (int16_t)roundf(floatingPointSaturationMatrix[i] * divisor);
      }
      vImageMatrixMultiply_ARGB8888(inBuffer, outBuffer, saturationMatrix,
                                    divisor, nullptr, nullptr, kvImageNoFlags);
    }
    if (outBuffer == &effectOutBuffer)
      effectImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (!effectImage)
      effectImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
  }

  // Set up output context.
  UIGraphicsBeginImageContextWithOptions(image.size,
                                         NO,  // opaque
                                         [[UIScreen mainScreen] scale]);
  CGContextRef outputContext = UIGraphicsGetCurrentContext();
  CGContextScaleCTM(outputContext, 1.0, -1.0);
  CGContextTranslateCTM(outputContext, 0, -image.size.height);

  // Draw base image.
  CGContextDrawImage(outputContext, imageRect, image.CGImage);

  // Draw effect image.
  if (effectImage) {
    gfx::ScopedCGContextSaveGState context(outputContext);
    if (maskImage)
      CGContextClipToMask(outputContext, imageRect, maskImage.CGImage);
    CGContextDrawImage(outputContext, imageRect, effectImage.CGImage);
  }

  // Add in color tint.
  if (tintColor) {
    gfx::ScopedCGContextSaveGState context(outputContext);
    CGContextSetFillColorWithColor(outputContext, tintColor.CGColor);
    CGContextFillRect(outputContext, imageRect);
  }

  // Output image is ready.
  UIImage* outputImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return outputImage;
}

UIImage* CropImage(UIImage* image, const CGRect& cropRect) {
  CGImageRef cgImage = CGImageCreateWithImageInRect([image CGImage], cropRect);
  UIImage* result = [UIImage imageWithCGImage:cgImage];
  CGImageRelease(cgImage);
  return result;
}

UIInterfaceOrientation GetInterfaceOrientation() {
  return [[UIApplication sharedApplication] statusBarOrientation];
}

CGFloat CurrentKeyboardHeight(NSValue* keyboardFrameValue) {
  CGSize keyboardSize = [keyboardFrameValue CGRectValue].size;
  if (base::ios::IsRunningOnIOS8OrLater()) {
    return keyboardSize.height;
  } else {
    return IsPortrait() ? keyboardSize.height : keyboardSize.width;
  }
}

UIImage* ImageWithColor(UIColor* color) {
  CGRect rect = CGRectMake(0, 0, 1, 1);
  UIGraphicsBeginImageContext(rect.size);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetFillColorWithColor(context, [color CGColor]);
  CGContextFillRect(context, rect);
  UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

UIImage* CircularImageFromImage(UIImage* image, CGFloat width) {
  CGRect frame =
      CGRectMakeAlignedAndCenteredAt(width / 2.0, width / 2.0, width);

  UIGraphicsBeginImageContextWithOptions(frame.size, NO, 0.0);
  CGContextRef context = UIGraphicsGetCurrentContext();

  CGContextBeginPath(context);
  CGContextAddEllipseInRect(context, frame);
  CGContextClosePath(context);
  CGContextClip(context);

  CGFloat scaleX = frame.size.width / image.size.width;
  CGFloat scaleY = frame.size.height / image.size.height;
  CGFloat scale = std::max(scaleX, scaleY);
  CGContextScaleCTM(context, scale, scale);

  [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];

  image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return image;
}

UIColor* InterpolateFromColorToColor(UIColor* firstColor,
                                     UIColor* secondColor,
                                     CGFloat fraction) {
  DCHECK_LE(0.0, fraction);
  DCHECK_LE(fraction, 1.0);
  CGFloat r1, r2, g1, g2, b1, b2, a1, a2;
  GetRGBA(firstColor, &r1, &g1, &b1, &a1);
  GetRGBA(secondColor, &r2, &g2, &b2, &a2);
  return [UIColor colorWithRed:Lerp(r1, r2, fraction)
                         green:Lerp(g1, g2, fraction)
                          blue:Lerp(b1, b2, fraction)
                         alpha:Lerp(a1, a2, fraction)];
}

void ApplyVisualConstraints(NSArray* constraints,
                            NSDictionary* subviewsDictionary,
                            UIView* parentView) {
  ApplyVisualConstraintsWithMetricsAndOptions(constraints, subviewsDictionary,
                                              nil, 0, parentView);
}

void ApplyVisualConstraintsWithOptions(NSArray* constraints,
                                       NSDictionary* subviewsDictionary,
                                       NSLayoutFormatOptions options,
                                       UIView* parentView) {
  ApplyVisualConstraintsWithMetricsAndOptions(constraints, subviewsDictionary,
                                              nil, options, parentView);
}

void ApplyVisualConstraintsWithMetrics(NSArray* constraints,
                                       NSDictionary* subviewsDictionary,
                                       NSDictionary* metrics,
                                       UIView* parentView) {
  ApplyVisualConstraintsWithMetricsAndOptions(constraints, subviewsDictionary,
                                              metrics, 0, parentView);
}

void ApplyVisualConstraintsWithMetricsAndOptions(
    NSArray* constraints,
    NSDictionary* subviewsDictionary,
    NSDictionary* metrics,
    NSLayoutFormatOptions options,
    UIView* parentView) {
  for (NSString* constraint in constraints) {
    DCHECK([constraint isKindOfClass:[NSString class]]);
    [parentView
        addConstraints:[NSLayoutConstraint
                           constraintsWithVisualFormat:constraint
                                               options:options
                                               metrics:metrics
                                                 views:subviewsDictionary]];
  }
}

void AddSameCenterXConstraint(UIView* parentView, UIView* subview) {
  DCHECK_EQ(parentView, [subview superview]);
  [parentView addConstraint:[NSLayoutConstraint
                                constraintWithItem:subview
                                         attribute:NSLayoutAttributeCenterX
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:parentView
                                         attribute:NSLayoutAttributeCenterX
                                        multiplier:1
                                          constant:0]];
}

void AddSameCenterXConstraint(UIView *parentView, UIView *subview1,
                              UIView *subview2) {
  DCHECK_EQ(parentView, [subview1 superview]);
  DCHECK_EQ(parentView, [subview2 superview]);
  DCHECK_NE(subview1, subview2);
  [parentView addConstraint:[NSLayoutConstraint
                                constraintWithItem:subview1
                                         attribute:NSLayoutAttributeCenterX
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:subview2
                                         attribute:NSLayoutAttributeCenterX
                                        multiplier:1
                                          constant:0]];
}

void AddSameCenterYConstraint(UIView* parentView, UIView* subview) {
  DCHECK_EQ(parentView, [subview superview]);
  [parentView addConstraint:[NSLayoutConstraint
                                constraintWithItem:subview
                                         attribute:NSLayoutAttributeCenterY
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:parentView
                                         attribute:NSLayoutAttributeCenterY
                                        multiplier:1
                                          constant:0]];
}

void AddSameCenterYConstraint(UIView* parentView,
                              UIView* subview1,
                              UIView* subview2) {
  DCHECK_EQ(parentView, [subview1 superview]);
  DCHECK_EQ(parentView, [subview2 superview]);
  DCHECK_NE(subview1, subview2);
  [parentView addConstraint:[NSLayoutConstraint
                                constraintWithItem:subview1
                                         attribute:NSLayoutAttributeCenterY
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:subview2
                                         attribute:NSLayoutAttributeCenterY
                                        multiplier:1
                                          constant:0]];
}

bool IsCompact(id<UITraitEnvironment> environment) {
  if (base::ios::IsRunningOnIOS8OrLater()) {
    return environment.traitCollection.horizontalSizeClass ==
           UIUserInterfaceSizeClassCompact;
  } else {
    // Prior to iOS 8, iPad is always regular, iPhone is always compact.
    return !IsIPadIdiom();
  }
}

bool IsCompact() {
  UIWindow* keyWindow = [UIApplication sharedApplication].keyWindow;
  return IsCompact(keyWindow);
}

bool IsCompactTablet(id<UITraitEnvironment> environment) {
  return IsIPadIdiom() && IsCompact(environment);
}

bool IsCompactTablet() {
  return IsIPadIdiom() && IsCompact();
}
