#import "BookmarksBarBorder.h"

@implementation DPBookmarksBorderView
- (NSView *)hitTest:(NSPoint)point { return nil; }
- (BOOL)isAccessibilityElement { return NO; }
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}
- (void)drawRect:(NSRect)dirtyRect {
    NSView *source = self.source;
    if (!source || NSIsEmptyRect(source.bounds)) return;
    // AIDEV-NOTE: reuse Dia’s rendered divider, including its current theme color; do not guess a gray.
    NSBitmapImageRep *image = [source bitmapImageRepForCachingDisplayInRect:source.bounds];
    [source cacheDisplayInRect:source.bounds toBitmapImageRep:image];
    self.renderedColor = [image colorAtX:image.pixelsWide / 2 y:0];
    [image drawInRect:self.bounds];
}
@end

// AIDEV-NOTE: a new page can draw the bookmarks border before Dia paints the URL divider's layer.
// Refresh after Dia paints that source, rather than keeping the first transparent snapshot.
static void DPDivider_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPDivider_updateLayer, self);
    NSView *bar = DPSubview(self.superview.superview, DPDiaBookmarksBar);
    DPBookmarksBorderView *border = (id)DPSubview(bar, "DPBookmarksBorderView");
    if (border.source == self) border.needsDisplay = YES;
}

static void DPUpdateBookmarksBorder(NSView *bar) {
    DPBookmarksBorderView *border = (id)DPSubview(bar, "DPBookmarksBorderView");
    NSView *source = DPBookmarksBarBorder.on ? DPBookmarksToolbarDivider(bar) : nil;
    if (!source || NSIsEmptyRect(bar.bounds)) {
        [border removeFromSuperview];
        return;
    }
    if (!border) {
        border = [DPBookmarksBorderView new];
        [bar addSubview:border positioned:NSWindowAbove relativeTo:nil];
    }
    CGFloat height = NSHeight(source.frame);
    CGFloat y = bar.isFlipped ? NSMaxY(bar.bounds) - height : NSMinY(bar.bounds);
    border.frame = NSMakeRect(NSMinX(bar.bounds), y, NSWidth(bar.bounds), height);
    border.autoresizingMask = NSViewWidthSizable | (bar.isFlipped ? NSViewMinYMargin : NSViewMaxYMargin);
    DPHookClass(source.class, @selector(updateLayer), (IMP)DPDivider_updateLayer);
    border.source = source;
    border.needsDisplay = YES;
}

static void DPBookmarks_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPBookmarks_layout, self);
    DPUpdateBookmarksBorder(self);
}

static void DPApplyBookmarksBorder(DPPatch *patch) {
    for (NSView *bar in DPFindViews(DPDiaBookmarksBar)) DPUpdateBookmarksBorder(bar);
}

static void DPInstallBookmarksBorder(void) {
    DPHook(DPDiaBookmarksBar, @selector(layout), (IMP)DPBookmarks_layout);
    DPOnLaunch(^{ DPApplyBookmarksBorder(&DPBookmarksBarBorder); });
}

DP_PATCH(DPBookmarksBarBorder) {
    .key = @"bookmarksBarBorder",
    .order = 25,
    .title = @"Bookmarks bar bottom border",
    .detail = @"Add a divider below bookmarks that matches the URL bar divider.",
    .symbol = @"rectangle.bottomthird.inset.filled",
    .tint = @"systemGrayColor",
    .classes = DPClasses(DPDiaBookmarksBar, DPDiaToolbar),
    .install = DPInstallBookmarksBorder,
    .apply = DPApplyBookmarksBorder,
    .verify = DPVerifyBookmarksBarBorder,
};
