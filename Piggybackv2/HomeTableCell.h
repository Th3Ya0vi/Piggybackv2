//
//  HomeTableCell.h
//  Piggybackv2
//
//  Created by Kimberly Hsiao on 7/10/12.
//  Copyright (c) 2012 Calimucho. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HomeTableCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel* nameOfItem;
@property (nonatomic, weak) IBOutlet UILabel* favoritedBy;
@property (nonatomic, weak) IBOutlet UIImageView* profilePic;
@property (nonatomic, weak) IBOutlet UILabel* date;
@property (nonatomic, weak) IBOutlet UIButton* heart;
@property (nonatomic, weak) IBOutlet UIButton* todo;
@property (nonatomic, strong) NSString* mediaType;

- (IBAction)heart:(id)sender;
- (IBAction)todo:(id)sender;

@end