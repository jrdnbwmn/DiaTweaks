#import "StdPatch/StdPatch.h"
extern DPPatch DPBookmarksBarBorder;
NSView *DPBookmarksToolbarDivider(NSView *bookmarks);
NSString *DPVerifyBookmarksBarBorder(DPPatch *patch);

@interface DPBookmarksBorderView : NSView
@property(nonatomic, weak) NSView *source;
@property(nonatomic, strong) NSColor *renderedColor;
@end
