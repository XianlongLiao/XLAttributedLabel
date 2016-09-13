//
//  XLRegexAttributedLabel.m
//  XLAttributedLabel
//
//  Created by 先龙 廖 on 16/7/14.
//  Copyright © 2016年 先龙 廖. All rights reserved.
//

#import "XLRegexAttributedLabel.h"

#pragma mark 相关配置
//------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------

/**
 *  和字体高度的比例
 */
const CGFloat kXLEmojiWidthRatioWithLineHeight = 1.15f;

/**
 *  表情绘制Y轴矫正值，和字体高度的比例，越大越往下
 */
const CGFloat kXLEmojiOriginYOffsetRatioWithLineHeight = 0.10f;
const CGFloat kXLAscentDescentScale = 0.25f;

/**
 *  绘制表情，添加表情时的key，用来保存表情图片名称和读取
 */
NSString *const kCustomGlyphAttributedImageName = @"kCustomGlyphAttributedImageName";

/**
 *  表情占位符
 */
NSString *const kEmojiReplaceCharacter = @"\uFFFC";

NSString *const kHTMLRegexExpression = @"<(S*?)[^>]*>.*?|<.*? />";
NSString *const kHttpURLRegexExpression = @"[a-zA-z]+://[^\\s]*";

/**
 *  修正绘制offset，根据挡圈设置的textAlignment
 *
 *  @param textAlignment 当前设置的textAlignment
 *
 *  @return 偏移值
 */
static inline CGFloat TTTFlushFactorForTextAlignment(NSTextAlignment textAlignment) {
    switch (textAlignment) {
        case NSTextAlignmentCenter:
            return 0.5f;
        case NSTextAlignmentRight:
            return 1.0f;
        case NSTextAlignmentLeft:
        default:
            return 0.0f;
    }
}

//------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------
/**
 *  regex and plist manager, 单例模式，每次加入的正则或plist都会全局保留一份，否则每个Label都有自己的副本会影响效率
 */
@interface XLRegexPlistManager : NSObject

@property (nonatomic, strong) NSMutableDictionary *plistRecords;
@property (nonatomic, strong) NSMutableDictionary *regularExpressionRecords;

@end

@implementation XLRegexPlistManager

+ (instancetype)shareInstance {
    static XLRegexPlistManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[XLRegexPlistManager alloc] init];
    });
    return manager;
}

#pragma mark - get plist dict for key -
- (NSDictionary *)dictFromKey:(NSString *)key {
    NSAssert(key && key.length > 0, @"key不可以为空值");
    if (self.plistRecords[key]) {
        return self.plistRecords[key];
    }
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:key];
    NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:path];
    self.plistRecords[key] = dict;
    return dict;
}

#pragma mark - get regex for key -
- (NSRegularExpression *)regularExpressionForRegex:(NSString *)regex {
    NSAssert(regex && regex.length > 0, @"regex不可以为空值");
    if (self.regularExpressionRecords[regex]) {
        return self.regularExpressionRecords[regex];
    }
    NSRegularExpression *regular = [[NSRegularExpression alloc] initWithPattern:regex
                                                                        options:NSRegularExpressionCaseInsensitive
                                                                          error:nil];
    NSAssert1(regular, @"正则表达式--%@--有误", regex);
    self.regularExpressionRecords[regex] = regular;
    return regular;
}

#pragma mark - XLRegexPlistManager getter -

- (NSMutableDictionary *)plistRecords {
    if (!_plistRecords) {
        _plistRecords = [[NSMutableDictionary alloc] init];
    }
    return _plistRecords;
}

- (NSMutableDictionary *)regexRecords {
    if (!_regularExpressionRecords) {
        _regularExpressionRecords = [[NSMutableDictionary alloc] init];
    }
    return _regularExpressionRecords;
}

@end

#pragma mark - 表情callback
//------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------

typedef struct CustomGlyphMetrics {
    CGFloat ascent;
    CGFloat descent;
    CGFloat width;
} CustomGlyphMetrics, *CustomGlyphMetricsRef;

static void deallocCallback(void *refCon) {
    free(refCon), refCon = NULL;
}

static CGFloat ascentCallback(void *refCon) {
    CustomGlyphMetricsRef metrics = (CustomGlyphMetricsRef)refCon;
    return metrics->ascent;
}

static CGFloat descentCallback(void *refCon) {
    CustomGlyphMetricsRef metrics = (CustomGlyphMetricsRef)refCon;
    return metrics->descent;
}

static CGFloat widthCallback(void *refCon) {
    CustomGlyphMetricsRef metrics = (CustomGlyphMetricsRef)refCon;
    return metrics->width;
}

//------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------
@interface XLLinkAttachment : NSObject

@property (nonatomic, strong) NSString *string;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, strong) NSString *url;

- (instancetype)initWithString:(NSString *)string range:(NSRange)range url:(NSString *)url;

@end

@implementation XLLinkAttachment

- (instancetype)initWithString:(NSString *)string range:(NSRange)range url:(NSString *)url {
    self = [super init];
    if (self) {
        self.string = string;
        self.range = range;
        self.url = url;
    }
    return self;
}

@end

//------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------

@interface TTTAttributedLabel (XLRegexAttributedLabel)

@property (readwrite, nonatomic, strong) TTTAttributedLabelLink *activeLink;

- (void)commonInit;

- (NSArray *)addLinksWithTextCheckingResults:(NSArray *)results
                                  attributes:(NSDictionary *)attributes;

- (void)drawStrike:(CTFrameRef)frame
            inRect:(CGRect)rect
           context:(CGContextRef)c;

@end

//------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------

@interface XLRegexAttributedLabel ()

/**
 *  @regexAttributeds: 普通的富文本正则，更换颜色或字体 key为正则表达式，value为attributeds
 *  @emojiRegexAttributeds：表情的正则表达式，key为正则表达式，value为xxx.plist
 *  @linkRegexAttributeds：超链接正则表达式，key为正则表达式，value为attributeds
 */
@property (strong, nonatomic) NSMutableDictionary *regexAttributeds;
@property (strong, nonatomic) NSMutableDictionary *emojiRegexAttributeds;
@property (strong, nonatomic) NSMutableDictionary *linkRegexAttributeds;

/**
 *  记录HTML超链接标签属性
 */
@property (strong, nonatomic) NSMutableArray *linkAttachments;

@end

@implementation XLRegexAttributedLabel

- (void)commonInit {
    [super commonInit];
    _regexAttributeds = [[NSMutableDictionary alloc] init];
    _emojiRegexAttributeds = [[NSMutableDictionary alloc] init];
    _linkRegexAttributeds = [[NSMutableDictionary alloc] init];
    _linkAttachments = [NSMutableArray new];
    
    self.emojiBundleName = @"NIMKitResouce.bundle";
    self.isMatchHtmlLink = YES;
    
    self.numberOfLines = 0;
    self.font = [UIFont systemFontOfSize:15.0];
    self.textColor = [UIColor blackColor];
    self.backgroundColor = [UIColor clearColor];
    self.lineBreakMode = NSLineBreakByCharWrapping;
    self.lineSpacing = 5;
    
    //链接默认样式设置
    NSMutableDictionary *linkAttributeds = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *activeLinkAttributeds = [[NSMutableDictionary alloc] init];
    UIColor *commonLinkColor = [UIColor blueColor];
    NSValue *edgeInsetsValue = [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(1, 1, 1, 1)];
    
    
    [linkAttributeds setObject:commonLinkColor forKey:(NSString *)kCTForegroundColorAttributeName];
    
    [activeLinkAttributeds setObject:commonLinkColor forKey:(NSString *)kCTForegroundColorAttributeName];
    [activeLinkAttributeds setValue:[UIColor lightGrayColor] forKey:kTTTBackgroundFillColorAttributeName];
    [activeLinkAttributeds setValue:edgeInsetsValue forKey:kTTTBackgroundFillPaddingAttributeName];
    [activeLinkAttributeds setValue:@2 forKey:kTTTBackgroundCornerRadiusAttributeName];
    
    self.linkAttributes = linkAttributeds;
    self.activeLinkAttributes = activeLinkAttributeds;
}


- (void)setEmojiBundleName:(NSString *)emojiBundleName {
    if (emojiBundleName && emojiBundleName.length >0 && ![[emojiBundleName lowercaseString] hasSuffix:@".bundle"]) {
        _emojiBundleName = [emojiBundleName stringByAppendingString:@".bundle"];
    }else {
        _emojiBundleName = emojiBundleName;
    }
}

/**
 *  如果是有attributedText的情况下，有可能会返回少那么点的，这里矫正下
 *
 */
- (CGSize)sizeThatFits:(CGSize)size {
    if (!self.attributedText) {
        return [super sizeThatFits:size];
    }
    
    CGSize rSize = [super sizeThatFits:size];
    rSize.height +=1;
    return rSize;
}

#pragma mark - size fit result
- (CGSize)preferredSizeWithMaxWidth:(CGFloat)maxWidth
{
    maxWidth = maxWidth - self.textInsets.left - self.textInsets.right;
    return [self sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
}

//------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------
#pragma mark - 常规富文本

- (void)addRegex:(NSString *)regex withFont:(UIFont *)font {
    [self addRegex:regex withFont:font withColor:nil];
}

- (void)addRegex:(NSString *)regex withFont:(UIFont *)font withColor:(UIColor *)color {
    NSMutableDictionary *attributeds = [[NSMutableDictionary alloc] initWithCapacity:2];
    if (font) {
        [attributeds setValue:font forKey:NSFontAttributeName];
    }
    if (color) {
        [attributeds setValue:color forKey:NSForegroundColorAttributeName];
    }
    [self.regexAttributeds setValue:attributeds forKey:regex];
}

//------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------
#pragma mark - 添加表情正则

- (void)addRegex:(NSString *)regex withEmojiPlist:(NSString *)plistName {
    [self.emojiRegexAttributeds setValue:plistName forKey:regex];
}

//------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------
#pragma mark - 添加链接正则

- (void)addLinkWithRegex:(NSString *)regex {
    [self addLinkWithRegex:regex withFont:nil];
}

- (void)addLinkWithRegex:(NSString *)regex withFont:(UIFont *)font {
    [self addLinkWithRegex:regex withFont:font withColor:nil];
}

- (void)addLinkWithRegex:(NSString *)regex withFont:(UIFont *)font withColor:(UIColor *)color {
    NSMutableDictionary *attributeds = [[NSMutableDictionary alloc] initWithCapacity:2];
    if (font) {
        [attributeds setValue:font forKey:NSFontAttributeName];
    }
    if (color) {
        [attributeds setValue:color forKey:NSForegroundColorAttributeName];
    }
    [self.linkRegexAttributeds setValue:attributeds forKey:regex];
}

//------------------------------------------------------------------------------------------------
#pragma mark - set text

- (void)setContentText:(id)contentText {
    NSParameterAssert(!contentText || [contentText isKindOfClass:[NSAttributedString class]] || [contentText isKindOfClass:[NSString class]]);
    [self.linkAttachments removeAllObjects];
    _contentText = contentText;
    if ([_contentText isKindOfClass:[NSString class]]) {
        __weak typeof(self) weakSelf = self;
        [super setText:_contentText afterInheritingLabelAttributesAndConfiguringWithBlock:^NSMutableAttributedString *(NSMutableAttributedString *mutableAttributedString) {
            return (id)[weakSelf regularExpressionAttributedStringFromText:mutableAttributedString];
        }];
    }else {
        [super setText:_contentText];
    }
    //添加Link
    if (self.linkAttachments.count > 0) {
        NSMutableArray *results = [NSMutableArray new];
        for (XLLinkAttachment *attachment in self.linkAttachments) {
            NSTextCheckingResult *linkResult = [NSTextCheckingResult correctionCheckingResultWithRange:attachment.range
                                                                                     replacementString:attachment.url];
            [results addObject:linkResult];
        }
        [super addLinksWithTextCheckingResults:results attributes:self.linkAttributes];
    }
}

- (NSAttributedString *)regularExpressionAttributedStringFromText:(NSAttributedString *)attributedText {
    
    __block NSMutableAttributedString *attributedStr = [[NSMutableAttributedString alloc] initWithAttributedString:attributedText];
    [attributedStr beginEditing];
    
    //表情处理
    if (self.emojiRegexAttributeds.count > 0) {
        NSArray *regexs = [self.emojiRegexAttributeds allKeys];
        [regexs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *regex = (id)obj;
            NSString *plistName = self.emojiRegexAttributeds[regex];
            NSDictionary *plistDict = [[XLRegexPlistManager shareInstance] dictFromKey:plistName];
            NSRegularExpression *regular = [[XLRegexPlistManager shareInstance] regularExpressionForRegex:regex];
            __block NSInteger textOffset = 0;
            __block CGFloat emojiWidth = self.font.lineHeight * kXLEmojiWidthRatioWithLineHeight;
            [regular enumerateMatchesInString:attributedText.string
                                      options:NSMatchingWithTransparentBounds
                                        range:NSMakeRange(0, [attributedStr.string length])
                                   usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
                                       NSRange resultRanage = result.range;
                                       resultRanage.location -= textOffset; //改变attributedStr需要知道当前表情在哪 减去之前replace减少的位数
                                       NSString *resultText = [attributedStr.string substringWithRange:resultRanage];
                                       NSString *fileName = plistDict[resultText];
                                       if (fileName) {
                                           NSMutableAttributedString *imageRepaceCharacterStr = [[NSMutableAttributedString alloc] initWithString:kEmojiReplaceCharacter];
                                           [attributedStr replaceCharactersInRange:resultRanage withAttributedString:imageRepaceCharacterStr];
                                           NSRange replaceRange = NSMakeRange(resultRanage.location, imageRepaceCharacterStr.length);
                                           
                                           CTRunDelegateCallbacks callbacks = [self emojiGlyphMetricsCallback];
                                           
                                           // 这里设置下需要绘制的图片的大小，这里我自定义了一个结构体以便于存储数据
                                           CustomGlyphMetricsRef metrics = malloc(sizeof(CustomGlyphMetrics));
                                           metrics->width = emojiWidth;
                                           metrics->ascent = 1 / (1 + kXLAscentDescentScale)*metrics->width;
                                           metrics->descent = metrics->ascent*kXLAscentDescentScale;
                                           CTRunDelegateRef delegate = CTRunDelegateCreate(&callbacks, metrics);
                                           [attributedStr addAttribute:(NSString *)kCTRunDelegateAttributeName
                                                                 value:(__bridge id)delegate
                                                                 range:replaceRange];
                                           CFRelease(delegate);
                                           
                                           // 设置自定义属性，绘制的时候需要用到
                                           [attributedStr addAttribute:kCustomGlyphAttributedImageName
                                                                 value:fileName
                                                                 range:replaceRange];
                                           
                                           textOffset += resultRanage.length - replaceRange.length;
                                       }
                                   }];
        }];
    }
    //HTML标签，默认样式展示
    if (self.isMatchHtmlLink) {
        NSRegularExpression *regular = [[XLRegexPlistManager shareInstance] regularExpressionForRegex:kHTMLRegexExpression];
        NSArray *matches = [regular matchesInString:attributedStr.string options:0x00 range:NSMakeRange(0, attributedStr.string.length)];
        NSArray *attachments = [self htmlAttachmentsWithContentString:attributedStr.string fromMatches:matches];
        
        [self.linkAttachments addObjectsFromArray:attachments];
        
        for (NSInteger i = matches.count - 1; i >= 0; i--) { //从后往前替换 不用计算range
            NSTextCheckingResult *result = matches[i];
            NSAttributedString *clearAtributedStr = [[NSAttributedString alloc] initWithString:@""];
            [attributedStr replaceCharactersInRange:result.range withAttributedString:clearAtributedStr];
        }
    }
    
    //常规富文本处理
    if (self.regexAttributeds.count > 0) {
        NSArray *regexs = [self.regexAttributeds allKeys];
        [regexs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *regex = (id)obj;
            NSRegularExpression *regular = [[XLRegexPlistManager shareInstance] regularExpressionForRegex:regex];
            id value = self.regexAttributeds[regex];
            NSDictionary *attributeds = value;
            [regular enumerateMatchesInString:attributedStr.string
                                      options:NSMatchingWithTransparentBounds
                                        range:NSMakeRange(0, [attributedStr.string length])
                                   usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
                                       NSRange resultRange = result.range;
                                       [attributedStr addAttributes:attributeds range:resultRange];
                                   }];
        }];
    }
    [attributedStr endEditing];
    return attributedStr;
}

/**
 * 定义回调函数
 */
- (CTRunDelegateCallbacks)emojiGlyphMetricsCallback {
    CTRunDelegateCallbacks callbacks;
    callbacks.version = kCTRunDelegateCurrentVersion;
    callbacks.getAscent = ascentCallback;
    callbacks.getDescent = descentCallback;
    callbacks.getWidth = widthCallback;
    callbacks.dealloc = deallocCallback;
    return callbacks;
}

/**
 *  获取字符串中的HTML标示
 *
 *  @param string  字符串
 *  @param matches 正则匹配结果
 *
 *  @return attachments
 */
- (NSArray *)htmlAttachmentsWithContentString:(NSString *)contentString fromMatches:(NSArray *)matches {
    if (matches.count % 2 != 0) {
        return nil;
    }
    NSMutableArray *attachments = [NSMutableArray new];
    CGFloat offsetLocation = 0;
    for (int i = 0; i < matches.count; i += 2) {
        NSTextCheckingResult *htmlTagPreResult = matches[i];
        NSTextCheckingResult *htmlTagSufResult = matches[i+1];
        NSString *preHtmlTag = [contentString substringWithRange:htmlTagPreResult.range];
        
        //string
        NSRange stringRange;
        stringRange.location = NSMaxRange(htmlTagPreResult.range);
        stringRange.length = htmlTagSufResult.range.location - stringRange.location;
        NSString *string = [contentString substringWithRange:stringRange];
        
        //range  这里计算的是后面把HTML标签删除后的range
        NSRange range;
        range.location = htmlTagPreResult.range.location - offsetLocation;
        range.length = stringRange.length;
        
        //url
        NSRegularExpression *urlRegular = [[XLRegexPlistManager shareInstance] regularExpressionForRegex:kHttpURLRegexExpression];
        NSTextCheckingResult *urlResult = [urlRegular firstMatchInString:preHtmlTag options:0x00 range:NSMakeRange(0, preHtmlTag.length)];
        if (urlResult) {
            NSString *url = [preHtmlTag substringWithRange:NSMakeRange(urlResult.range.location, urlResult.range.length - 2)]; //这里减去2是为了去除多余的">
            XLLinkAttachment *htmlAttachment = [[XLLinkAttachment alloc] initWithString:string
                                                                                  range:range
                                                                                    url:url];
            [attachments addObject:htmlAttachment];
            
            offsetLocation += htmlTagPreResult.range.length + htmlTagSufResult.range.length;
        }
        
    }
    return attachments;
}

#pragma mark - 绘制表情
- (void)drawStrike:(CTFrameRef)frame
            inRect:(CGRect)rect
           context:(CGContextRef)c
{
    [super drawStrike:frame inRect:rect context:c];
    
    CGFloat emojiWith = self.font.lineHeight * kXLEmojiWidthRatioWithLineHeight;
    CGFloat emojiOriginYOffset = self.font.lineHeight * kXLEmojiOriginYOffsetRatioWithLineHeight;
    
    CGFloat flushFactor = TTTFlushFactorForTextAlignment(self.textAlignment);
    
    CFArrayRef lines = CTFrameGetLines(frame);
    NSInteger numberOfLines = self.numberOfLines > 0 ? MIN(self.numberOfLines, CFArrayGetCount(lines)) : CFArrayGetCount(lines);
    CGPoint lineOrigins[numberOfLines];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, numberOfLines), lineOrigins);
    
    BOOL truncateLastLine = (self.lineBreakMode == NSLineBreakByTruncatingHead || self.lineBreakMode == NSLineBreakByTruncatingMiddle || self.lineBreakMode == NSLineBreakByTruncatingTail);
    CFRange textRange = CFRangeMake(0, (CFIndex)[self.attributedText length]);
    
    for (CFIndex lineIndex = 0; lineIndex < numberOfLines; lineIndex++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
        
        //这里其实是能获取到当前行的真实origin.x，根据textAlignment，而lineBounds.origin.x其实是默认一直为0的(不会受textAlignment影响)
        CGFloat penOffset = (CGFloat)CTLineGetPenOffsetForFlush(line, flushFactor, rect.size.width);
        
        CFIndex truncationAttributePosition = -1;
        //检测如果是最后一行，是否有替换...
        if (lineIndex == numberOfLines - 1 && truncateLastLine) {
            // Check if the range of text in the last line reaches the end of the full attributed string
            CFRange lastLineRange = CTLineGetStringRange(line);
            
            if (!(lastLineRange.length == 0 && lastLineRange.location == 0) && lastLineRange.location + lastLineRange.length < textRange.location + textRange.length) {
                // Get correct truncationType and attribute position
                truncationAttributePosition = lastLineRange.location;
                NSLineBreakMode lineBreakMode = self.lineBreakMode;
                
                // Multiple lines, only use UILineBreakModeTailTruncation
                if (numberOfLines != 1) {
                    lineBreakMode = NSLineBreakByTruncatingTail;
                }
                
                switch (lineBreakMode) {
                    case NSLineBreakByTruncatingHead:
                        break;
                    case NSLineBreakByTruncatingMiddle:
                        truncationAttributePosition += (lastLineRange.length / 2);
                        break;
                    case NSLineBreakByTruncatingTail:
                    default: truncationAttributePosition += (lastLineRange.length - 1);
                        break;
                }
                //如果要在truncationAttributePosition这个位置画表情需要忽略
            }
        }
        //找到当前行的每一个要素，姑且这么叫吧。可以理解为有单独的attr属性的各个range。
        for (id glyphRun in (__bridge NSArray *)CTLineGetGlyphRuns(line)) {
            //找到此要素所对应的属性
            NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes((__bridge CTRunRef) glyphRun);
            //判断是否有图像，如果有就绘制上去
            NSString *imageName = attributes[kCustomGlyphAttributedImageName];
            if (imageName) {
                CFRange glyphRange = CTRunGetStringRange((__bridge CTRunRef)glyphRun);
                if (glyphRange.location == truncationAttributePosition) {
                    //这里因为glyphRange的length肯定为1，所以只做这一个判断足够
                    continue;
                }
                
                CGRect runBounds = CGRectZero;
                CGFloat runAscent = 0.0f;
                CGFloat runDescent = 0.0f;
                
                runBounds.size.width = (CGFloat)CTRunGetTypographicBounds((__bridge CTRunRef)glyphRun, CFRangeMake(0, 0), &runAscent, &runDescent, NULL);
                
                if (runBounds.size.width != emojiWith) {
                    //这一句是为了在某些情况下，例如单行省略号模式下，默认行为会将个别表情的runDelegate改变，也就改变了其大小。这时候会引起界面上错乱，
                    continue;
                }
                
                runBounds.size.height = runAscent + runDescent;
                
                CGFloat xOffset = 0.0f;
                switch (CTRunGetStatus((__bridge CTRunRef)glyphRun)) {
                    case kCTRunStatusRightToLeft:
                        xOffset = CTLineGetOffsetForStringIndex(line, glyphRange.location + glyphRange.length, NULL);
                        break;
                    default:
                        xOffset = CTLineGetOffsetForStringIndex(line, glyphRange.location, NULL);
                        break;
                }
                runBounds.origin.x = penOffset + xOffset;
                runBounds.origin.y = lineOrigins[lineIndex].y;
                runBounds.origin.y -= runDescent;
                
                imageName = [NSString stringWithFormat:@"Emoticon/Emoji/%@", imageName];
                NSString *imagePath = [self.emojiBundleName stringByAppendingPathComponent:imageName];
                UIImage *image = [UIImage imageNamed:imagePath];
                runBounds.origin.y -= emojiOriginYOffset; //稍微矫正下。
                CGContextDrawImage(c, runBounds, image.CGImage);
            }
        }
    }
}

#pragma mark - select link override

- (void)touchesEnded:(NSSet *)touches
           withEvent:(UIEvent *)event
{
    //如果delegate实现了XLAttributedLabel自身的选择link方法
    if(self.delegate && [self.delegate respondsToSelector:@selector(attributedLable:didSelectedLink:)]){
        if (self.activeLink && self.activeLink.result.resultType == NSTextCheckingTypeCorrection) {
            NSTextCheckingResult *result = self.activeLink.result;
            [self.delegate attributedLable:self didSelectedLink:result.replacementString];
            self.activeLink = nil;
            return;
        }
    }
    [super touchesEnded:touches withEvent:event];
}

@end
