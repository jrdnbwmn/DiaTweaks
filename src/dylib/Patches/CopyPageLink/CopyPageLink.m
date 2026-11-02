#import "StdPatch/StdPatch.h"
#import <objc/message.h>

static NSString *const DPCopyLinkID = @"diapatches.copyPageLink";
extern DPPatch DPCopyPageLink;
static char DPFieldFrameKey, DPToastKey;

static BOOL DPCopyCurrentLink(NSPasteboard *pasteboard) {
    id app = NSApp.delegate;
    if (![app respondsToSelector:@selector(appleScriptWindows)]) return NO;
    NSArray *windows = ((id (*)(id, SEL))objc_msgSend)(app, @selector(appleScriptWindows));
    for (id window in windows) {
        if (![window respondsToSelector:@selector(orderedIndex)] ||
            ((NSInteger (*)(id, SEL))objc_msgSend)(window, @selector(orderedIndex)) != 0 ||
            ![window respondsToSelector:@selector(activeTab)]) continue;
        id tab = ((id (*)(id, SEL))objc_msgSend)(window, @selector(activeTab));
        if (![tab respondsToSelector:@selector(URL)]) return NO;
        id url = ((id (*)(id, SEL))objc_msgSend)(tab, @selector(URL));
        NSString *text = [url isKindOfClass:NSURL.class] ? [url absoluteString] : url;
        if (![text isKindOfClass:NSString.class] || !text.length) return NO;
        [pasteboard clearContents];
        return [pasteboard setString:text forType:NSPasteboardTypeString];
    }
    return NO;
}

@interface DPCopyLinkButton : NSButton
@property (strong) NSTrackingArea *hoverTracking;
@end

@interface DPCopyToast : NSView
@end
@implementation DPCopyToast
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end

@implementation DPCopyLinkButton
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.hoverTracking) [self removeTrackingArea:self.hoverTracking];
    self.hoverTracking = [[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
        owner:self userInfo:nil];
    [self addTrackingArea:self.hoverTracking];
}
- (void)mouseEntered:(NSEvent *)event {
    self.wantsLayer = YES;
    self.layer.cornerRadius = 6;
    self.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:0.08].CGColor;
}
- (void)mouseExited:(NSEvent *)event { self.layer.backgroundColor = nil; }

- (void)copyPageLink:(id)sender {
    if (!DPCopyCurrentLink(NSPasteboard.generalPasteboard)) return;
    self.image = [NSImage imageWithSystemSymbolName:@"checkmark" accessibilityDescription:@"Copied"];
    NSView *root = self.window.contentView.superview;
    [DPGet(self, &DPToastKey) removeFromSuperview];
    NSRect button = [self convertRect:self.bounds toView:root];
    CGFloat y = root.isFlipped ? NSMaxY(button) + 4 : NSMinY(button) - 32;
    DPCopyToast *toast = [[DPCopyToast alloc] initWithFrame:NSMakeRect(NSMidX(button) - 48, y, 96, 28)];
    toast.wantsLayer = YES;
    toast.layer.backgroundColor = NSColor.controlBackgroundColor.CGColor;
    toast.layer.cornerRadius = 7;
    toast.layer.shadowColor = NSColor.blackColor.CGColor;
    toast.layer.shadowOpacity = 0.2;
    toast.layer.shadowRadius = 4;
    toast.layer.shadowOffset = CGSizeMake(0, -1);
    NSTextField *label = [NSTextField labelWithString:@"Link copied"];
    label.alignment = NSTextAlignmentCenter;
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    label.frame = NSMakeRect(0, 6, 96, 16);
    [toast addSubview:label];
    [root addSubview:toast positioned:NSWindowAbove relativeTo:nil];
    DPSet(self, &DPToastKey, toast);
    __weak DPCopyLinkButton *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DPCopyLinkButton *button = weakSelf;
        if (DPGet(button, &DPToastKey) != toast) return;
        [toast removeFromSuperview];
        DPSet(button, &DPToastKey, nil);
        button.image = [NSImage imageWithSystemSymbolName:@"link" accessibilityDescription:@"Copy page link"];
    });
}
@end

static void DPApplyCopyLink(NSView *toolbar) {
    NSView *existing = DPFindView(toolbar, ^BOOL(NSView *view) { return [view.identifier isEqualToString:DPCopyLinkID]; });
    NSView *field = DPFindView(toolbar, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaAddressField); });
    if (field) {
        NSRect original = [DPDiaValue(field, &DPFieldFrameKey, @(field.frame)) rectValue];
        NSRect frame = original;
        if (DPCopyPageLink.on && NSWidth(frame) > 35) frame.origin.x += 35, frame.size.width -= 35;
        DPOverride(field, &DPFieldFrameKey, @(original), @(frame));
        if (!NSEqualRects(field.frame, frame)) field.frame = frame;
    }
    if (!DPCopyPageLink.on) {
        if (existing) [existing removeFromSuperview];
        return;
    }
    NSView *reload = DPFindView(toolbar, ^BOOL(NSView *view) { return DPHasLabel(view, @"Reload this page") || DPHasLabel(view, @"Stop loading this page"); });
    if (!reload || !field || reload.superview != field.superview) return;
    DPCopyLinkButton *button = (DPCopyLinkButton *)existing;
    if (!button) {
        button = [DPCopyLinkButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"link" accessibilityDescription:@"Copy page link"] target:nil action:@selector(copyPageLink:)];
        button.target = button;
        button.bordered = NO;
        button.contentTintColor = NSColor.labelColor;
        button.identifier = DPCopyLinkID;
        button.toolTip = @"Copy page link";
        [button setAccessibilityLabel:@"Copy page link"];
        [reload.superview addSubview:button];
    }
    button.frame = NSMakeRect(NSMaxX(reload.frame) + 5, NSMinY(reload.frame), 30, 30);
}

static void DPToolbar_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPToolbar_layout, self);
    DPApplyCopyLink(self);
}

static void DPInstallCopyPageLink(void) {
    DPHook(DPDiaToolbar, @selector(layout), (IMP)DPToolbar_layout);
}

static void DPApplyCopyPageLink(DPPatch *patch) {
    for (NSView *toolbar in DPFindViews(DPDiaToolbar)) DPApplyCopyLink(toolbar);
}

static NSString *DPVerifyCopyPageLink(DPPatch *patch) {
    for (NSView *toolbar in DPFindViews(DPDiaToolbar)) {
        if (toolbar.hiddenOrHasHiddenAncestor) continue;
        NSView *button = DPFindView(toolbar, ^BOOL(NSView *view) { return [view.identifier isEqualToString:DPCopyLinkID]; });
        if (patch->on && (!button || button.hiddenOrHasHiddenAncestor || NSWidth(button.frame) < 1))
            return @"copy link button is not visible in the navigation bar";
        if (!patch->on && button && !button.hiddenOrHasHiddenAncestor)
            return @"copy link button remains visible when disabled";
        NSView *reload = DPFindView(toolbar, ^BOOL(NSView *view) { return DPHasLabel(view, @"Reload this page") || DPHasLabel(view, @"Stop loading this page"); });
        if (patch->on && reload && (button.superview != reload.superview || NSMinX(button.frame) < NSMaxX(reload.frame)))
            return @"copy link button is not beside the navigation buttons";
        if (patch->on) {
            BOOL tracksHover = NO;
            for (NSTrackingArea *area in button.trackingAreas)
                if ((area.options & NSTrackingMouseEnteredAndExited) && area.owner == button) tracksHover = YES;
            if (!tracksHover) return @"copy link button has no hover feedback";
        }
    }
    if (patch->on) {
        NSPasteboard *test = [NSPasteboard pasteboardWithUniqueName];
        BOOL copied = DPCopyCurrentLink(test);
        NSString *url = [test stringForType:NSPasteboardTypeString];
        [test releaseGlobally];
        if (!copied || !url.length) return @"the current page link cannot be copied";
    }
    return nil;
}

DP_PATCH(DPCopyPageLink) {
    .key = @"copyPageLink",
    .order = 157,
    .title = @"Copy page link",
    .detail = @"Show a toolbar button to copy the current page URL.",
    .symbol = @"link",
    .tint = @"systemBlueColor",
    .section = @"Toolbar",
    .classes = DPClasses(DPDiaAddressField),
    .install = DPInstallCopyPageLink,
    .apply = DPApplyCopyPageLink,
    .verify = DPVerifyCopyPageLink,
};
