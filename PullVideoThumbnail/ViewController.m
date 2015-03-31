//
//  ViewController.m
//  PullVideoThumbnail
//
//  Created by Terry Bu on 3/27/15.
//  Copyright (c) 2015 Terry Bu. All rights reserved.
//

#import "ViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "CEMovieMaker.h"
#import "SVProgressHUD.h"

@import MediaPlayer;
//Crucial import makes MPPlayer code work below

@interface ViewController () {
    UIImage *thumbnail;
    Float64 limit;
    NSURL *videoCompletedFileURL;
    ALAssetsLibrary *assetsLibrary;
}

@property (nonatomic, strong) CEMovieMaker *movieMaker;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //we don't show imagepickercontroller from viewdidload - because it complains of attempting to present pickercontroller before this vc is ready - viewDidLayOutSubviews does better.
    
    self.stillsStatusLabel.text = @"";
    self.playBarButton.enabled = NO;
    self.produceVideoButton.hidden = YES;
    self.saveVideoButton.hidden = YES;

}


-(IBAction)showImagePickerController {
    // 1 - Validations
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary] == NO) {
        NSLog(@"couldn't open photo library");
    }
    // 2 - Get image picker
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    //To allow only VIDEOS to show up on selection picker menu - default is all photos/videos
    //Note that kUTypeMovie throws "undeclared identifier" error, if you don't import MobileCoreServices Framework
    imagePickerController.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, nil];

    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    imagePickerController.allowsEditing = NO;
    imagePickerController.delegate = self;
    // 3 - Display image picker
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    [self dismissViewControllerAnimated:YES completion:^{
        
        [SVProgressHUD show];
        
        //validate that it's a video
        if (CFStringCompare ((__bridge_retained CFStringRef)mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
            NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
            assetsLibrary = [[ALAssetsLibrary alloc] init];
            //import <AssetsLibrary> for this
            [assetsLibrary assetForURL:videoURL resultBlock:^(ALAsset *asset) {
                //this is the block to use with your asset
                //whatever you want to perform to your asset, you should do so in this block
                //user might have to say yes to permission. If denied, failure block will get called
                
                AVAsset *avAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
                AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc]initWithAsset:avAsset];
                imageGenerator.appliesPreferredTrackTransform = YES;
                imageGenerator.requestedTimeToleranceAfter =  kCMTimeZero;
                imageGenerator.requestedTimeToleranceBefore =  kCMTimeZero;
                int FPS = 25;
                limit = CMTimeGetSeconds(avAsset.duration) *  FPS;
                for (Float64 i = 0; i < limit; i++){
                    @autoreleasepool {
                        CMTime time = CMTimeMake(i, FPS);
                        NSError *err;
                        CMTime actualTime;
                        CGImageRef image = [imageGenerator copyCGImageAtTime:time actualTime:&actualTime error:&err];
                        UIImage *generatedImage = [[UIImage alloc] initWithCGImage:image];
                        [self saveImage: generatedImage index:i];
                        //Saves the image on document directory and not memory
                        if (i == 0)
                            thumbnail = generatedImage;
                        CGImageRelease(image);
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.thumbnailImageView.image = thumbnail;
                    NSLog(@"total # of stills: %f", limit);
                    [SVProgressHUD dismiss];
                    self.stillsStatusLabel.text = @"Still Thumbnails Successfuly Generated From Selected Video";
                    self.produceVideoButton.hidden = NO;
                });
            } failureBlock:nil];
        }
    }];
}

- (void) saveImage: (UIImage *) image index: (int) i {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"frame%d", i]];
    NSLog(@"filePath %@", filePath);
    NSData *data = UIImagePNGRepresentation(image);
    [data writeToFile:filePath atomically:YES];
}

- (IBAction) produceVideo
{
    [SVProgressHUD show];
    
    NSMutableArray *frames = [self loadImagesFromSavedDirectoryIntoArray];
    [self createMovieOutofStillPhotos:frames];
}

- (NSMutableArray *) loadImagesFromSavedDirectoryIntoArray {
    NSMutableArray *frames = [[NSMutableArray alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    for (int i=0; i < limit; i++) {
        NSString* filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"frame%d", i]];
        UIImage* image = [UIImage imageWithContentsOfFile:filePath];
        [frames addObject:image];
    }
    
    [frames setObject:[UIImage imageNamed:@"sun"] atIndexedSubscript:3];
    [frames setObject:[UIImage imageNamed:@"sun"] atIndexedSubscript:4];
    [frames setObject:[UIImage imageNamed:@"sun"] atIndexedSubscript:10];
    [frames setObject:[UIImage imageNamed:@"sun"] atIndexedSubscript:11];

    //interjecting with a random image in the middle of video
    
    return frames;
}

- (void) createMovieOutofStillPhotos: (NSMutableArray *) arrayOfFrames {
    UIImage *image = arrayOfFrames[0];
    NSDictionary *settings = [CEMovieMaker videoSettingsWithCodec:AVVideoCodecH264 withWidth:image.size.width andHeight:image.size.height];
    self.movieMaker = [[CEMovieMaker alloc] initWithSettings:settings];
    [self.movieMaker createMovieFromImages:[arrayOfFrames copy] withCompletion:^(NSURL *fileURL){
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            
            self.playBarButton.enabled = YES;
            self.produceVideoButton.hidden = YES;
            self.saveVideoButton.hidden = NO;
            
            self.stillsStatusLabel.text = @"A new video was successfully created from our extracted frames";
        });
        [self viewMovieAtUrl:fileURL];
        videoCompletedFileURL = fileURL;
    }];
}

- (IBAction)playCompletedVideo:(id)sender {
    MPMoviePlayerViewController *playerController = [[MPMoviePlayerViewController alloc] initWithContentURL: videoCompletedFileURL];
    [playerController.view setFrame:self.view.bounds];
    [self presentMoviePlayerViewControllerAnimated:playerController];
    [playerController.moviePlayer prepareToPlay];
    [playerController.moviePlayer play];
    [self.view addSubview:playerController.view];
}

- (void)viewMovieAtUrl:(NSURL *)fileURL
{
    MPMoviePlayerViewController *playerController = [[MPMoviePlayerViewController alloc] initWithContentURL:fileURL];
    [playerController.view setFrame:self.view.bounds];
    [self presentMoviePlayerViewControllerAnimated:playerController];
    [playerController.moviePlayer prepareToPlay];
    [playerController.moviePlayer play];
    [self.view addSubview:playerController.view];
}

- (IBAction) saveVideo {
    [SVProgressHUD show];
    
    if (videoCompletedFileURL) {
        UISaveVideoAtPathToSavedPhotosAlbum([videoCompletedFileURL relativePath], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }
    
    //another way to save video to your photos album
//    if (videoCompletedFileURL && [assetsLibrary videoAtPathIsCompatibleWithSavedPhotosAlbum:videoCompletedFileURL]) {
//        [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:videoCompletedFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
//            
//        }];
//    }
    
    [SVProgressHUD dismiss];
}

-(void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    if (error) {
        NSLog(@"Finished with error: %@", error);
        return;
    }
    NSLog(@"we finished saving video to your album");
    UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"Saved Video" message:@"Your newly created video got saved to Photos" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [alertView show];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
