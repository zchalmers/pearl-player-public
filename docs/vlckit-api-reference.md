# VLCKit 4.0.0-alpha.21 API reference (comments stripped)

Generated from the iOS slice headers of VLCKit.xcframework (virtualox/vlckit-spm 4.0.0-alpha.21).
Full original headers with doc comments are in this same directory.


## VLCAdjustFilter.h

```objc
#ifndef VLCAdjustFilter_h
#define VLCAdjustFilter_h

#import "VLCFilter.h"

@class VLCMediaPlayer;

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kVLCAdjustFilterContrastParameterKey;
extern NSString * const kVLCAdjustFilterBrightnessParameterKey;
extern NSString * const kVLCAdjustFilterHueParameterKey;
extern NSString * const kVLCAdjustFilterSaturationParameterKey;
extern NSString * const kVLCAdjustFilterGammaParameterKey;

@interface VLCAdjustFilter : NSObject<VLCFilter>

@property (nonatomic, readonly) id<VLCFilterParameter> contrast;

@property (nonatomic, readonly) id<VLCFilterParameter> brightness;

@property (nonatomic, readonly) id<VLCFilterParameter> hue;

@property (nonatomic, readonly) id<VLCFilterParameter> saturation;

@property (nonatomic, readonly) id<VLCFilterParameter> gamma;

+ (instancetype)new NS_UNAVAILABLE;
+ (instancetype)createWithVLCMediaPlayer:(VLCMediaPlayer *)mediaPlayer;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithVLCMediaPlayer:(VLCMediaPlayer *)mediaPlayer NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END

#endif
```


## VLCAudio.h

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const VLCMediaPlayerVolumeChangedNotification NS_SWIFT_NAME(VLCMediaPlayer.volumeChangedNotification);

OBJC_VISIBLE
@interface VLCAudio : NSObject

@property (getter=isMuted) BOOL muted;

@property (assign) int volume;

@property (readwrite) BOOL passthrough;

- (void)volumeDown;

- (void)volumeUp;

@end

NS_ASSUME_NONNULL_END
```


## VLCAudioEqualizer.h

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(VLCAudioEqualizer.Preset)
@interface VLCAudioEqualizerPreset : NSObject

@property (nonatomic, copy, readonly) NSString *name;

@property (nonatomic, readonly) unsigned index;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(VLCAudioEqualizer.Band)
@interface VLCAudioEqualizerBand : NSObject

@property (nonatomic, readonly) float frequency;

@property (nonatomic, readonly) unsigned index;

@property (nonatomic) float amplification;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(VLCAudioEqualizer)
@interface VLCAudioEqualizer : NSObject

@property (class, nonatomic, copy, readonly) NSArray<VLCAudioEqualizerPreset *> *presets;

@property (nonatomic) float preAmplification;

@property (nonatomic, copy, readonly) NSArray<VLCAudioEqualizerBand *> *bands;

- (instancetype)init;
- (instancetype)initWithPreset:(VLCAudioEqualizerPreset *)preset;

@end

NS_ASSUME_NONNULL_END
```


## VLCConsoleLogger.h

```objc
#import <Foundation/Foundation.h>

#import "VLCLogging.h"

NS_ASSUME_NONNULL_BEGIN

@interface VLCConsoleLogger : NSObject<VLCFormattedMessageLogging>

@property (nonatomic, readwrite) id<VLCLogMessageFormatting> formatter;

@end

NS_ASSUME_NONNULL_END
```


## VLCDialogProvider.h

```objc
@class VLCLibrary;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, VLCDialogQuestionType) {
    VLCDialogQuestionNormal,
    VLCDialogQuestionWarning,
    VLCDialogQuestionCritical,
};

@protocol VLCCustomDialogRendererProtocol <NSObject>

- (void)showErrorWithTitle:(NSString *)error
      message:(NSString *)message;

- (void)showLoginWithTitle:(NSString *)title
                   message:(NSString *)message
           defaultUsername:(nullable NSString *)username
          askingForStorage:(BOOL)askingForStorage
             withReference:(NSValue *)reference;

- (void)showQuestionWithTitle:(NSString *)title
                      message:(NSString *)message
                         type:(VLCDialogQuestionType)questionType
                 cancelString:(nullable NSString *)cancelString
                action1String:(nullable NSString *)action1String
                action2String:(nullable NSString *)action2String
                withReference:(NSValue *)reference;

- (void)showProgressWithTitle:(NSString *)title
                      message:(NSString *)message
              isIndeterminate:(BOOL)isIndeterminate
                     position:(float)position
                 cancelString:(nullable NSString *)cancelString
                withReference:(NSValue *)reference;

- (void)updateProgressWithReference:(NSValue *)reference
                            message:(nullable NSString *)message
                            position:(float)position;

- (void)cancelDialogWithReference:(NSValue *)reference;

@end

OBJC_VISIBLE
@interface VLCDialogProvider : NSObject

- (nullable instancetype)initWithLibrary:(nullable VLCLibrary *)library
                                 customUI:(BOOL)customUI;

@property (weak, readwrite, nonatomic, nullable) id<VLCCustomDialogRendererProtocol> customRenderer;

- (void)postUsername:(NSString *)username
         andPassword:(NSString *)password
  forDialogReference:(NSValue *)dialogReference
               store:(BOOL)store;

- (void)postAction:(int)buttonNumber
forDialogReference:(NSValue *)dialogReference;

- (void)dismissDialogWithReference:(NSValue *)dialogReference;

@end

NS_ASSUME_NONNULL_END
```


## VLCDrawable.h

```objc
# import <TargetConditionals.h>
# if TARGET_OS_OSX
#     import <Cocoa/Cocoa.h>
#     define VLCView NSView
# else
#     import <Foundation/Foundation.h>
#     import <UIKit/UIKit.h>
#     define VLCView UIView
# endif

@protocol VLCPictureInPictureMediaControlling <NSObject>

- (void)play;

- (void)pause;

- (void)seekBy:(int64_t)offset completion:(dispatch_block_t)completion;

- (int64_t)mediaLength;

- (int64_t)mediaTime;

- (BOOL)isMediaSeekable;

- (BOOL)isMediaPlaying;
@end

@protocol VLCPictureInPictureWindowControlling <NSObject>

@property (nonatomic) void(^stateChangeEventHandler)(BOOL isStarted);

- (void)startPictureInPicture;

- (void)stopPictureInPicture;

- (void)invalidatePlaybackState;
@end

@protocol VLCDrawable <NSObject>

- (void)addSubview:(VLCView *)view;

- (CGRect)bounds;
@end

@protocol VLCPictureInPictureDrawable <NSObject>

- (id<VLCPictureInPictureMediaControlling>) mediaController;

- (void (^)(id<VLCPictureInPictureWindowControlling>)) pictureInPictureReady;
@end
```


## VLCEventsConfiguration.h

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VLCEventsConfiguring <NSObject>

- (dispatch_queue_t _Nullable) dispatchQueue;
- (BOOL) isAsync;

@end

@interface VLCEventsDefaultConfiguration : NSObject<VLCEventsConfiguring>

@end

@interface VLCEventsLegacyConfiguration : NSObject<VLCEventsConfiguring>

@end

NS_ASSUME_NONNULL_END
```


## VLCFileLogger.h

```objc
#import <Foundation/Foundation.h>

#import "VLCLogging.h"

NS_ASSUME_NONNULL_BEGIN

@interface VLCFileLogger : NSObject<VLCFormattedMessageLogging>

@property (nonatomic, readonly) NSFileHandle *fileHandle;

@property (nonatomic, readwrite) id<VLCLogMessageFormatting> formatter;

+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)createWithFileHandle:(NSFileHandle *)fileHandle;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
```


## VLCFilter.h

```objc
#ifndef VLCFilter_h
#define VLCFilter_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class VLCMediaPlayer;

@protocol VLCFilter;

NS_SWIFT_NAME(VLCFilterParameterProtocol)
@protocol VLCFilterParameter <NSObject>
@property (nonatomic) id value;
@property (nonatomic, readonly) id defaultValue;
@property (nonatomic, readonly) id minValue;
@property (nonatomic, readonly) id maxValue;
- (BOOL)isValueSetToDefault;
@end

@protocol VLCFilter <NSObject>

@property (nonatomic, weak, readonly) VLCMediaPlayer *mediaPlayer;

@property (nonatomic, getter=isEnabled) BOOL enabled;

@property (nonatomic, readonly) NSDictionary< NSString*, id<VLCFilterParameter> > *parameters;

- (BOOL)resetParametersIfNeeded;

- (void)applyParametersFrom:(id<VLCFilter>)otherFilter;

@end

NS_ASSUME_NONNULL_END

#endif
```


## VLCKit.h

```objc
#include <TargetConditionals.h>

#import <VLCKit/VLCAudio.h>
#import <VLCKit/VLCLibrary.h>
#import <VLCKit/VLCMedia.h>
#import <VLCKit/VLCMediaSlave.h>
#import <VLCKit/VLCMediaDiscoverer.h>
#import <VLCKit/VLCMediaList.h>
#import <VLCKit/VLCMediaPlayer.h>
#import <VLCKit/VLCAudioEqualizer.h>
#import <VLCKit/VLCMediaListPlayer.h>
#import <VLCKit/VLCMediaThumbnailer.h>
#import <VLCKit/VLCMediaParser.h>
#import <VLCKit/VLCMediaDownloader.h>
#import <VLCKit/VLCMediaMetaData.h>
#import <VLCKit/VLCTime.h>
#import <VLCKit/VLCFilter.h>
#import <VLCKit/VLCAdjustFilter.h>
#import <VLCKit/VLCLogging.h>
#import <VLCKit/VLCConsoleLogger.h>
#import <VLCKit/VLCFileLogger.h>
#import <VLCKit/VLCLogMessageFormatter.h>
#import <VLCKit/VLCEventsConfiguration.h>
#import <VLCKit/VLCMediaPlayerTitleDescription.h>
#if !TARGET_OS_WATCH
#import <VLCKit/VLCDrawable.h>
#import <VLCKit/VLCDialogProvider.h>
#endif

#if TARGET_OS_OSX
#import <VLCKit/VLCTranscoder.h>
#import <VLCKit/VLCStreamOutput.h>
#import <VLCKit/VLCStreamSession.h>
#import <VLCKit/VLCVideoLayer.h>
#import <VLCKit/VLCVideoView.h>
#import <VLCKit/VLCRendererDiscoverer.h>
#import <VLCKit/VLCRendererItem.h>
#endif
#if TARGET_OS_IOS
#import <VLCKit/VLCTranscoder.h>
#import <VLCKit/VLCRendererDiscoverer.h>
#import <VLCKit/VLCRendererItem.h>
#endif

@class VLCMedia;
@class VLCMediaList;
@class VLCTime;
@class VLCAudio;
@class VLCMediaThumbnailer;
@class VLCMediaParser;
@class VLCMediaListPlayer;
@class VLCMediaPlayer;
@class VLCAudioEqualizer;
@class VLCAudioEqualizerPreset;
@class VLCAudioEqualizerBand;
#if !TARGET_OS_WATCH
@class VLCDialogProvider;
#endif
@class VLCRendererDiscoverer;
@class VLCRendererDiscovererDescription;
@class VLCRendererItem;
@class VLCFilterParameter;
@class VLCAdjustFilter;
@class VLCMediaMetaData;
@class VLCConsoleLogger;
@class VLCFileLogger;
@class VLCLogMessageFormatter;
@class VLCMediaPlayerChapterDescription;
@class VLCMediaPlayerTitleDescription;

#if TARGET_OS_IPHONE
@class VLCAudio;
@class VLCMediaListPlayer;
@class VLCMediaPlayer;
@class VLCMediaThumbnailer;
@class VLCRendererDiscoverer;
@class VLCRendererDiscovererDescription;
@class VLCRendererItem;
#else
@class VLCVideoView;
#endif
```


## VLCLibrary.h

```objc
#import <Foundation/Foundation.h>

@protocol VLCLogging, VLCEventsConfiguring;

NS_ASSUME_NONNULL_BEGIN

OBJC_VISIBLE
@interface VLCLibrary : NSObject

@property (class, nonatomic, nullable) id<VLCEventsConfiguring> sharedEventsConfiguration;

@property (class, nonatomic, copy, nullable) NSString *currentErrorMessage;

+ (VLCLibrary *)sharedLibrary;

 - (instancetype)initWithOptions:(NSArray *)options;

@property (readwrite, nonatomic, nullable) NSArray< id<VLCLogging> > *loggers;

@property (readonly, copy) NSString *version;

@property (readonly, copy) NSString *compiler;

@property (readonly, copy) NSString *changeset;

- (void)setHumanReadableName:(NSString *)readableName withHTTPUserAgent:(NSString *)userAgent;

- (void)setApplicationIdentifier:(NSString *)identifier withVersion:(NSString *)version andApplicationIconName:(NSString *)icon;

@property (nonatomic, assign) void *instance;

@end

NS_ASSUME_NONNULL_END
```


## VLCLogMessageFormatter.h

```objc
#import <Foundation/Foundation.h>

#import "VLCLogging.h"

NS_ASSUME_NONNULL_BEGIN

@interface VLCLogMessageFormatter : NSObject<VLCLogMessageFormatting>

@end

NS_ASSUME_NONNULL_END
```


## VLCLogging.h

```objc
#ifndef VLCLogging_h
#define VLCLogging_h

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, VLCLogLevel) {
    kVLCLogLevelError = 0,
    kVLCLogLevelWarning,
    kVLCLogLevelInfo,
    kVLCLogLevelDebug
};

@interface VLCLogContext: NSObject

@property (nonatomic, readonly) uintptr_t objectId;

@property (nonatomic, readonly) NSString *objectType;

@property (nonatomic, readonly) NSString *module;

@property (nonatomic, readonly, nullable) NSString *header;

@property (nonatomic, readonly, nullable) NSString *file;

@property (nonatomic, readonly) int line;

@property (nonatomic, readonly, nullable) NSString *function;

@property (nonatomic, readonly) unsigned long threadId;

@end

typedef NS_OPTIONS(int, VLCLogContextFlag) {
    kVLCLogLevelContextNone = 0,
    kVLCLogLevelContextModule = 1<<0,
    kVLCLogLevelContextFileLocation = 1<<1,
    kVLCLogLevelContextCallingFunction = 1<<2,
    kVLCLogLevelContextCustom = 1<<3,
    kVLCLogLevelContextAll = 0xF
};

@protocol VLCLogMessageFormatting <NSObject>

@property (readwrite, nonatomic) VLCLogContextFlag contextFlags;

@property (readwrite, nonatomic, nullable) id customContext;

@required

- (NSString *)formatWithMessage:(NSString *)message
                       logLevel:(VLCLogLevel)level
                        context:(nullable VLCLogContext *)context;

@end

@protocol VLCLogging <NSObject>
@required

@property (readwrite, nonatomic) VLCLogLevel level;

- (void)handleMessage:(NSString *)message
             logLevel:(VLCLogLevel)level
              context:(nullable VLCLogContext *)context;
@end

@protocol VLCFormattedMessageLogging <VLCLogging>
@required

@property (nonatomic, readwrite) id<VLCLogMessageFormatting> formatter;

@end

NS_ASSUME_NONNULL_END

#endif
```


## VLCMedia.h

```objc
#import <Foundation/Foundation.h>

@class VLCTime, VLCMediaTrack, VLCMediaMetaData, VLCMediaSlave;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const VLCMediaMetaChangedNotification NS_SWIFT_NAME(VLCMedia.metaChangedNotification);
FOUNDATION_EXPORT NSNotificationName const VLCMediaSubitemsChangedNotification NS_SWIFT_NAME(VLCMedia.subitemsChangedNotification);
FOUNDATION_EXPORT NSNotificationName const VLCMediaArtworkChangedNotification NS_SWIFT_NAME(VLCMedia.artworkChangedNotification);

@class VLCLibrary;
@class VLCMediaList;
@class VLCMedia;

@protocol VLCMediaDelegate <NSObject>

@optional

- (void)mediaMetaDataDidChange:(VLCMedia *)aMedia;

- (void)mediaDidFinishParsing:(VLCMedia *)aMedia;

- (void)mediaDidChangeSubitems:(VLCMedia *)aMedia;

- (void)mediaDidChangeArtwork:(VLCMedia *)aMedia;

@end

OBJC_VISIBLE
@interface VLCMedia : NSObject

+ (nullable instancetype)mediaWithURL:(NSURL *)anURL;

+ (nullable instancetype)mediaWithPath:(NSString *)aPath;

typedef NS_ENUM(NSInteger, VLCMediaTrackType) {
    VLCMediaTrackTypeUnknown    = -1,
    VLCMediaTrackTypeAudio      = 0,
    VLCMediaTrackTypeVideo      = 1,
    VLCMediaTrackTypeText       = 2
} NS_SWIFT_NAME(VLCMedia.TrackType);

+ (NSString *)codecNameForFourCC:(uint32_t)fourcc trackType:(VLCMediaTrackType)trackType;

+ (nullable instancetype)mediaAsNodeWithName:(NSString *)aName;

- (nullable instancetype)initWithURL:(NSURL *)anURL;

- (nullable instancetype)initWithPath:(NSString *)aPath;

- (nullable instancetype)initWithStream:(NSInputStream *)stream;

- (nullable instancetype)initAsNodeWithName:(NSString *)aName;

typedef NS_ENUM(NSUInteger, VLCMediaOrientation) {
    VLCMediaOrientationTopLeft,
    VLCMediaOrientationTopRight,
    VLCMediaOrientationBottomLeft,
    VLCMediaOrientationBottomRight,
    VLCMediaOrientationLeftTop,
    VLCMediaOrientationLeftBottom,
    VLCMediaOrientationRightTop,
    VLCMediaOrientationRightBottom
};

typedef NS_ENUM(NSUInteger, VLCMediaProjection) {
    VLCMediaProjectionRectangular,
    VLCMediaProjectionEquiRectangular,
    VLCMediaProjectionCubemapLayoutStandard = 0x100
};

typedef NS_ENUM(NSUInteger, VLCMediaType) {
    VLCMediaTypeUnknown,
    VLCMediaTypeFile,
    VLCMediaTypeDirectory,
    VLCMediaTypeDisc,
    VLCMediaTypeStream,
    VLCMediaTypePlaylist,
};

@property (readonly) VLCMediaType mediaType;

- (NSComparisonResult)compare:(nullable VLCMedia *)media;

@property (nonatomic, weak, nullable) id<VLCMediaDelegate> delegate;

@property (nonatomic, readwrite, strong) VLCTime * length;

typedef NS_ENUM(unsigned, VLCMediaParsedStatus)
{
    VLCMediaParsedStatusNone = 0,
    VLCMediaParsedStatusPending,
    VLCMediaParsedStatusSkipped,
    VLCMediaParsedStatusFailed,
    VLCMediaParsedStatusTimeout,
    VLCMediaParsedStatusCancelled,
    VLCMediaParsedStatusDone
};

@property (nonatomic, readonly) VLCMediaParsedStatus parsedStatus;

@property (nonatomic, readonly, strong, nullable) NSURL * url;

@property (nonatomic, readonly, strong, nullable) VLCMediaList * subitems;

@property (nonatomic, readonly) VLCMediaMetaData *metaData;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray<VLCMediaTrack *> *tracksInformation;

typedef NS_ENUM(unsigned, VLCMediaFileStatType) {
    VLCMediaFileStatTypeMtime   = 0,
    VLCMediaFileStatTypeSize    = 1
} NS_SWIFT_NAME(VLCMedia.FileStatType);

typedef NS_ENUM(int, VLCMediaFileStatReturnType) {
    VLCMediaFileStatReturnTypeError     = -1,
    VLCMediaFileStatReturnTypeNotFound  = 0,
    VLCMediaFileStatReturnTypeSuccess   = 1
} NS_SWIFT_NAME(VLCMedia.FileStatReturnType);

- (VLCMediaFileStatReturnType)fileStatValueForType:(const VLCMediaFileStatType)type value:(uint64_t *)value;

- (void)addOption:(NSString *)option;
- (void)addOptions:(NSDictionary*)options;

typedef NS_OPTIONS(unsigned, VLCMediaOption) {
    VLCMediaOptionTrusted = 0x2,
    VLCMediaOptionUnique  = 0x100
} NS_SWIFT_NAME(VLCMedia.Option);

- (void)addOption:(NSString *)option withFlags:(VLCMediaOption)flags;

@property (nonatomic, readonly, copy) NSArray<VLCMediaSlave *> *slaves;

- (BOOL)addSlave:(VLCMediaSlave *)slave;

- (void)clearSlaves;

- (int)storeCookie:(NSString *)cookie
           forHost:(NSString *)host
              path:(NSString *)path;

- (void)clearStoredCookies;

struct VLCMediaStats
{

    const uint64_t         readBytes;
    const float            inputBitrate;

    const uint64_t         demuxReadBytes;
    const float            demuxBitrate;
    const uint64_t         demuxCorrupted;
    const uint64_t         demuxDiscontinuity;

    const uint64_t         decodedVideo;
    const uint64_t         decodedAudio;

    const uint64_t         displayedPictures;
    const uint64_t         latePictures;
    const uint64_t         lostPictures;

    const uint64_t         playedAudioBuffers;
    const uint64_t         lostAudioBuffers;

} NS_SWIFT_NAME(VLCMedia.Stats);
typedef struct VLCMediaStats VLCMediaStats;

@property (nonatomic, readonly) VLCMediaStats statistics;

@end

#pragma mark - VLCMedia+Tracks

@interface VLCMedia (Tracks)

@property(nonatomic, readonly, copy) NSArray<VLCMediaTrack *> *audioTracks;

@property(nonatomic, readonly, copy) NSArray<VLCMediaTrack *> *videoTracks;

@property(nonatomic, readonly, copy) NSArray<VLCMediaTrack *> *textTracks;

@end

#pragma mark - VLCMediaTrack

NS_SWIFT_NAME(VLCMedia.AudioTrack)
@interface VLCMediaAudioTrack : NSObject

@property(nonatomic, readonly) unsigned channelsNumber;

@property(nonatomic, readonly) unsigned rate;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(VLCMedia.VideoTrack)
@interface VLCMediaVideoTrack : NSObject

@property(nonatomic, readonly) unsigned height;

@property(nonatomic, readonly) unsigned width;

@property(nonatomic, readonly) VLCMediaOrientation orientation;

@property(nonatomic, readonly) VLCMediaProjection projection;

@property(nonatomic, readonly) unsigned sourceAspectRatio;

@property(nonatomic, readonly) unsigned sourceAspectRatioDenominator;

@property(nonatomic, readonly) unsigned frameRate;

@property(nonatomic, readonly) unsigned frameRateDenominator;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(VLCMedia.TextTrack)
@interface VLCMediaTextTrack : NSObject

@property(nonatomic, readonly, copy, nullable) NSString *encoding;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(VLCMedia.Track)
@interface VLCMediaTrack : NSObject

@property(nonatomic, readonly) VLCMediaTrackType type;

@property(nonatomic, readonly) u_int32_t codec;

@property(nonatomic, readonly) u_int32_t fourcc;

@property(nonatomic, readonly) int identifier;

@property(nonatomic, readonly) int profile;

@property(nonatomic, readonly) int level;

@property(nonatomic, readonly) unsigned int bitrate;

@property(nonatomic, readonly, copy, nullable) NSString *language;

@property(nonatomic, readonly, copy, nullable) NSString *trackDescription;

@property(nonatomic, readonly, nullable) VLCMediaAudioTrack *audio;

@property(nonatomic, readonly, nullable) VLCMediaVideoTrack *video;

@property(nonatomic, readonly, nullable) VLCMediaTextTrack *text;

- (NSString *)codecName;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(VLCMediaPlayer.Track)
@interface VLCMediaPlayerTrack : VLCMediaTrack

@property (nonatomic, readonly, copy) NSString *trackId;

@property (nonatomic, readonly, getter=isIdStable) BOOL idStable;

@property (nonatomic, readonly, copy) NSString *trackName;

@property (nonatomic, getter=isSelected) BOOL selected;

@property (nonatomic, getter=isSelectedExclusively) BOOL selectedExclusively;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
```


## VLCMediaDiscoverer.h

```objc
#import <Foundation/Foundation.h>

@class VLCLibrary, VLCMediaList, VLCMedia;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(unsigned, VLCMediaDiscovererCategoryType)
{
    VLCMediaDiscovererCategoryTypeDevices = 0,
    VLCMediaDiscovererCategoryTypeLAN,
    VLCMediaDiscovererCategoryTypePodcasts,
    VLCMediaDiscovererCategoryTypeLocalDirectories
};

OBJC_VISIBLE OBJC_EXTERN
NSString *const VLCMediaDiscovererName;
OBJC_VISIBLE OBJC_EXTERN
NSString *const VLCMediaDiscovererLongName;
OBJC_VISIBLE OBJC_EXTERN
NSString *const VLCMediaDiscovererCategory;
OBJC_VISIBLE OBJC_EXTERN
NSString *const VLCMediaDiscovererUpdatedNotification;

@protocol VLCMediaDiscovererDelegate <NSObject>

@optional

- (void)mediaAdded:(VLCMedia *)media parent:(nullable VLCMedia *)parent;

- (void)mediaRemoved:(VLCMedia *)media;

@end

OBJC_VISIBLE
@interface VLCMediaDiscoverer : NSObject

@property (nonatomic, readonly) VLCLibrary *libraryInstance;

@property (weak, nullable) id<VLCMediaDiscovererDelegate> delegate;

+ (NSArray *)availableMediaDiscovererForCategoryType:(VLCMediaDiscovererCategoryType)categoryType;

- (instancetype)initWithName:(NSString *)aServiceName;

- (instancetype)initWithName:(NSString *)aServiceName libraryInstance:(nullable VLCLibrary *)libraryInstance;

- (int)startDiscoverer;

- (void)stopDiscoverer;

@property (weak, readonly, nullable) VLCMediaList *discoveredMedia;

@property (readonly) BOOL isRunning;
@end

NS_ASSUME_NONNULL_END
```


## VLCMediaDownloader.h

```objc
#import <Foundation/Foundation.h>
#import "VLCMedia.h"
#import "VLCMediaList.h"
#import "VLCMediaSlave.h"

NS_ASSUME_NONNULL_BEGIN

@class VLCLibrary;
@class VLCMediaDownloader;
@class VLCMediaDownloadTask;

typedef NS_ENUM(NSInteger, VLCMediaDownloadStatus) {
    VLCMediaDownloadStatusPending = 0,
    VLCMediaDownloadStatusRunning,
    VLCMediaDownloadStatusPaused,
    VLCMediaDownloadStatusFinished,
    VLCMediaDownloadStatusCancelled,
    VLCMediaDownloadStatusError
};

FOUNDATION_EXPORT const NSInteger VLCMediaDownloadConsumedError;
FOUNDATION_EXPORT const NSInteger VLCMediaDownloadConsumedCancel;

@protocol VLCMediaDownloaderDelegate <NSObject>

@required

- (NSInteger)mediaDownloadTask:(VLCMediaDownloadTask *)task
                didReceiveData:(NSData *)data
                      position:(uint64_t)position
                         total:(uint64_t)total;

- (void)mediaDownloadTask:(VLCMediaDownloadTask *)task
          didUpdateStatus:(VLCMediaDownloadStatus)status;

@optional

- (void)mediaDownloadTask:(VLCMediaDownloadTask *)task
        didReceiveSubitems:(VLCMediaList *)subitems;

- (void)mediaDownloadTask:(VLCMediaDownloadTask *)task
          didReceiveSlaves:(NSArray<VLCMediaSlave *> *)slaves;

@end

@interface VLCMediaDownloadTask : NSObject

@property (nonatomic, readonly) VLCMedia *media;
@property (nonatomic, readonly) VLCMediaDownloadStatus status;
@property (nonatomic, getter=isPaused) BOOL paused;

- (void)cancel;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@interface VLCMediaDownloader : NSObject

- (instancetype)init;

- (instancetype)initWithLibrary:(VLCLibrary *)library NS_DESIGNATED_INITIALIZER;

- (nullable VLCMediaDownloadTask *)downloadMedia:(VLCMedia *)media
                                        delegate:(id<VLCMediaDownloaderDelegate>)delegate;

- (void)cancelAll;

@end

NS_ASSUME_NONNULL_END
```


## VLCMediaList.h

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class VLCMedia;
@class VLCMediaList;

OBJC_VISIBLE
@interface VLCMediaList : NSObject

- (instancetype)initWithArray:(nullable NSArray<VLCMedia *> *)array;

- (void)lock;

- (void)unlock;

- (NSUInteger)addMedia:(VLCMedia *)media;

- (void)insertMedia:(VLCMedia *)media atIndex:(NSUInteger)index;

- (BOOL)removeMediaAtIndex:(NSUInteger)index;

- (nullable VLCMedia *)mediaAtIndex:(NSUInteger)index;

- (NSUInteger)indexOfMedia:(VLCMedia *)media;

@property (readonly) NSInteger count;

@property (readonly) BOOL isReadOnly;

@property (readonly) BOOL isEmpty;

@end

NS_ASSUME_NONNULL_END
```


## VLCMediaListPlayer.h

```objc
#import "VLCMediaPlayer.h"

@class VLCMedia, VLCMediaPlayer, VLCMediaList, VLCMediaListPlayer;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VLCRepeatMode) {
    VLCDoNotRepeat,
    VLCRepeatCurrentItem,
    VLCRepeatAllItems
};

@protocol VLCMediaListPlayerDelegate <NSObject>
@optional

- (void)mediaListPlayer:(VLCMediaListPlayer *)player
              nextMedia:(VLCMedia *)media;

- (void)mediaListPlayerStopped:(VLCMediaListPlayer *)player;
@end

OBJC_VISIBLE
@interface VLCMediaListPlayer : NSObject

@property (readwrite, nullable) VLCMediaList *mediaList;

@property (readwrite, nullable) VLCMedia *rootMedia;

@property (readonly) VLCMediaPlayer *mediaPlayer;

@property (nonatomic, weak, nullable) id <VLCMediaListPlayerDelegate> delegate;

- (instancetype)initWithDrawable:(id)drawable;

- (instancetype)initWithOptions:(NSArray *)options;

- (instancetype)initWithOptions:(nullable NSArray *)options andDrawable:(nullable id)drawable;

- (void)play;

- (void)pause;

- (void)stop;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL next;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL previous;

- (void)playItemAtNumber:(NSNumber *)index;

@property (readwrite) VLCRepeatMode repeatMode;

@property (nonatomic, readonly, getter=isPlaying) BOOL playing;

@property (nonatomic, readonly) VLCMediaPlayerState state;

- (void)playMedia:(VLCMedia *)media;

@end

NS_ASSUME_NONNULL_END
```


## VLCMediaMetaData.h

```objc
#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIImage.h>
#else
#import <AppKit/NSImage.h>
#endif

typedef
#if TARGET_OS_IPHONE
UIImage
#else
NSImage
#endif
VLCPlatformImage;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(VLCMedia.MetaData)
@interface VLCMediaMetaData : NSObject

@property(nonatomic, copy, nullable) NSString *title;

@property(nonatomic, copy, nullable) NSString *artist;

@property(nonatomic, copy, nullable) NSString *genre;

@property(nonatomic, copy, nullable) NSString *copyright;

@property(nonatomic, copy, nullable) NSString *album;

@property(nonatomic) unsigned trackNumber;

@property(nonatomic, copy, nullable) NSString *metaDescription;

@property(nonatomic, copy, nullable) NSString *rating;

@property(nonatomic, copy, nullable) NSString *date;

@property(nonatomic, copy, nullable) NSString *setting;

@property(nonatomic, nullable) NSURL *url;

@property(nonatomic, copy, nullable) NSString *language;

@property(nonatomic, copy, nullable) NSString *nowPlaying;

@property(nonatomic, copy, nullable) NSString *publisher;

@property(nonatomic, copy, nullable) NSString *encodedBy;

@property(nonatomic, nullable) NSURL *artworkURL;

@property(nonatomic) unsigned trackID;

@property(nonatomic) unsigned trackTotal;

@property(nonatomic, copy, nullable) NSString *director;

@property(nonatomic) unsigned season;

@property(nonatomic) unsigned episode;

@property(nonatomic, copy, nullable) NSString *showName;

@property(nonatomic, copy, nullable) NSString *actors;

@property(nonatomic, copy, nullable) NSString *albumArtist;

@property(nonatomic) unsigned discNumber;

@property(nonatomic) unsigned discTotal;

@property(nonatomic, readonly, nullable) VLCPlatformImage *artwork;

@property(nonatomic, copy, readonly, nullable) NSDictionary<NSString *, NSString *> *extra;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)save;

- (void)prefetch;

- (void)clearCache;

- (nullable NSString *)extraValueForKey:(NSString *)key;

- (void)setExtraValue:(nullable NSString *)value forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
```


## VLCMediaParser.h

```objc
#import <Foundation/Foundation.h>
#import "VLCMedia.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VLCMediaParserDelegate <NSObject>

@required

- (void)mediaFinishedParsing:(VLCMedia *)media withStatus:(VLCMediaParsedStatus)status;

@end

@interface VLCMediaParser : NSObject

typedef NS_OPTIONS(int, VLCMediaParsingOptions) {
    VLCMediaParse               = 0x01,
    VLCMediaFetchLocal          = 0x02,
    VLCMediaFetchNetwork        = 0x04,
    VLCMediaDoInteract          = 0x08,
};

@property (weak, nullable) id<VLCMediaParserDelegate> delegate;

+ (instancetype)sharedParser;

- (instancetype)initWithLibrary:(VLCLibrary *)library timeout:(int)timeout;

- (int)queueMedia:(VLCMedia *)media options:(VLCMediaParsingOptions)options;

- (void)cancelParsingForMedia:(VLCMedia *)media;

- (void)cancelAllParsing;

@end

NS_ASSUME_NONNULL_END
```


## VLCMediaPlayer.h

```objc
#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
# import <UIKit/UIImage.h>
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VLCMediaTrackType) NS_SWIFT_NAME(VLCMedia.TrackType);
@class VLCLibrary, VLCMedia, VLCTime, VLCAudio, VLCMediaPlayer, VLCMediaPlayerTrack, VLCAdjustFilter, VLCAudioEqualizer, VLCMediaPlayerTitleDescription, VLCMediaPlayerChapterDescription, VLCProgramDescription;
#if !TARGET_OS_IPHONE
@class VLCVideoView, VLCVideoLayer;
#endif
#if !TARGET_OS_TV
@class VLCRendererItem;
#endif

FOUNDATION_EXPORT NSNotificationName const VLCMediaPlayerTimeChangedNotification NS_SWIFT_NAME(VLCMediaPlayer.timeChangedNotification);
FOUNDATION_EXPORT NSNotificationName const VLCMediaPlayerStateChangedNotification NS_SWIFT_NAME(VLCMediaPlayer.stateChangedNotification);
FOUNDATION_EXPORT NSNotificationName const VLCMediaPlayerTitleSelectionChangedNotification NS_SWIFT_NAME(VLCMediaPlayer.titleSelectionChangedNotification);
FOUNDATION_EXPORT NSNotificationName const VLCMediaPlayerTitleListChangedNotification NS_SWIFT_NAME(VLCMediaPlayer.titleListChangedNotification);
FOUNDATION_EXPORT NSNotificationName const VLCMediaPlayerChapterChangedNotification NS_SWIFT_NAME(VLCMediaPlayer.chapterChangedNotification);
FOUNDATION_EXPORT NSNotificationName const VLCMediaPlayerSnapshotTakenNotification NS_SWIFT_NAME(VLCMediaPlayer.snapshotTakenNotification);
FOUNDATION_EXPORT NSNotificationName const VLCMediaPlayerProgramListChangedNotification NS_SWIFT_NAME(VLCMediaPlayer.programListChangedNotification);
FOUNDATION_EXPORT NSNotificationName const VLCMediaPlayerProgramSelectionChangedNotification NS_SWIFT_NAME(VLCMediaPlayer.programSelectionChangedNotification);
FOUNDATION_EXPORT NSNotificationName const VLCMediaPlayerCapabilitiesChangedNotification NS_SWIFT_NAME(VLCMediaPlayer.capabilitiesChangedNotification);

typedef NS_ENUM(NSInteger, VLCMediaPlayerState)
{
    VLCMediaPlayerStateNothingSpecial,
    VLCMediaPlayerStateOpening,
    VLCMediaPlayerStatePlaying,
    VLCMediaPlayerStatePaused,
    VLCMediaPlayerStateStopped,
    VLCMediaPlayerStateStopping,
    VLCMediaPlayerStateError,
};

typedef NS_ENUM(unsigned, VLCMediaPlaybackNavigationAction)
{
    VLCMediaPlaybackNavigationActionActivate = 0,
    VLCMediaPlaybackNavigationActionUp,
    VLCMediaPlaybackNavigationActionDown,
    VLCMediaPlaybackNavigationActionLeft,
    VLCMediaPlaybackNavigationActionRight
};

typedef NS_ENUM(NSInteger, VLCDeinterlace)
{
    VLCDeinterlaceAuto = -1,
    VLCDeinterlaceOn = 1,
    VLCDeinterlaceOff = 0
};

typedef NS_ENUM(NSInteger, VLCMediaPlayerFrameStepResult)
{
    VLCMediaPlayerFrameStepResultSuccess = 0,
    VLCMediaPlayerFrameStepResultPending,
    VLCMediaPlayerFrameStepResultVideoError,
    VLCMediaPlayerFrameStepResultCannotPause,
    VLCMediaPlayerFrameStepResultInvalidState,
    VLCMediaPlayerFrameStepResultCannotSeekBack,
};

OBJC_VISIBLE OBJC_EXTERN
NSString * VLCMediaPlayerStateToString(VLCMediaPlayerState state);

@protocol VLCMediaPlayerDelegate <NSObject>

@optional

- (void)mediaPlayerStateChanged:(VLCMediaPlayerState)newState;

- (void)mediaPlayerBufferingChanged:(float)progress;

- (void)mediaPlayerTrackAdded:(NSString *)trackId
                     withType:(VLCMediaTrackType)trackType;

- (void)mediaPlayerTrackRemoved:(NSString *)trackId
                       withType:(VLCMediaTrackType)trackType;

- (void)mediaPlayerTrackUpdated:(NSString *)trackId
                       withType:(VLCMediaTrackType)trackType;

- (void)mediaPlayerTrackSelected:(VLCMediaTrackType)trackType
                      selectedId:(NSString *)unselectedId
                    unselectedId:(NSString*)unselectedId;

- (void)mediaPlayerLengthChanged:(int64_t)length;

- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification;

- (void)mediaPlayerTitleSelectionChanged:(NSNotification *)aNotification;

- (void)mediaPlayerTitleListChanged:(NSNotification *)aNotification;

- (void)mediaPlayerChapterChanged:(NSNotification *)aNotification;

- (void)mediaPlayerProgramListChanged:(NSNotification *)aNotification;

- (void)mediaPlayerProgramSelectionChanged:(NSNotification *)aNotification;

- (void)mediaPlayerSnapshot:(NSNotification *)aNotification;

- (void)mediaPlayerStartedRecording:(VLCMediaPlayer *)player;

- (void)mediaPlayer:(VLCMediaPlayer *)player recordingStoppedAtURL:(nullable NSURL *)url;

- (void)mediaPlayer:(VLCMediaPlayer *)player nextFrameSteppedWithResult:(VLCMediaPlayerFrameStepResult)result;

- (void)mediaPlayer:(VLCMediaPlayer *)player previousFrameSteppedWithResult:(VLCMediaPlayerFrameStepResult)result;

@end

OBJC_VISIBLE
@interface VLCMediaPlayer : NSObject

@property (nonatomic, readonly) VLCLibrary *libraryInstance;

@property (weak, nonatomic, nullable) id<VLCMediaPlayerDelegate> delegate;

#if !TARGET_OS_IPHONE

- (instancetype)initWithVideoView:(VLCVideoView *)aVideoView;

- (instancetype)initWithVideoLayer:(VLCVideoLayer *)aVideoLayer;
#endif

- (instancetype)initWithLibrary:(VLCLibrary *)library;

- (instancetype)initWithOptions:(NSArray *)options;

- (instancetype)initWithLibVLCInstance:(void *)playerInstance andLibrary:(VLCLibrary *)library;

#pragma mark -
#pragma mark video functionality

#if !TARGET_OS_IPHONE

- (void)setVideoView:(VLCVideoView *)aVideoView;

- (void)setVideoLayer:(VLCVideoLayer *)aVideoLayer;
#endif

@property (strong, nullable) id drawable;

@property (nonatomic, copy, nullable) NSString *videoAspectRatio;

- (void)setCropRatioWithNumerator:(unsigned int)numerator denominator:(unsigned int)denominator;

@property (nonatomic) float scaleFactor;

- (void)saveVideoSnapshotAt:(NSString *)path withWidth:(int)width andHeight:(int)height;

- (void)setDeinterlaceFilter: (nullable NSString *)name;

- (void)setDeinterlace:(VLCDeinterlace)deinterlace withFilter:(NSString *)name;

typedef NS_ENUM(NSInteger, VLCVideoFitMode) {
    VLCVideoFitNone = 0,
    VLCVideoFitSmaller,
    VLCVideoFitLarger,
    VLCVideoFitWidth,
    VLCVideoFitHeight
} NS_SWIFT_NAME(VLCMediaPlayer.VideoFitMode);

@property (nonatomic) VLCVideoFitMode videoFitMode;

@property (nonatomic, readonly) VLCAdjustFilter * _Nonnull adjustFilter;

@property (nonatomic) BOOL adjustFilterEnabled __deprecated_msg("Use -[VLCMediaPlayer adjustFilter].enabled instead");

@property (nonatomic) float contrast __deprecated_msg("Use -[VLCMediaPlayer adjustFilter].contrast instead");

@property (nonatomic) float brightness __deprecated_msg("Use -[VLCMediaPlayer adjustFilter].brightness instead");

@property (nonatomic) float hue __deprecated_msg("Use -[VLCMediaPlayer adjustFilter].hue instead");

@property (nonatomic) float saturation __deprecated_msg("Use -[VLCMediaPlayer adjustFilter].saturation instead");

@property (nonatomic) float gamma __deprecated_msg("Use -[VLCMediaPlayer adjustFilter].gamma instead");

@property (nonatomic) float rate;

@property (nonatomic, readonly, weak) VLCAudio * audio;

@property (NS_NONATOMIC_IOSONLY, readonly) CGSize videoSize;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL hasVideoOut;

#pragma mark -
#pragma mark time

@property (NS_NONATOMIC_IOSONLY, strong) VLCTime *time;

@property (nonatomic, readonly, weak) VLCTime *remainingTime;

@property (nonatomic) int64_t minimalTimePeriod;

@property (nonatomic) NSTimeInterval timeChangeUpdateInterval;

#pragma mark -
#pragma mark ES track handling

typedef NS_ENUM(unsigned, VLCMediaPlaybackSlaveType)
{
    VLCMediaPlaybackSlaveTypeSubtitle = 0,
    VLCMediaPlaybackSlaveTypeAudio
};

- (int)addPlaybackSlave:(NSURL *)slaveURL type:(VLCMediaPlaybackSlaveType)slaveType enforce:(BOOL)enforceSelection;

@property (readwrite) NSInteger currentVideoSubTitleDelay;

@property (readwrite) float currentSubTitleFontScale;

@property (readwrite) int currentChapterIndex;

- (void)previousChapter;

- (void)nextChapter;

- (int)numberOfChaptersForTitle:(int)titleIndex;

@property(nonatomic, nullable) VLCMediaPlayerChapterDescription *currentChapterDescription;

- (NSArray<VLCMediaPlayerChapterDescription *> *)chapterDescriptionsOfTitle:(int)titleIndex;

@property (readwrite) int currentTitleIndex;

@property (readonly) int numberOfTitles;

@property(nonatomic, nullable) VLCMediaPlayerTitleDescription *currentTitleDescription;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray<VLCMediaPlayerTitleDescription *> *titleDescriptions;

@property (readonly) int indexOfLongestTitle;

#pragma mark -
#pragma mark program selection

@property (nonatomic, readonly, copy, nullable) NSArray<VLCProgramDescription *> *programs;

@property (nonatomic, readonly, nullable) VLCProgramDescription *selectedProgram;

- (void)selectProgramWithIdentifier:(int)groupID;

@property (nonatomic, readonly, getter=isProgramScrambled) BOOL programScrambled;

#pragma mark -
#pragma mark A-B loop

typedef NS_ENUM(NSUInteger, VLCMediaPlayerABLoopState) {
    VLCMediaPlayerABLoopStateNone = 0,
    VLCMediaPlayerABLoopStateA,
    VLCMediaPlayerABLoopStateB
} NS_SWIFT_NAME(VLCMediaPlayer.ABLoopState);

- (BOOL)setABLoopFromTime:(VLCTime *)from toTime:(VLCTime *)to;

- (BOOL)setABLoopFromPosition:(double)from toPosition:(double)to;

- (BOOL)resetABLoop;

@property (nonatomic, readonly) VLCMediaPlayerABLoopState abLoopState;
@property (nonatomic, readonly, nullable) VLCTime *abLoopStartTime;
@property (nonatomic, readonly, nullable) VLCTime *abLoopEndTime;

#pragma mark -
#pragma mark audio functionality

typedef NS_ENUM(NSUInteger, VLCAudioStereoMode) {
    VLCAudioStereoModeUnset = 0,
    VLCAudioStereoModeStereo = 1,
    VLCAudioStereoModeRStereo = 2,
    VLCAudioStereoModeLeft = 3,
    VLCAudioStereoModeRight = 4,
    VLCAudioStereoModeDolbys = 5,
    VLCAudioStereoModeMono = 7
} NS_SWIFT_NAME(VLCMediaPlayer.AudioStereoMode);

@property (nonatomic) VLCAudioStereoMode audioStereoMode;

typedef NS_ENUM(unsigned, VLCAudioMixMode)
{
    VLCAudioMixModeUnset = 0,
    VLCAudioMixModeStereo = 1,
    VLCAudioMixModeBinaural = 2,
    VLCAudioMixMode4_0 = 3,
    VLCAudioMixMode5_1 = 4,
    VLCAudioMixMode7_1 = 5,
} NS_SWIFT_NAME(VLCMediaPlayer.AudioMixMode);

@property (nonatomic) VLCAudioMixMode audioMixMode;

@property (readwrite) NSInteger currentAudioPlaybackDelay;

#pragma mark -
#pragma mark equalizer

@property (nonatomic, nullable) VLCAudioEqualizer *equalizer;

#pragma mark -
#pragma mark media handling

@property (NS_NONATOMIC_IOSONLY, strong, nullable) VLCMedia *media;

#pragma mark -
#pragma mark playback operations

- (void)play;

- (void)pause;

- (void)stop;

- (void)gotoNextFrame;

- (void)gotoPreviousFrame;

- (void)fastForward;

- (void)fastForwardAtRate:(float)rate;

- (void)rewind;

- (void)rewindAtRate:(float)rate;

- (void)jumpWithOffset:(int)offset;

- (BOOL)jumpWithOffset:(int)interval completion:(dispatch_block_t)completion;

- (void)jumpBackward:(double)interval;

- (void)jumpForward:(double)interval;

- (void)extraShortJumpBackward;

- (void)extraShortJumpForward;

- (void)shortJumpBackward;

- (void)shortJumpForward;

- (void)mediumJumpBackward;

- (void)mediumJumpForward;

- (void)longJumpBackward;

- (void)longJumpForward;

- (void)performNavigationAction:(VLCMediaPlaybackNavigationAction)action;

- (BOOL)updateViewpoint:(float)yaw pitch:(float)pitch roll:(float)roll fov:(float)fov absolute:(BOOL)absolute;

@property (nonatomic) float yaw;

@property (nonatomic) float pitch;

@property (nonatomic) float roll;

@property (nonatomic) float fov;

#pragma mark -
#pragma mark playback information

@property (NS_NONATOMIC_IOSONLY, getter=isPlaying, readonly) BOOL playing;

@property (NS_NONATOMIC_IOSONLY, readonly) VLCMediaPlayerState state;

@property (NS_NONATOMIC_IOSONLY) double position;

@property (NS_NONATOMIC_IOSONLY, getter=isSeekable, readonly) BOOL seekable;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL canPause;

@property (NS_NONATOMIC_IOSONLY, readonly, copy, nullable) NSArray *snapshots;

#if TARGET_OS_IPHONE

@property (NS_NONATOMIC_IOSONLY, readonly, nullable) UIImage *lastSnapshot;
#else

@property (NS_NONATOMIC_IOSONLY, readonly, nullable) NSImage *lastSnapshot;
#endif

- (void)startRecordingAtPath:(NSString *)path;

- (void)stopRecording;

#pragma mark -
#pragma mark Renderer
#if !TARGET_OS_TV

- (BOOL)setRendererItem:(nullable VLCRendererItem *)item;
#endif
@end

#pragma mark - VLCMediaPlayer+Tracks

@interface VLCMediaPlayer (Tracks)

@property(nonatomic, readonly, copy) NSArray<VLCMediaPlayerTrack *> *audioTracks;

@property(nonatomic, readonly, copy) NSArray<VLCMediaPlayerTrack *> *videoTracks;

@property(nonatomic, readonly, copy) NSArray<VLCMediaPlayerTrack *> *textTracks;

- (void)selectTrackAtIndex:(NSInteger)index type:(VLCMediaTrackType)type;

- (void)deselectAllAudioTracks;

- (void)deselectAllVideoTracks;

- (void)selectTextTracks:(NSArray<VLCMediaPlayerTrack *> *)tracks;

- (void)deselectAllTextTracks;

@end

NS_ASSUME_NONNULL_END
```


## VLCMediaPlayerTitleDescription.h

```objc
#import <Foundation/Foundation.h>

@class VLCTime;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - VLCMediaPlayerChapterDescription

NS_SWIFT_NAME(VLCMediaPlayer.ChapterDescription)
@interface VLCMediaPlayerChapterDescription : NSObject

@property (nonatomic, readonly) VLCTime *timeOffset;

@property (nonatomic, readonly) VLCTime *durationTime;

@property (nonatomic, readonly, copy, nullable) NSString *name;

@property (nonatomic, readonly) int chapterIndex;

@property (nonatomic, readonly) int titleIndex;

@property (nonatomic, readonly, nullable) NSURL *mediaURL;

@property (nonatomic, getter=isCurrent, readonly) BOOL current;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (void)setCurrent;

@end

#pragma mark - VLCMediaPlayerTitleType

typedef NS_OPTIONS(unsigned, VLCMediaPlayerTitleType) {
    VLCMediaPlayerTitleTypeMenu         = 0x01,
    VLCMediaPlayerTitleTypeInteractive  = 0x02
} NS_SWIFT_NAME(VLCMediaPlayer.TitleType);

#pragma mark - VLCMediaPlayerTitleDescription

NS_SWIFT_NAME(VLCMediaPlayer.TitleDescription)
@interface VLCMediaPlayerTitleDescription : NSObject

@property (nonatomic, readonly) VLCTime *durationTime;

@property (nonatomic, readonly, copy, nullable) NSString *name;

@property (nonatomic, readonly) VLCMediaPlayerTitleType titleType;

@property (nonatomic, readonly, copy) NSArray<VLCMediaPlayerChapterDescription *> *chapterDescriptions;

@property (nonatomic, readonly) int titleIndex;

@property (nonatomic, readonly, nullable) NSURL *mediaURL;

@property (nonatomic, readonly, getter=isMenu) BOOL menu;

@property (nonatomic, readonly, getter=isCurrent) BOOL current;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (void)setCurrent;

- (void)navigateActivate;

- (void)navigateUp;

- (void)navigateDown;

- (void)navigateLeft;

- (void)navigateRight;

- (void)navigatePopup;

@end

#pragma mark - VLCProgramDescription

NS_SWIFT_NAME(VLCMediaPlayer.ProgramDescription)
@interface VLCProgramDescription : NSObject

@property (nonatomic, readonly) int groupID;
@property (nonatomic, readonly, copy, nullable) NSString *name;
@property (nonatomic, readonly, getter=isSelected) BOOL selected;
@property (nonatomic, readonly, getter=isScrambled) BOOL scrambled;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (void)setCurrent;

@end

NS_ASSUME_NONNULL_END
```


## VLCMediaSlave.h

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, VLCMediaSlaveType) {
    VLCMediaSlaveTypeSubtitle = 0,
    VLCMediaSlaveTypeAudio
};

@interface VLCMediaSlave : NSObject

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) VLCMediaSlaveType type;
@property (nonatomic, readonly) NSUInteger priority;

- (instancetype)initWithURL:(NSURL *)URL
                       type:(VLCMediaSlaveType)type
                   priority:(NSUInteger)priority NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
```


## VLCMediaThumbnailer.h

```objc
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class VLCMedia, VLCLibrary, VLCTime;
@protocol VLCMediaThumbnailerDelegate;

OBJC_VISIBLE
@interface VLCMediaThumbnailer : NSObject

+ (VLCMediaThumbnailer *)thumbnailerWithMedia:(VLCMedia *)media andDelegate:(id<VLCMediaThumbnailerDelegate>)delegate;

+ (VLCMediaThumbnailer *)thumbnailerWithMedia:(VLCMedia *)media delegate:(id<VLCMediaThumbnailerDelegate>)delegate andVLCLibrary:(nullable VLCLibrary *)library;

- (void)fetchThumbnail;

- (void)cancel;

@property (readwrite, weak, nonatomic, nullable) id<VLCMediaThumbnailerDelegate> delegate;

@property (readwrite, nonatomic) VLCMedia *media;

@property (readwrite, assign, nonatomic, nullable) CGImageRef thumbnail;

@property (readwrite, assign, nonatomic) CGFloat thumbnailHeight;

@property (readwrite, assign, nonatomic) CGFloat thumbnailWidth;

@property (readwrite, assign, nonatomic) float snapshotPosition;

@property (readwrite, nonatomic, nullable) VLCTime *snapshotTime;

@property (readwrite, assign, nonatomic) BOOL hardwareDecodingEnabled;

@property (readwrite, assign, nonatomic) BOOL preciseSeek;

@property (readwrite, assign, nonatomic) BOOL cropsToFit;
@end

@protocol VLCMediaThumbnailerDelegate
@required

- (void)mediaThumbnailerDidTimeOut:(VLCMediaThumbnailer *)mediaThumbnailer;

- (void)mediaThumbnailer:(VLCMediaThumbnailer *)mediaThumbnailer didFinishThumbnail:(CGImageRef)thumbnail;
@end

NS_ASSUME_NONNULL_END
```


## VLCRendererDiscoverer.h

```objc
@class VLCRendererItem, VLCRendererDiscoverer;

NS_ASSUME_NONNULL_BEGIN

@protocol VLCRendererDiscovererDelegate <NSObject>

- (void)rendererDiscovererItemAdded:(VLCRendererDiscoverer *)rendererDiscoverer
                               item:(VLCRendererItem *)item;
- (void)rendererDiscovererItemDeleted:(VLCRendererDiscoverer *)rendererDiscoverer
                               item:(VLCRendererItem *)item;

@end

OBJC_VISIBLE
@interface VLCRendererDiscovererDescription : NSObject

@property (nonatomic, readonly, copy) NSString *name;

@property (nonatomic, readonly, copy) NSString *longName;

- (instancetype)initWithName:(NSString *)name longName:(NSString *)longName;

@end

OBJC_VISIBLE
@interface VLCRendererDiscoverer : NSObject

@property (nonatomic, readonly, copy) NSString *name;

@property (nonatomic, readonly, copy) NSArray<VLCRendererItem *> *renderers;

@property (nonatomic, weak, nullable) id <VLCRendererDiscovererDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;

- (nullable instancetype)initWithName:(NSString *)name;

- (NSArray<VLCRendererItem *> *)renderers;

- (BOOL)start;

- (void)stop;

+ (nullable NSArray<VLCRendererDiscovererDescription *> *)list;

@end

NS_ASSUME_NONNULL_END
```


## VLCRendererItem.h

```objc
NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSInteger, VLCRendererPlay) {

    VLCRendererPlaysAudio = 1 << 0,

    VLCRendererPlaysVideo = 1 << 1
};

OBJC_VISIBLE
@interface VLCRendererItem : NSObject

@property (nonatomic, readonly, copy) NSString *name;

@property (nonatomic, readonly, copy) NSString *type;

@property (nonatomic, readonly, copy) NSString *iconURI;

@property (nonatomic, readonly, assign) int flags;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
```


## VLCTime.h

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

OBJC_VISIBLE
@interface VLCTime : NSObject

+ (VLCTime *)nullTime;

+ (VLCTime *)timeWithNumber:(nullable NSNumber *)aNumber;

+ (VLCTime *)timeWithInt:(int)aInt;

+ (int64_t)clock;

+ (int64_t)delay:(int64_t)ts;

- (instancetype)initWithNumber:(nullable NSNumber *)aNumber;

- (instancetype)initWithInt:(int)aInt;

@property (nonatomic, readonly, nullable) NSNumber * value;

@property (readonly) NSString * stringValue;

@property (readonly) NSString * verboseStringValue;

@property (readonly) NSString * minuteStringValue;

@property (readonly) int intValue;

@property (readonly) NSString * subSecondStringValue;

- (NSComparisonResult)compare:(VLCTime *)aTime;

- (BOOL)isEqual:(nullable id)object;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
```


## VLCTranscoder.h

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class VLCTranscoder;
@protocol VLCTranscoderDelegate <NSObject>

@optional

- (void)transcode:(VLCTranscoder *)transcoder finishedSucessfully:(BOOL)success;

@end

OBJC_VISIBLE
@interface VLCTranscoder: NSObject

@property (weak, nonatomic, nullable) id<VLCTranscoderDelegate> delegate;

- (BOOL)reencodeAndMuxSRTFile:(NSString *)srtPath toMP4File:(NSString *)mp4Path outputPath:(NSString *)outPath;

@end

NS_ASSUME_NONNULL_END
```
