//
//  ViewController.h
//  PullVideoThumbnail
//
//  Created by Terry Bu on 3/27/15.
//  Copyright (c) 2015 Terry Bu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet UILabel *stillsStatusLabel;
@property (weak, nonatomic) IBOutlet UIButton *produceVideoButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *playBarButton;
- (IBAction)playCompletedVideo:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *saveVideoButton;
- (IBAction) saveVideo;

@end

