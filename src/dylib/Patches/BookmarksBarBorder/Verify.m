#import "BookmarksBarBorder.h"

NSView *DPBookmarksToolbarDivider(NSView *bookmarks) {
    NSView *toolbar = DPSubview(bookmarks.superview, DPDiaToolbar);
    for (NSView *view in toolbar.subviews) {
        CGFloat bottom = toolbar.isFlipped ? NSMaxY(view.frame) : NSMinY(view.frame);
        CGFloat edge = toolbar.isFlipped ? NSMaxY(toolbar.bounds) : NSMinY(toolbar.bounds);
        if (!view.hidden && NSWidth(view.frame) == NSWidth(toolbar.bounds) &&
            NSHeight(view.frame) > 0 && NSHeight(view.frame) <= 1 && fabs(bottom - edge) < 0.01) return view;
    }
    return nil;
}

NSString *DPVerifyBookmarksBarBorder(DPPatch *patch) {
    NSArray<NSView *> *bars = DPFindViews(DPDiaBookmarksBar);
    if (!bars.count) return @"no bookmarks bar found";
    for (NSView *bar in bars) {
        NSArray<NSView *> *borders = [bar.subviews filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(NSView *view, NSDictionary *_) {
                return [NSStringFromClass(view.class) isEqualToString:@"DPBookmarksBorderView"];
            }]];
        if (!patch->on) {
            if (borders.count) return @"bookmarks divider remains when switched off";
            continue;
        }
        if (bar.hiddenOrHasHiddenAncestor || NSHeight(bar.bounds) == 0) continue;
        NSView *source = DPBookmarksToolbarDivider(bar);
        if (!source) return @"no URL bar divider found to match";
        if (borders.count != 1) return @"bookmarks bar needs exactly one bottom divider";
        NSView *border = borders.firstObject;
        if (bar.subviews.lastObject != border) return @"bookmarks divider is covered by a later subview";
        CGFloat y = bar.isFlipped ? NSMaxY(bar.bounds) - NSHeight(source.frame) : NSMinY(bar.bounds);
        NSRect expected = NSMakeRect(NSMinX(bar.bounds), y, NSWidth(bar.bounds), NSHeight(source.frame));
        if (!NSEqualRects(border.frame, expected)) return @"divider does not span the bottom of the bookmarks bar";
        if (border.hidden || border.alphaValue != 1) return @"bookmarks divider is invisible";
        if ([border hitTest:NSMakePoint(NSMidX(border.frame), NSMidY(border.frame))]) return @"divider intercepts bookmarks clicks";
        NSBitmapImageRep *original = [source bitmapImageRepForCachingDisplayInRect:source.bounds];
        [source cacheDisplayInRect:source.bounds toBitmapImageRep:original];
        NSColor *a = [[original colorAtX:original.pixelsWide / 2 y:0] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        if (bar.alphaValue == 0) continue; // A hidden toolbar has not necessarily drawn its divider yet.
        // Inspect the actual last draw; forcing a fresh render here would conceal a first-draw bug.
        NSColor *b = [((DPBookmarksBorderView *)border).renderedColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        if (!a || !b || fabs(a.redComponent - b.redComponent) > 0.01 || fabs(a.greenComponent - b.greenComponent) > 0.01 ||
            fabs(a.blueComponent - b.blueComponent) > 0.01 || fabs(a.alphaComponent - b.alphaComponent) > 0.01)
            return @"bookmarks divider does not match the URL bar divider color";
    }
    return nil;
}
