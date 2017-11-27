// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <MMTabBarView/MMAttachedTabBarButton.h>
#include <Habanero/CommonPaths.h>
#include "MainWindowFilePanelsStateToolbarDelegate.h"
#include <VFS/Native.h>
#include "MainWindowFilePanelState+TabsSupport.h"
#include "PanelView.h"
#include "PanelController.h"
#include "Views/FilePanelMainSplitView.h"
#include "FilesDraggingSource.h"
#include "PanelHistory.h"
#include "TabContextMenu.h"

template <class _Cont, class _Tp>
inline void erase_from(_Cont &__cont_, const _Tp& __value_)
{
    __cont_.erase(remove(begin(__cont_),
                         end(__cont_),
                         __value_),
                  end(__cont_)
                  );
}

@implementation MainWindowFilePanelState (TabsSupport)

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    return true;
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{    
    if( const auto panel_view = objc_cast<PanelView>(tabViewItem.view) ) {
        [self.window makeFirstResponder:panel_view];
        m_SplitView.leftOverlay = nil;
        m_SplitView.rightOverlay = nil;
    }
}

- (void)tabView:(NSTabView *)aTabView
receivedClickOnSelectedTabViewItem:(NSTabViewItem *)tabViewItem
{
    if( const auto panel_view = objc_cast<PanelView>(tabViewItem.view) ) {
        if( panel_view.active )
            return;
        [self.window makeFirstResponder:panel_view];
        m_SplitView.leftOverlay = nil;
        m_SplitView.rightOverlay = nil;
    }
}

- (BOOL)tabView:(NSTabView *)aTabView
shouldAllowTabViewItem:(NSTabViewItem *)tabViewItem
toLeaveTabBarView:(MMTabBarView *)tabBarView
{
    return aTabView.numberOfTabViewItems > 1;
}

- (NSDragOperation)tabView:(NSTabView *)aTabView
              validateDrop:(id <NSDraggingInfo>)sender
              proposedItem:(NSTabViewItem *)tabViewItem
             proposedIndex:(NSUInteger)proposedIndex
              inTabBarView:(MMTabBarView *)tabBarView
{
    const auto dragged_panel_view = objc_cast<PanelView>(tabViewItem.view);
    if( !dragged_panel_view )
        return NSDragOperationNone;
    
    if( dragged_panel_view.window != self.window )
        return NSDragOperationNone;
    
    return NSDragOperationGeneric;
}

- (void)tabView:(NSTabView*)aTabView
didDropTabViewItem:(NSTabViewItem *)tabViewItem
   inTabBarView:(MMTabBarView *)tabBarView
{
    const auto dropped_panel_view = objc_cast<PanelView>(tabViewItem.view);
    if( !dropped_panel_view )
        return;
    
    const auto dropped_panel_controller =  objc_cast<PanelController>(dropped_panel_view.delegate);
    if( !dropped_panel_controller )
        return;
    
    const auto index = [tabBarView.tabView indexOfTabViewItem:tabViewItem];
    if( index == NSNotFound )
        return;
    
    if( [self isRightController:dropped_panel_controller] ) {
        const auto it = find(begin(m_RightPanelControllers),
                             end(m_RightPanelControllers),
                             dropped_panel_controller);
        if( it == end(m_RightPanelControllers) )
            return;
        m_RightPanelControllers.erase(it);
    }

    if( [self isLeftController:dropped_panel_controller] ) {
        const auto it = find(begin(m_LeftPanelControllers),
                             end(m_LeftPanelControllers),
                             dropped_panel_controller);
        if( it == end(m_LeftPanelControllers) )
            return;
        m_LeftPanelControllers.erase(it);
    }
    
    if( [tabBarView isDescendantOf:m_SplitView.leftTabbedHolder] )
        m_LeftPanelControllers.insert(next(begin(m_LeftPanelControllers), index),
                                      dropped_panel_controller);
    else if( [tabBarView isDescendantOf:m_SplitView.rightTabbedHolder] )
        m_RightPanelControllers.insert(next(begin(m_RightPanelControllers), index),
                                       dropped_panel_controller);

    // empty or unselected tab view?
}

static string TabNameForController( PanelController* _controller )
{
    path p = _controller.currentDirectoryPath;
    string name = p == "/" ? p.native() : p.parent_path().filename().native();
    if( name == "/" && _controller.isUniform && _controller.vfs->Parent() ) {
        // source file name for vfs like archives and xattr
        name = path(_controller.vfs->JunctionPath()).filename().native();
    }
    return name;
}

- (NSTabViewItem*) tabViewItemForPanelController:(PanelController*)_controller
{
    NSArray<NSTabViewItem*> *tabs;
    if([self isLeftController:_controller])
        tabs = m_SplitView.leftTabbedHolder.tabView.tabViewItems;
    else if([self isRightController:_controller])
        tabs = m_SplitView.rightTabbedHolder.tabView.tabViewItems;
    
    if( !tabs )
        return nil;
    
    for(NSTabViewItem *it in tabs)
        if( it.view == _controller.view )
            return it;
    
    return nil;
}

- (void) updateTabNameForController:(PanelController*)_controller
{
    if( const auto tab_item = [self tabViewItemForPanelController:_controller] ) {
        const auto name = TabNameForController(_controller);
        tab_item.label = [NSString stringWithUTF8StdString:name];
    }
}

- (void)addNewTabToTabView:(NSTabView *)aTabView
{
    [self spawnNewTabInTabView:aTabView autoDirectoryLoading:true activateNewPanel:true];
}

- (PanelController*)spawnNewTabInTabView:(NSTabView *)aTabView
                    autoDirectoryLoading:(bool)_load
                        activateNewPanel:(bool)_activate
{
    PanelController *pc = [PanelController new];
    pc.state = self;
    PanelController *source = nil;
    if( aTabView == m_SplitView.leftTabbedHolder.tabView ) {
        source = self.leftPanelController;
        m_LeftPanelControllers.emplace_back(pc);
        [m_SplitView.leftTabbedHolder addPanel:pc.view];
    }
    else if( aTabView == m_SplitView.rightTabbedHolder.tabView ) {
        source = self.rightPanelController;
        m_RightPanelControllers.emplace_back(pc);
        [m_SplitView.rightTabbedHolder addPanel:pc.view];
    }
    else
        assert(0); // something is really broken
    
    [pc copyOptionsFromController:source];
    if( _load ) {
        if( source.isUniform ) {
            [pc GoToDir:source.currentDirectoryPath
                    vfs:source.vfs
           select_entry:""
                  async:false];
        }
        else if( !source.history.Empty() ) {
            auto h = source.history.All();
            [pc GoToVFSPromise:h.back().get().vfs onPath:h.back().get().path];
        }
        else
            [pc GoToDir:CommonPaths::Home()
                    vfs:VFSNativeHost::SharedHost()
           select_entry:""
                  async:false];
    }
    
    if( _activate )
        [self ActivatePanelByController:pc];
    
    return pc;
}

- (void)tabView:(NSTabView *)aTabView
didMoveTabViewItem:(NSTabViewItem *)tabViewItem
        toIndex:(NSUInteger)index
{
    PanelController *pc =  (PanelController*)(((PanelView*)tabViewItem.view).delegate);
    if( [self isLeftController:pc] ) {
        auto it = find(begin(m_LeftPanelControllers), end(m_LeftPanelControllers), pc);
        if(it == end(m_LeftPanelControllers))
            return;
        
        m_LeftPanelControllers.erase(it);
        m_LeftPanelControllers.insert(begin(m_LeftPanelControllers)+index, pc);
        
    }
    else if( [self isRightController:pc] ) {
        auto it = find(begin(m_RightPanelControllers), end(m_RightPanelControllers), pc);
        if(it == end(m_RightPanelControllers))
            return;
        
        m_RightPanelControllers.erase(it);
        m_RightPanelControllers.insert(begin(m_RightPanelControllers)+index, pc);
    }
}

- (BOOL)tabView:(NSTabView *)aTabView
shouldDragTabViewItem:(NSTabViewItem *)tabViewItem
   inTabBarView:(MMTabBarView *)tabBarView
{
    return aTabView.numberOfTabViewItems > 1;
}

- (NSArray *)allowedDraggedTypesForTabView:(NSTabView *)aTabView
{
    return @[FilesDraggingSource.privateDragUTI];
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
    [self updateTabBarsVisibility];
}

- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
    // NB! at this moment a tab was already removed from NSTabView objects
    if( auto pv = objc_cast<PanelView>(tabViewItem.view) )
        if( auto pc = objc_cast<PanelController>(pv.delegate) ) {
            erase_from(m_LeftPanelControllers, pc);
            erase_from(m_RightPanelControllers, pc);
        }
}

- (void) closeTabForController:(PanelController*)_controller
{
    NSTabViewItem *it;
    MMTabBarView *bar;

    if( [self isLeftController:_controller] ) {
        it = [m_SplitView.leftTabbedHolder tabViewItemForController:_controller];
        bar = m_SplitView.leftTabbedHolder.tabBar;
    }
    else if ( [self isRightController:_controller] ) {
        it = [m_SplitView.rightTabbedHolder tabViewItemForController:_controller];
        bar = m_SplitView.rightTabbedHolder.tabBar;
    }
 
    if( it && bar )
        if(const auto button = [bar attachedButtonForTabViewItem:it] )
            dispatch_to_main_queue([=]{
                if( const auto close_button = button.closeButton )
                    [close_button sendAction:close_button.action
                                          to:close_button.target];
            });
}

- (void) closeOtherTabsForController:(PanelController*)_controller
{
    MMTabBarView *bar;
    if( [self isLeftController:_controller] )
        bar = m_SplitView.leftTabbedHolder.tabBar;
    else if ( [self isRightController:_controller] )
        bar = m_SplitView.rightTabbedHolder.tabBar;
    
    if( !bar )
        return;
    
    vector<NSTabViewItem *> items;
    for( NSTabViewItem *it in bar.tabView.tabViewItems )
        if( it.view != _controller.view )
            items.emplace_back(it);
    
    if( items.empty() )
        return;
    
    dispatch_to_background([=]{
        for( auto it: items )
            dispatch_to_main_queue([=]{
                if( const auto button = [bar attachedButtonForTabViewItem:it] )
                    if( const auto close_button = button.closeButton )
                        [close_button sendAction:close_button.action
                                              to:close_button.target];
            });
    });
}

- (unsigned) currentSideTabsCount
{
    if( !self.isPanelActive )
        return 0;
    
    PanelController *cur = self.activePanelController;
    int tabs = 1;
    if( [self isLeftController:cur] )
        tabs = m_SplitView.leftTabbedHolder.tabsCount;
    else if( [self isRightController:cur] )
        tabs = m_SplitView.rightTabbedHolder.tabsCount;
    return tabs;
}

- (MMTabBarView*) activeTabBarView
{
    PanelController *cur = self.activePanelController;
    if(!cur)
        return nil;
    
    if([self isLeftController:cur])
        return m_SplitView.leftTabbedHolder.tabBar;
    else if([self isRightController:cur])
        return m_SplitView.rightTabbedHolder.tabBar;
    
    return nil;
}

- (FilePanelsTabbedHolder*) activeFilePanelsTabbedHolder
{
    PanelController *cur = self.activePanelController;
    if(!cur)
        return nil;
    
    if([self isLeftController:cur])
        return m_SplitView.leftTabbedHolder;
    else if([self isRightController:cur])
        return m_SplitView.rightTabbedHolder;
    
    return nil;
}

- (void) selectPreviousFilePanelTab
{
    if( auto th = self.activeFilePanelsTabbedHolder )
        [th selectPreviousFilePanelTab];
}

- (void) selectNextFilePanelTab
{
    if( auto th = self.activeFilePanelsTabbedHolder )
        [th selectNextFilePanelTab];
}

- (void) updateTabBarsVisibility
{
    unsigned lc = m_SplitView.leftTabbedHolder.tabsCount,
             rc = m_SplitView.rightTabbedHolder.tabsCount;
    bool should_be_shown = m_ShowTabs ? true : (lc > 1 || rc > 1);
    m_SplitView.leftTabbedHolder.tabBarShown = should_be_shown;
    m_SplitView.rightTabbedHolder.tabBarShown = should_be_shown;
}

- (void) updateTabBarButtons
{
    const auto handler = ^(MMAttachedTabBarButton *aButton, NSUInteger idx, BOOL *stop) {
        [aButton setNeedsDisplay];
    };
    [m_SplitView.leftTabbedHolder.tabBar  enumerateAttachedButtonsUsingBlock:handler];
    [m_SplitView.rightTabbedHolder.tabBar  enumerateAttachedButtonsUsingBlock:handler];
}

- (FilePanelsTabbedHolder *) leftTabbedHolder
{
    return m_SplitView.leftTabbedHolder;
}

- (FilePanelsTabbedHolder *) rightTabbedHolder
{
    return m_SplitView.rightTabbedHolder;
}

static NSImage *ResizeImage( NSImage* _img, NSSize _new_size)
{
    if( !_img.valid )
        return nil;
    
    NSImage *small_img = [[NSImage alloc] initWithSize:_new_size];
    [small_img lockFocus];
    _img.size = _new_size;
    NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationHigh;
    [_img drawAtPoint:NSZeroPoint
             fromRect:CGRectMake(0, 0, _new_size.width, _new_size.height)
            operation:NSCompositeCopy
             fraction:1.0];
    [small_img unlockFocus];
    
    return small_img;
}

- (NSImage *)tabView:(NSTabView *)aTabView
 imageForTabViewItem:(NSTabViewItem *)tabViewItem
              offset:(NSSize *)offset
           styleMask:(NSUInteger *)styleMask
{
    const auto panel_view = objc_cast<PanelView>(tabViewItem.view);
    if( !panel_view )
        return nil;
    
    const auto bitmap = [panel_view bitmapImageRepForCachingDisplayInRect:panel_view.bounds];
    if( !bitmap )
        return nil;
    
    [panel_view cacheDisplayInRect:panel_view.bounds toBitmapImageRep:bitmap];
    
    auto image = [[NSImage alloc] init];
    [image addRepresentation:bitmap];
    
    const auto max_dim = 320.;
    const auto scale = max( bitmap.size.width, bitmap.size.height ) / max_dim;
    if( scale > 1 )
        image = ResizeImage(image, NSMakeSize(bitmap.size.width / scale,
                                              bitmap.size.height / scale));
    
    return image;
}

- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem
{
    if( auto pv = objc_cast<PanelView>(tabViewItem.view) )
        if( auto pc = objc_cast<PanelController>(pv.delegate) )
            return [[NCPanelTabContextMenu alloc] initWithPanel:pc ofState:self];
    
    return nil;
}

@end

