//
//  AppDelegate.h
//  iOSPeripheralBTConnectivity
//
//  Created by Christos Christodoulou on 10/10/2017.
//  Copyright © 2017 Christos Christodoulou. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

