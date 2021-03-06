//
//  AppDelegate.m
//  Piggybackv2
//
//  Created by Michael Gao on 6/21/12.
//  Copyright (c) 2012 Calimucho. All rights reserved.
//

#import "AppDelegate.h"
#import "PiggybackTabBarController.h"
#include "appkey.c"
#import "ListenTableViewController.h"
#import "ExploreTableViewController.h"
#import "LoginViewController.h"
#import <RestKit/RestKit.h>
#import <RestKit/CoreData.h>
#import "PBUser.h"
#import "SetAmbassadorsViewController.h"
#import "HomeViewController.h"
#import "PBMusicItem.h"
#import "PBMusicActivity.h"
#import "PBPlacesItem.h"
#import "PBPlacesActivity.h"
#import "PBVideosItem.h"
#import "PBVideosActivity.h"
#import "PBMusicNews.h"
#import "PBPlacesFeedback.h"
#import "PBVideosFeedback.h"
#import "PBMusicFeedback.h"
#import <RestKit/RKRequestSerialization.h>

@interface AppDelegate ()

@property (nonatomic, strong) UILabel *newsNotificationLabel;

@end

@implementation AppDelegate

//NSString* RK_BASE_URL = @"http://piggybackv2.herokuapp.com";
NSString *RK_BASE_URL = @"http://localhost:5000";
NSString* const FB_APP_ID = @"316977565057222";
NSString* const FSQ_CLIENT_ID = @"LBZXOLI3RUL2GDOHGPO5HH4Z101JUATS2ECUZ0QACUJVWUFB";
NSString* const FSQ_CALLBACK_URL = @"piggyback://foursquare";

@synthesize window = _window;
@synthesize foursquare = _foursquare;
@synthesize facebook = _facebook;
@synthesize foursquareDelegate = _foursquareDelegate;
@synthesize newsNotificationLabel = _newsNotificationLabel;
@synthesize accountLinkNavigationController = _accountLinkViewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // set up storyboard and root view controller
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    PiggybackTabBarController *rootViewController = (PiggybackTabBarController *)self.window.rootViewController;
    
    // set up restkit object manager (for core data)
    RKObjectManager* objectManager = [RKObjectManager objectManagerWithBaseURL:[NSURL URLWithString:RK_BASE_URL]];
    objectManager.acceptMIMEType = RKMIMETypeJSON;
    objectManager.serializationMIMEType = RKMIMETypeJSON;
    objectManager.client.requestQueue.showsNetworkActivityIndicatorWhenBusy = YES;
    objectManager.objectStore = [RKManagedObjectStore objectStoreWithStoreFilename:@"Piggybackv2.sqlite"];
    [RKObjectManager setSharedManager:objectManager];
    
    // set up restkit client (for sending requests w/o core data integration)
    RKClient *client = [RKClient clientWithBaseURLString:RK_BASE_URL];
    [client setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [RKClient setSharedClient:client];

    // set up remote push notifications
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert];
    
    [self setupRestkitRouting];
    [self setupRestkitMapping];

    // setting up foursquare
    self.foursquare = [[BZFoursquare alloc] initWithClientID:FSQ_CLIENT_ID callbackURL:FSQ_CALLBACK_URL];
    self.foursquare.sessionDelegate = self;
    self.foursquareDelegate = [[FoursquareDelegate alloc] init];
    [(PiggybackTabBarController*)self.window.rootViewController setFoursquareDelegate:self.foursquareDelegate];
    
    // setting up spotify
    [SPSession initializeSharedSessionWithApplicationKey:[NSData dataWithBytes:&g_appkey length:g_appkey_size] 
											   userAgent:@"com.getpiggyback.Piggybackv2"
										   loadingPolicy:SPAsyncLoadingManual
												   error:nil];
    [[SPSession sharedSession] setDelegate:self];
    
    // if re-logging in to spotify after being disconected
    if ([SPSession sharedSession].connectionState == 3) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [[SPSession sharedSession] attemptLoginWithUserName:[defaults objectForKey:@"spotifyUsername"] existingCredential:[defaults objectForKey:@"spotifyCredentials"] rememberCredentials:YES];
    }


    // setting up facebook
    self.facebook = [[Facebook alloc] initWithAppId:FB_APP_ID andDelegate:self];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"FBAccessTokenKey"] 
        && [defaults objectForKey:@"FBExpirationDateKey"]) {
        self.facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
        self.facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
    }
    
    [self.window makeKeyAndVisible];
    if (![self.facebook isSessionValid]) {
        LoginViewController *loginViewController = [storyboard instantiateViewControllerWithIdentifier:@"loginViewController"];
        [rootViewController presentViewController:loginViewController animated:NO completion:nil];
    } else {
        // do nothing (default behavior is to show tab bar controller)
    }
    
    // add news notification label
    self.newsNotificationLabel = [[UILabel alloc] initWithFrame:CGRectMake(140, 420, 20, 20)];
    self.newsNotificationLabel.text = @"+1";
    self.newsNotificationLabel.alpha = 0.0;
    [self.window addSubview:self.newsNotificationLabel];
    
    return YES;
}

#pragma mark -
#pragma mark - setting up restkit mapping and routing

- (void)setupRestkitRouting {
    RKObjectRouter *router = [RKObjectManager sharedManager].router;
    [router routeClass:[PBUser class] toResourcePath:@"/addUser" forMethod:RKRequestMethodPOST];
    [router routeClass:[PBUser class] toResourcePath:@"/updateUser" forMethod:RKRequestMethodPUT];
    [router routeClass:[PBMusicItem class] toResourcePath:@"/addMusicItem" forMethod:RKRequestMethodPOST];
    [router routeClass:[PBMusicActivity class] toResourcePath:@"/addMusicActivity" forMethod:RKRequestMethodPOST];
    [router routeClass:[PBMusicFeedback class] toResourcePath:@"/addMusicFeedback" forMethod:RKRequestMethodPOST];
    [router routeClass:[PBPlacesItem class] toResourcePath:@"/addPlacesItem" forMethod:RKRequestMethodPOST];
    [router routeClass:[PBPlacesItem class] toResourcePath:@"/updatePlacesItem" forMethod:RKRequestMethodPUT];
    [router routeClass:[PBPlacesActivity class] toResourcePath:@"/addPlacesActivity" forMethod:RKRequestMethodPOST];
    [router routeClass:[PBPlacesFeedback class] toResourcePath:@"/addPlacesFeedback" forMethod:RKRequestMethodPOST];
    [router routeClass:[PBVideosItem class] toResourcePath:@"/addVideosItem" forMethod:RKRequestMethodPOST];
    [router routeClass:[PBVideosActivity class] toResourcePath:@"/addVideosActivity" forMethod:RKRequestMethodPOST];
    [router routeClass:[PBVideosFeedback class] toResourcePath:@"/addVideosFeedback" forMethod:RKRequestMethodPOST];
}

- (void)setupRestkitMapping {

    // mapping declarations
    RKObjectManager *objectManager = [RKObjectManager sharedManager];
    RKManagedObjectMapping* userMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBUser" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping* musicItemMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBMusicItem" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping *musicActivityMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBMusicActivity" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping *musicNewsMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBMusicNews" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping *musicFeedbackMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBMusicFeedback" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping* placesItemMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBPlacesItem" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping* placesActivityMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBPlacesActivity" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping *placesNewsMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBPlacesNews" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping *placesFeedbackMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBPlacesFeedback" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping* videosItemMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBVideosItem" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping* videosActivityMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBVideosActivity" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping *videosNewsMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBVideosNews" inManagedObjectStore:objectManager.objectStore];
    RKManagedObjectMapping *videosFeedbackMapping = [RKManagedObjectMapping mappingForEntityWithName:@"PBVideosFeedback" inManagedObjectStore:objectManager.objectStore];
    
    // user mapping
    userMapping.primaryKeyAttribute = @"uid";
    [userMapping mapAttributes:@"uid",@"fbId",@"firstName",@"lastName",@"email",@"spotifyUsername",@"youtubeUsername",@"foursquareId",@"isPiggybackUser",@"dateAdded",@"dateBecamePbUser",nil];
    [userMapping mapRelationship:@"musicAmbassadors" withMapping:userMapping];
    [userMapping mapRelationship:@"placesAmbassadors" withMapping:userMapping];
    [userMapping mapRelationship:@"videosAmbassadors" withMapping:userMapping];
    [objectManager.mappingProvider setMapping:userMapping forKeyPath:@"PBUser"];
    
    // musicItem mapping
    musicItemMapping.primaryKeyAttribute = @"musicItemId";
    [musicItemMapping mapAttributes:@"musicItemId",@"artistName",@"songTitle",@"albumTitle",@"albumYear",@"spotifyUrl",@"songDuration",nil];
    [objectManager.mappingProvider setMapping:musicItemMapping forKeyPath:@"PBMusicItem"];
    
    // musicActivity mapping
    musicActivityMapping.primaryKeyAttribute = @"musicActivityId";
    [musicActivityMapping mapAttributes:@"musicActivityId",@"uid",@"musicItemId",@"musicActivityType",@"dateAdded",nil];
    [musicActivityMapping mapRelationship:@"musicItem" withMapping:musicItemMapping];
    [musicActivityMapping mapRelationship:@"user" withMapping:userMapping];
    [musicActivityMapping mapRelationship:@"news" withMapping:musicNewsMapping];
    [musicActivityMapping connectRelationship:@"musicItem" withObjectForPrimaryKeyAttribute:@"musicItemId"];
    [musicActivityMapping connectRelationship:@"user" withObjectForPrimaryKeyAttribute:@"uid"];
    [objectManager.mappingProvider setMapping:musicActivityMapping forKeyPath:@"PBMusicActivity"];
    
    // musicNews mapping
    musicNewsMapping.primaryKeyAttribute = @"musicNewsId";
    [musicNewsMapping mapAttributes:@"musicNewsId", @"newsActionType", @"dateAdded", @"followerUid", @"musicActivityId", nil];
    [musicNewsMapping mapRelationship:@"follower" withMapping:userMapping];
    [musicNewsMapping mapRelationship:@"musicActivity" withMapping:musicActivityMapping];
    [musicNewsMapping connectRelationship:@"follower" withObjectForPrimaryKeyAttribute:@"followerUid"];
    [musicNewsMapping connectRelationship:@"musicActivity" withObjectForPrimaryKeyAttribute:@"musicActivityId"];
    [objectManager.mappingProvider setMapping:musicNewsMapping forKeyPath:@"PBMusicNews"];
    
    // musicFeedback mapping
    musicFeedbackMapping.primaryKeyAttribute = @"musicFeedbackId";
    [musicFeedbackMapping mapAttributes:@"musicFeedbackId", @"dateAdded", @"musicActivityId", @"followerUid", @"musicFeedbackType", nil];
    [musicFeedbackMapping mapRelationship:@"musicActivity" withMapping:musicActivityMapping];
    [musicFeedbackMapping connectRelationship:@"musicActivity" withObjectForPrimaryKeyAttribute:@"musicActivityId"];
    [objectManager.mappingProvider setMapping:musicFeedbackMapping forKeyPath:@"PBMusicFeedback"];
    
    // placesItem mapping
    placesItemMapping.primaryKeyAttribute = @"placesItemId";
    [placesItemMapping mapAttributes:@"placesItemId",@"addr",@"addrCity",@"addrCountry",@"addrState",@"addrCountry",@"addrZip",@"foursquareReferenceId",@"lat",@"lng",@"name",@"phone",@"photoURL",nil];
    [objectManager.mappingProvider setMapping:placesItemMapping forKeyPath:@"PBPlacesItem"];
    
    // placesActivity mapping
    placesActivityMapping.primaryKeyAttribute = @"placesActivityId";
    [placesActivityMapping mapAttributes:@"placesActivityId",@"uid",@"placesItemId",@"placesActivityType",@"dateAdded",nil];
    [placesActivityMapping mapRelationship:@"placesItem" withMapping:placesItemMapping];
    [placesActivityMapping mapRelationship:@"user" withMapping:userMapping];
    [placesActivityMapping mapRelationship:@"news" withMapping:placesNewsMapping];
    [placesActivityMapping connectRelationship:@"placesItem" withObjectForPrimaryKeyAttribute:@"placesItemId"];
    [placesActivityMapping connectRelationship:@"user" withObjectForPrimaryKeyAttribute:@"uid"];
    [objectManager.mappingProvider setMapping:placesActivityMapping forKeyPath:@"PBPlacesActivity"];
    
    // placesNews mapping
    placesNewsMapping.primaryKeyAttribute = @"placesNewsId";
    [placesNewsMapping mapAttributes:@"placesNewsId", @"newsActionType", @"dateAdded", @"followerUid", @"placesActivityId", nil];
    [placesNewsMapping mapRelationship:@"follower" withMapping:userMapping];
    [placesNewsMapping mapRelationship:@"placesActivity" withMapping:placesActivityMapping];
    [placesNewsMapping connectRelationship:@"follower" withObjectForPrimaryKeyAttribute:@"followerUid"];
    [placesNewsMapping connectRelationship:@"placesActivity" withObjectForPrimaryKeyAttribute:@"placesActivityId"];
    [objectManager.mappingProvider setMapping:placesNewsMapping forKeyPath:@"PBPlacesNews"];
    
    // placesFeedback mapping
    placesFeedbackMapping.primaryKeyAttribute = @"placesFeedbackId";
    [placesFeedbackMapping mapAttributes:@"placesFeedbackId", @"dateAdded", @"placesActivityId", @"followerUid", @"placesFeedbackType", nil];
    [placesFeedbackMapping mapRelationship:@"placesActivity" withMapping:placesActivityMapping];
    [placesFeedbackMapping connectRelationship:@"placesActivity" withObjectForPrimaryKeyAttribute:@"placesActivityId"];
    [objectManager.mappingProvider setMapping:placesFeedbackMapping forKeyPath:@"PBPlacesFeedback"];
    
    // videosItem mapping
    videosItemMapping.primaryKeyAttribute = @"videosItemId";
    [videosItemMapping mapAttributes:@"videosItemId",@"name",@"videoURL",@"thumbnailURL",nil];
    [objectManager.mappingProvider setMapping:videosItemMapping forKeyPath:@"PBVideosItem"];
    
    // videosActivity mapping
    videosActivityMapping.primaryKeyAttribute = @"videosActivityId";
    [videosActivityMapping mapAttributes:@"videosActivityId",@"uid",@"videosItemId",@"videosActivityType",@"dateAdded",nil];
    [videosActivityMapping mapRelationship:@"videosItem" withMapping:videosItemMapping];
    [videosActivityMapping mapRelationship:@"user" withMapping:userMapping];
    [videosActivityMapping mapRelationship:@"news" withMapping:videosNewsMapping];
    [videosActivityMapping connectRelationship:@"videosItem" withObjectForPrimaryKeyAttribute:@"videosItemId"];
    [videosActivityMapping connectRelationship:@"user" withObjectForPrimaryKeyAttribute:@"uid"];
    [objectManager.mappingProvider setMapping:videosActivityMapping forKeyPath:@"PBVideosActivity"];
    
    // videosNews mapping
    videosNewsMapping.primaryKeyAttribute = @"videosNewsId";
    [videosNewsMapping mapAttributes:@"videosNewsId", @"newsActionType", @"dateAdded", @"followerUid", @"videosActivityId", nil];
    [videosNewsMapping mapRelationship:@"follower" withMapping:userMapping];
    [videosNewsMapping mapRelationship:@"videosActivity" withMapping:videosActivityMapping];
    [videosNewsMapping connectRelationship:@"follower" withObjectForPrimaryKeyAttribute:@"followerUid"];
    [videosNewsMapping connectRelationship:@"videosActivity" withObjectForPrimaryKeyAttribute:@"videosActivityId"];
    [objectManager.mappingProvider setMapping:videosNewsMapping forKeyPath:@"PBVideosNews"];
    
    // videosFeedback mapping
    videosFeedbackMapping.primaryKeyAttribute = @"videosFeedbackId";
    [videosFeedbackMapping mapAttributes:@"videosFeedbackId", @"dateAdded", @"videosActivityId", @"followerUid", @"videosFeedbackType", nil];
    [videosFeedbackMapping mapRelationship:@"videosActivity" withMapping:videosActivityMapping];
    [videosFeedbackMapping connectRelationship:@"videosActivity" withObjectForPrimaryKeyAttribute:@"videosActivityId"];
    [objectManager.mappingProvider setMapping:videosFeedbackMapping forKeyPath:@"PBVideosFeedback"];
    
    // serialization declarations
    RKObjectMapping *userSerializationMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    RKObjectMapping *musicItemSerializationMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    RKObjectMapping *musicActivitySerializationMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    RKObjectMapping *musicFeedbackSerializationMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    RKObjectMapping *placesItemSerializationMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    RKObjectMapping *placesActivitySerializationMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    RKObjectMapping *placesFeedbackSerializationMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    RKObjectMapping *videosItemSerializationMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    RKObjectMapping *videosActivitySerializationMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];
    RKObjectMapping *videosFeedbackSerializationMapping = [RKObjectMapping mappingForClass:[NSMutableDictionary class]];

    // user serialization
    [userSerializationMapping mapAttributes:@"uid",@"fbId",@"firstName",@"lastName",@"email",@"spotifyUsername",@"youtubeUsername",@"foursquareId",@"isPiggybackUser",@"dateAdded",@"dateBecamePbUser",nil];
    [userSerializationMapping mapRelationship:@"musicAmbassadors" withMapping:userSerializationMapping];
    [userSerializationMapping mapRelationship:@"placesAmbassadors" withMapping:userSerializationMapping];
    [objectManager.mappingProvider setSerializationMapping:userSerializationMapping forClass:[PBUser class]];
    
    // musicItem serialization
    [musicItemSerializationMapping mapAttributes:@"musicItemId",@"artistName",@"songTitle",@"albumTitle",@"albumYear",@"spotifyUrl",@"songDuration",nil];
    [objectManager.mappingProvider setSerializationMapping:musicItemSerializationMapping forClass:[PBMusicItem class]];
    
    // musicActivity serialization
    [musicActivitySerializationMapping mapAttributes:@"musicActivityId",@"uid",@"musicItemId",@"musicActivityType",@"dateAdded",nil];
    [musicActivitySerializationMapping mapRelationship:@"musicItem" withMapping:musicItemSerializationMapping];
    [objectManager.mappingProvider setSerializationMapping:musicActivitySerializationMapping forClass:[PBMusicActivity class]];
    
    // musicFeedback serialization
    [musicFeedbackSerializationMapping mapAttributes:@"musicFeedbackId", @"musicActivityId", @"followerUid", @"musicFeedbackType", nil];
    [musicFeedbackSerializationMapping mapRelationship:@"musicActivity" withMapping:musicActivitySerializationMapping];
    [musicFeedbackSerializationMapping mapRelationship:@"follower" withMapping:userSerializationMapping];
    [objectManager.mappingProvider setSerializationMapping:musicFeedbackSerializationMapping forClass:[PBMusicFeedback class]];
    
    // placesItem serialization
    [placesItemSerializationMapping mapAttributes:@"placesItemId",@"addr",@"addrCity",@"addrCountry",@"addrState",@"addrCountry",@"addrZip",@"foursquareReferenceId",@"lat",@"lng",@"name",@"phone",@"photoURL",nil];
    [objectManager.mappingProvider setSerializationMapping:placesItemSerializationMapping forClass:[PBPlacesItem class]];
    
    // placesActivity serialization
    [placesActivitySerializationMapping mapAttributes:@"placesActivityId",@"uid",@"placesItemId",@"placesActivityType",@"dateAdded",nil];
    [placesActivitySerializationMapping mapRelationship:@"placesItem" withMapping:placesItemSerializationMapping];
    [objectManager.mappingProvider setSerializationMapping:placesActivitySerializationMapping forClass:[PBPlacesActivity class]];
    
    // placesFeedback serialization
    [placesFeedbackSerializationMapping mapAttributes:@"placesFeedbackId", @"placesActivityId", @"followerUid", @"placesFeedbackType", nil];
    [placesFeedbackSerializationMapping mapRelationship:@"placesActivity" withMapping:placesActivitySerializationMapping];
    [placesFeedbackSerializationMapping mapRelationship:@"follower" withMapping:userSerializationMapping];
    [objectManager.mappingProvider setSerializationMapping:placesFeedbackSerializationMapping forClass:[PBPlacesFeedback class]];
    
    // videosItem serialization
    [videosItemSerializationMapping mapAttributes:@"videosItemId",@"name",@"videoURL",@"thumbnailURL",nil];
    [objectManager.mappingProvider setSerializationMapping:videosItemSerializationMapping forClass:[PBVideosItem class]];
    
    // videosActivity serialization
    [videosActivitySerializationMapping mapAttributes:@"videosActivityId",@"uid",@"videosItemId",@"videosActivityType",@"dateAdded",nil];
    [videosActivitySerializationMapping mapRelationship:@"videosItem" withMapping:videosItemSerializationMapping];
    [objectManager.mappingProvider setSerializationMapping:videosActivitySerializationMapping forClass:[PBVideosActivity class]];
    
    // videosFeedback serialization
    [videosFeedbackSerializationMapping mapAttributes:@"videosFeedbackId", @"videosActivityId", @"followerUid", @"videosFeedbackType", nil];
    [videosFeedbackSerializationMapping mapRelationship:@"videosActivity" withMapping:videosActivitySerializationMapping];
    [videosFeedbackSerializationMapping mapRelationship:@"follower" withMapping:userSerializationMapping];
    [objectManager.mappingProvider setSerializationMapping:videosFeedbackSerializationMapping forClass:[PBVideosFeedback class]];
}

#pragma mark -
#pragma mark - handling facebook and foursquare openURL redirects

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if ([[[[url absoluteString] componentsSeparatedByString:@":"] objectAtIndex:0] isEqualToString:@"fb316977565057222"]) {
        return [self.facebook handleOpenURL:url];
    } else if ([[[[url absoluteString] componentsSeparatedByString:@":"] objectAtIndex:0] isEqualToString:@"piggyback"]) {
        return [self.foursquare handleOpenURL:url];
    } else {
        NSLog(@"did not find a matching openURL");
        return NO;
    }
}

// Pre iOS 4.2 support
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [self.facebook handleOpenURL:url]; 
}

#pragma mark -
#pragma mark - BZFoursquareSessionDelegate protocol methods
- (void)foursquareDidAuthorize:(BZFoursquare *)foursquare {
    NSLog(@"foursquare did authorize");
    NSLog(@"foursquare in app delegate is %@",self.foursquare);
    self.foursquareDelegate.didLoginToFoursquare = YES;
    if (self.foursquareDelegate.didFacebookFriendsLoad && self.foursquareDelegate.didLoginToFoursquare && !self.foursquareDelegate.didLoadFoursquareFriends) {
        [self.foursquareDelegate getFoursquareSelf];
        [self.foursquareDelegate getFoursquareFriends];
        NSLog(@"loading foursquare friends after authorization");
    }
}

- (void)foursquareDidNotAuthorize:(BZFoursquare *)foursquare error:(NSDictionary *)errorInfo {
    NSLog(@"foursquare failed to authorize: %@", errorInfo);
}

#pragma mark -
#pragma mark SPSessionDelegate Methods

-(UIViewController *)viewControllerToPresentLoginViewForSession:(SPSession *)aSession {
//    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
//    AccountLinkViewController *accountLinkViewController = [storyboard instantiateViewControllerWithIdentifier:@"accountLinkViewController"];
//	return accountLinkViewController;
    return self.accountLinkNavigationController;
}

-(void)session:(SPSession *)aSession didGenerateLoginCredentials:(NSString *)credential forUserName:(NSString *)userName {
    [[NSUserDefaults standardUserDefaults] setObject:userName forKey:@"spotifyUsername"];
    [[NSUserDefaults standardUserDefaults] setObject:credential forKey:@"spotifyCredentials"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)sessionDidLoginSuccessfully:(SPSession *)aSession; {
    NSLog(@"logged into spotify");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *playlistStringURL = [[NSUserDefaults standardUserDefaults] objectForKey:@"PBPlaylistURL"];
    if (!playlistStringURL) {
        NSLog(@"attempting to create PB playlist");
        
        [SPAsyncLoading waitUntilLoaded:aSession timeout:5.0f then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
            SPPlaylistContainer *plContainer = aSession.userPlaylists;
            [SPAsyncLoading waitUntilLoaded:plContainer timeout:5.0f then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
                [plContainer createPlaylistWithName:@"Piggyback songs" callback:^(SPPlaylist *createdPlaylist) {

                    // move playlist to the top in spotify
                    [plContainer moveItem:createdPlaylist toIndex:0 ofNewParent:nil callback:^(NSError *error) {
                        NSLog(@"PB playlist moved to the top");
                        
                        [SPAsyncLoading waitUntilLoaded:createdPlaylist timeout:5.0f then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
                            // store spotify URL in NSUserDefaults
                            [defaults setObject:[createdPlaylist.spotifyURL absoluteString] forKey:@"PBPlaylistURL"];
                            
                            // set homeViewController playlist property
                            PiggybackTabBarController* tabBarController = (PiggybackTabBarController*)self.window.rootViewController;
                            UINavigationController* navigationController = [tabBarController.viewControllers objectAtIndex:0];
                            HomeViewController* homeViewController = (HomeViewController*)navigationController.topViewController;
                            [homeViewController setPiggybackPlaylist:createdPlaylist];
                        }];
                    }];
                }];
            }];
        }];
    } else {
        // PB playlist already exists -- set homeViewController playlist property
        [SPPlaylist playlistWithPlaylistURL:[NSURL URLWithString:playlistStringURL] inSession:[SPSession sharedSession] callback:^(SPPlaylist *playlist) {
            NSLog(@"connected to PB playlist");
            PiggybackTabBarController* tabBarController = (PiggybackTabBarController*)self.window.rootViewController;
            UINavigationController* navigationController = [tabBarController.viewControllers objectAtIndex:0];
            HomeViewController* homeViewController = (HomeViewController*)navigationController.topViewController;
            [homeViewController setPiggybackPlaylist:playlist];
        }];
    }
}

-(void)session:(SPSession *)aSession didFailToLoginWithError:(NSError *)error; {
    NSLog(@"failed to log into spotify");
//    self.accountLinkViewController.spotifyToggle.on = FALSE;
}

-(void)sessionDidLogOut:(SPSession *)aSession {
	NSLog(@"logged out of spotify");
//    self.accountLinkViewController.spotifyToggle.on = FALSE;
}

-(void)session:(SPSession *)aSession didEncounterNetworkError:(NSError *)error; {}
-(void)session:(SPSession *)aSession didLogMessage:(NSString *)aMessage; {}
-(void)sessionDidChangeMetadata:(SPSession *)aSession; {}

-(void)session:(SPSession *)aSession recievedMessageForUser:(NSString *)aMessage; {
	return;
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message from Spotify"
													message:aMessage
												   delegate:nil
										  cancelButtonTitle:@"OK"
										  otherButtonTitles:nil];
	[alert show];
}

#pragma mark -
#pragma mark -- FBSessionDelegate methods
- (void)fbDidLogin {
    Facebook *facebook = [(AppDelegate *)[[UIApplication sharedApplication] delegate] facebook];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[facebook accessToken] forKey:@"FBAccessTokenKey"];
    [defaults setObject:[facebook expirationDate] forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
    
    // get current user
    PiggybackTabBarController* rootViewController = (PiggybackTabBarController*)self.window.rootViewController;
    [(LoginViewController*)[rootViewController presentedViewController] getAndStoreCurrentUserFbInformationAndUid];
    
    // dismiss login view 
    [rootViewController dismissViewControllerAnimated:NO completion:nil]; // dismisses loginViewController
    
    // show account link page when you log in for the first time
    AccountLinkNavigationController *accountLinkNavigationController = [rootViewController.storyboard instantiateViewControllerWithIdentifier:@"accountLinkNavigationController"];
    self.accountLinkNavigationController = accountLinkNavigationController;
    [rootViewController presentViewController:accountLinkNavigationController animated:NO completion:nil];  
    
    NSLog(@"logged in");
}

- (void)fbDidNotLogin:(BOOL)cancelled {
    NSLog(@"did not log in");
}

-(void)fbDidExtendToken:(NSString *)accessToken expiresAt:(NSDate *)expiresAt {
    NSLog(@"token extended");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:accessToken forKey:@"FBAccessTokenKey"];
    [defaults setObject:expiresAt forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
}

- (void)fbDidLogout {
    // clear NSUserDefaults
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:[NSDictionary dictionary] forName:[[NSBundle mainBundle] bundleIdentifier]];
    
    PiggybackTabBarController* rootViewController = (PiggybackTabBarController*)self.window.rootViewController;
    [rootViewController dismissViewControllerAnimated:NO completion:nil]; // dismisses account view controller

    LoginViewController *loginViewController = [rootViewController.storyboard instantiateViewControllerWithIdentifier:@"loginViewController"];
    [rootViewController presentViewController:loginViewController animated:NO completion:nil];
    
#warning - do not reset tabs
    // release existing view controllers and create new instances for next user who logs in
//    UIViewController* listenNavigationController = [rootViewController.storyboard instantiateViewControllerWithIdentifier:@"listenNavigationController"];
//    UIViewController* exploreNavigationController = [rootViewController.storyboard instantiateViewControllerWithIdentifier:@"exploreNavigationController"];
//    UIViewController* watchNavigationController = [rootViewController.storyboard instantiateViewControllerWithIdentifier:@"watchNavigationController"];
//    NSArray* newTabViewControllers = [NSArray arrayWithObjects:listenNavigationController, exploreNavigationController, watchNavigationController, nil];
//    rootViewController.viewControllers = newTabViewControllers;
//    rootViewController.selectedIndex = 0;
    
    NSLog(@"logged out");
}

- (void)fbSessionInvalidated {
    
}

#pragma mark -
#pragma mark - Remote notification delegation methods

- (void)sendProviderDeviceToken:(NSString *)deviceToken andUid:(NSNumber *)Uid {
    NSLog(@"adding device token from app delegate");
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:deviceToken, @"deviceToken", Uid, @"uid", nil];
    id<RKParser> parser = [[RKParserRegistry sharedRegistry] parserForMIMEType:RKMIMETypeJSON];
    NSError *error = nil;
    NSString *json = [parser stringFromObject:params error:&error];
    
    if (!error) {
        [[RKClient sharedClient] post:@"/addIphonePushToken" params:[RKRequestSerialization serializationWithData:[json dataUsingEncoding:NSUTF8StringEncoding] MIMEType:RKMIMETypeJSON] delegate:self];
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:@"DeviceTokenAdded"];
    }
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *token = [deviceToken description];
    token = [token stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSLog(@"device token obtained: %@", token);
    
    // store device token in defaults if it doesn't exist or it changed
    if (![defaults objectForKey:@"DeviceToken"] || ![[defaults objectForKey:@"DeviceToken"] isEqualToString:token]) {
        [defaults setObject:token forKey:@"DeviceToken"];
        
        // add to DB if already have UID
        if ([defaults objectForKey:@"UID"]) {
            [self sendProviderDeviceToken:token andUid:[defaults objectForKey:@"UID"]];
        } else {
            [defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DeviceTokenAdded"];
        }
    }
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Error in registration. Error: %@", error);
}

#pragma mark - RKRequestDelegate methods

- (void)request:(RKRequest*)request didLoadResponse:(RKResponse*)response {  
    NSLog(@"objects from push notification are %@",[response bodyAsString]);
}

- (void)request:(RKRequest *)request didFailLoadWithError:(NSError *)error {
    NSLog(@"restkit failed with error from push notification: %@", error);
}

#pragma mark -
#pragma mark - AppDelegate methods
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    if (application.applicationState == UIApplicationStateActive) {
        NSLog(@"received push notification");
        self.newsNotificationLabel.alpha = 1.0;
        [UIView animateWithDuration:5.0 animations:^{
            self.newsNotificationLabel.alpha = 0.0;
        }];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
//    [[SPSession sharedSession] logout:^{}];
//    [self.foursquare invalidateSession];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
//    NSLog(@"became active");
//    PiggybackTabBarController* tabBarController = (PiggybackTabBarController*)self.window.rootViewController;
//    UINavigationController* navigationController = [tabBarController.viewControllers objectAtIndex:0];
//    HomeViewController* homeViewController = (HomeViewController*)navigationController.topViewController;
//    [homeViewController fetchAmbassadorFavsFromCoreData];
    
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    NSLog(@"app will terminate");
}

@end
