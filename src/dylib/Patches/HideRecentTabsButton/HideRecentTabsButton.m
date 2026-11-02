#import "StdPatch/Hide.h"

static BOOL DPIsRecentTabsButton(NSView *view) { return DPHasLabel(view, @"Recent tabs"); }

extern DPPatch DPHideRecentTabsButton;
static char DPDownloadFrameKey, DPProfileFrameKey;

static void DPHeaderSetFrame(NSView *view, const void *key, NSRect frame, BOOL override) {
    if (!view) return;
    NSRect original = [DPDiaValue(view, key, @(view.frame)) rectValue];
    if (override) {
        DPOverride(view, key, @(original), @(frame));
        if (!NSEqualRects(view.frame, frame)) view.frame = frame;
    } else if (DPGet(view, key)) {
        DPSet(view, key, nil);
        if (!NSEqualRects(view.frame, original)) view.frame = original;
    }
}

static void DPCompactSidebarHeader(NSView *header) {
    NSView *recent = DPFindView(header, ^BOOL(NSView *v) { return DPHasLabel(v, @"Recent tabs"); });
    NSView *downloads = DPFindView(header, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaDownloadsButton); });
    if (!recent || !downloads || recent.superview != downloads.superview) return;
    NSView *profile = DPFindView(recent.superview, ^BOOL(NSView *v) { return [NSStringFromClass(v.class) containsString:@"ProfileIndicatorWrapperView"]; });
    NSRect downloadFrame = [DPDiaValue(downloads, &DPDownloadFrameKey, @(downloads.frame)) rectValue];
    NSRect profileFrame = profile ? [DPDiaValue(profile, &DPProfileFrameKey, @(profile.frame)) rectValue] : NSZeroRect;
    BOOL compact = DPHideRecentTabsButton.on && recent.hidden && !downloads.hiddenOrHasHiddenAncestor;
    CGFloat gap = NSMaxX(recent.frame) - NSMaxX(downloadFrame);
    compact &= NSMinX(recent.frame) > NSMinX(downloadFrame) && gap > 1 && gap <= NSWidth(recent.frame) + 4;
    if (compact) {
        downloadFrame.origin.x += gap;
        if (profile && NSMaxX(profileFrame) <= NSMinX(downloadFrame)) profileFrame.size.width += gap;
    }
    DPHeaderSetFrame(downloads, &DPDownloadFrameKey, downloadFrame, compact);
    DPHeaderSetFrame(profile, &DPProfileFrameKey, profileFrame, compact);
}

static void DPHeaderStack_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPHeaderStack_layout, self);
    // AIDEV-NOTE: Dia's stack reserves a slot after the recent-tabs button is hidden.
    if (DPIsKind(self.superview, DPDiaSidebarHeader)) DPCompactSidebarHeader(self.superview);
}

static void DPRefreshRecentTabsSpacing(void) {
    for (NSView *header in DPFindViews(DPDiaSidebarHeader)) {
        NSView *recent = DPFindView(header, ^BOOL(NSView *v) { return DPHasLabel(v, @"Recent tabs"); });
        [recent.superview layoutSubtreeIfNeeded];
        DPCompactSidebarHeader(header);
    }
}

static void DPApplyRecentTabs(DPPatch *patch) {
    DPApplyHides(patch);
    DPRefreshRecentTabsSpacing();
    dispatch_async(dispatch_get_main_queue(), ^{ DPRefreshRecentTabsSpacing(); });
}

static void DPInstallRecentTabsSpacing(void) {
    DPHookClass(NSStackView.class, @selector(layout), (IMP)DPHeaderStack_layout);
}

static NSString *DPVerifyRecentTabsSpacing(DPPatch *patch) {
    NSString *problem = DPVerifyHides(patch);
    if (problem || !patch->on) return problem;
    for (NSView *header in DPFindViews(DPDiaSidebarHeader)) {
        NSView *recent = DPFindView(header, ^BOOL(NSView *view) { return DPHasLabel(view, @"Recent tabs"); });
        NSView *downloads = DPFindView(header, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaDownloadsButton); });
        if (!recent || !downloads || !recent.hidden || downloads.hiddenOrHasHiddenAncestor || recent.superview != downloads.superview) continue;
        if (NSMinX(recent.frame) > NSMinX(downloads.frame) && fabs(NSMaxX(recent.frame) - NSMaxX(downloads.frame)) > 1)
            return @"download button leaves a gap for hidden recent tabs";
    }
    return nil;
}

DP_PATCH(DPHideRecentTabsButton) {
    .key = @"hideRecentTabsButton",
    .order = 80,
    .title = @"Hide recent tabs button",
    .detail = @"Hide the recent tabs button in the tab bar or sidebar.",
    .symbol = @"clock.arrow.circlepath",
    .tint = @"systemPinkColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaSidebarFooter, DPDiaTabStripController),
    .install = DPInstallRecentTabsSpacing,
    .apply = DPApplyRecentTabs,
    .hides = DPIsRecentTabsButton,
    .verify = DPVerifyRecentTabsSpacing,
};
