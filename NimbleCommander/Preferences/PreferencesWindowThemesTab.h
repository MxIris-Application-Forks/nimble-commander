//
//  PreferencesWindowThemesTab.h
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 1/17/17.
//  Copyright © 2017 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>

@interface PreferencesWindowThemesTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                          NSOutlineViewDelegate,
                                                          NSOutlineViewDataSource,
                                                          NSTextFieldDelegate>

@end
