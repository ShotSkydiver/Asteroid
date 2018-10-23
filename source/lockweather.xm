#include "lockweather.h"

//TODO Change today to use the cases in descriptions
//TODO Fix Blur on lockscreen vs just pulling down notification center
//TODO Customization, move portion of view around
//TODO Scroll with notifications, hide during notifications etc
//TODO add dismiss button
//TODO make only appear during set times
//TODO Make sure to add the camera fix from nine to this tweak (thats casle problem)


NSBundle *tweakBundle = [NSBundle bundleWithPath:@"/Library/Application Support/lockWeather.bundle"];
//NSString *alertTitle = [tweakBundle localizedStringForKey:@"ALERT_TITLE" value:@"" table:nil];


// Data required for the isOnLockscreen() function --------------------------------------------------------------------------------------
BOOL isUILocked() {
    long count = [[[%c(SBFPasscodeLockTrackerForPreventLockAssertions) sharedInstance] valueForKey:@"_assertions"] count];
    if (count == 0) return YES; // array is empty
    if (count == 1) {
        if ([[[[[[%c(SBFPasscodeLockTrackerForPreventLockAssertions) sharedInstance] valueForKey:@"_assertions"] allObjects] objectAtIndex:0] identifier] isEqualToString:@"UI unlocked"]) return NO; // either device is unlocked or an app is opened (from the ones allowed on lockscreen). Luckily system gives us enough info so we can tell what happened
        else return YES; // if there are more than one should be safe enough to assume device is unlocked
    }
    else return NO;
}
 
static BOOL isOnCoverSheet; // the data that needs to be analyzed
 
BOOL isOnLockscreen() {
    //NSLog(@"nine_TWEAK | %d", isOnCoverSheet);
    if(isUILocked()){
        isOnCoverSheet = YES; // This is used to catch an exception where it was locked, but the isOnCoverSheet didnt update to reflect.
        return YES;
        }
        else if(!isUILocked() && isOnCoverSheet == YES) return YES;
        else if(!isUILocked() && isOnCoverSheet == NO) return NO;
        else return NO;
}
 
 static id _instance;
 
%hook SBFPasscodeLockTrackerForPreventLockAssertions
- (id) init {
    if (_instance == nil) _instance = %orig;
    else %orig; // just in case it needs more than one instance
    return _instance;
}
%new
 // add a shared instance so we can use it later
+ (id) sharedInstance {
    if (!_instance) return [[%c(SBFPasscodeLockTrackerForPreventLockAssertions) alloc] init];
    return _instance;
}
%end
 
 // Setting isOnCoverSheet properly, actually works perfectly
 %hook SBCoverSheetSlidingViewController
 - (void)_finishTransitionToPresented:(_Bool)arg1 animated:(_Bool)arg2 withCompletion:(id)arg3 {
     if((arg1 == 0) && ([self dismissalSlidingMode] == 1)){
         if(!isUILocked()) isOnCoverSheet = NO;
         } 
         else if ((arg1 == 1) && ([self dismissalSlidingMode] == 1)){
             if(isUILocked()) isOnCoverSheet = YES;
             }
             %orig;
    }
 %end
 // end of data required for the isOnLockscreen() function --------------------------------------------------------------------------------------


static BOOL numberOfNotifcations;
static BOOL isDismissed;

%hook SBDashBoardMainPageView
%property (nonatomic, retain) UIView *weather;
%property (nonatomic, retain) UIImageView *logo;
%property (nonatomic, retain) UILabel *greetingLabel;
%property (nonatomic, retain) UILabel *description;
%property (nonatomic, retain) UILabel *currentTemp;
%property (retain, nonatomic) UIVisualEffectView *blurView;
%property (retain, nonatomic) UIButton *dismissButton;
%property (retain, nonatomic) WALockscreenWidgetViewController *weatherCont;
%property (retain, nonatomic) NSTimer *refreshTimer;


- (void)layoutSubviews {
    %orig;

    if(!self.weather){
        self.weather=[[UIView alloc]initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [self.weather setBackgroundColor:[UIColor clearColor]];
        [self.weather setUserInteractionEnabled:NO];
        [self addSubview:self.weather];
    }
    
    // Just some rect stuff
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    
    if(!self.logo){
        self.logo = [[UIImageView alloc] initWithFrame:CGRectMake(screenWidth/3.6, screenHeight/2.1, 100, 225)];
        [self.weather addSubview:self.logo];
    }   

    [[CSWeatherInformationProvider sharedProvider] updatedWeatherWithCompletion:^(NSDictionary *weather) {
        UIImage *icon;
        // Updating the image icon
        BOOL setColor = FALSE;
        if([[prefs stringForKey:@"setImageType"] isEqualToString:@"Standard"]){
            icon = weather[@"kCurrentConditionImage_nc-variant"];
        }else if ([[prefs stringForKey:@"setImageType"] isEqualToString:@"Filled Solid Color"]){
            icon = weather[@"kCurrentConditionImage_white-variant"];
            setColor = TRUE;
        }else{
            icon = weather[@"kCurrentConditionImage_black-variant"];
            setColor = TRUE;
        }
        
        self.logo.image = icon;
        if(setColor){
            self.logo.image = [self.logo.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.logo setTintColor:[prefs colorForKey:@"glyphColor"]];
        }
        

        self.logo.contentMode = UIViewContentModeScaleAspectFit;
    }];
    
    //Current Temperature Localized
    if(!self.currentTemp){
        self.currentTemp = [[UILabel alloc] initWithFrame:CGRectMake(screenWidth/2.1, screenHeight/2.1, 100, 225)];
        self.currentTemp.textAlignment = NSTextAlignmentCenter;
        self.currentTemp.textColor = [prefs colorForKey:@"textColor"];//[prefs colorForKey:@"textColor"];];
        [self.currentTemp setUserInteractionEnabled:NO];
        [self.weather addSubview: self.currentTemp];
    }
    
    // Updating the font
    if([prefs boolForKey:@"customFont"]){
        self.currentTemp.font = [UIFont fontWithName:[prefs stringForKey:@"availableFonts"] size:[prefs intForKey:@"tempSize"]];
    }else{
        self.currentTemp.font = [UIFont systemFontOfSize: [prefs intForKey:@"tempSize"] weight: UIFontWeightLight];
    }
    self.currentTemp.textColor = [prefs colorForKey:@"textColor"];
    
    if(!self.greetingLabel){
        self.greetingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.frame.size.height/2.5, self.frame.size.width, self.frame.size.height/8.6)];
        self.greetingLabel.textAlignment = NSTextAlignmentCenter;
        self.greetingLabel.textColor = [prefs colorForKey:@"textColor"];
        [self.greetingLabel setUserInteractionEnabled:NO];
        [self.weather addSubview:self.greetingLabel];
    }
    
    // Setting Greeting Label Font
    if([prefs boolForKey:@"customFont"]){
        self.greetingLabel.font = [UIFont fontWithName:[prefs stringForKey:@"availableFonts"] size:[prefs intForKey:@"greetingSize"]];
    }else{
        self.greetingLabel.font = [UIFont systemFontOfSize:[prefs intForKey:@"greetingSize"] weight: UIFontWeightLight];
    }
    self.greetingLabel.textColor = [prefs colorForKey:@"textColor"];

    
    
    if(!self.description){
        self.description = [[UILabel alloc] initWithFrame:CGRectMake(0, self.frame.size.height/2.1, self.weather.frame.size.width, self.frame.size.height/8.6)];
        self.description.textAlignment = NSTextAlignmentCenter;
        self.description.lineBreakMode = NSLineBreakByWordWrapping;
        self.description.numberOfLines = 0;
        self.description.textColor = [prefs colorForKey:@"textColor"];
        self.description.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.description setUserInteractionEnabled:NO];
        self.description.preferredMaxLayoutWidth = self.weather.frame.size.width;
        [self.weather addSubview:self.description];
    }
    
    // Setting the font for the description
    if([prefs boolForKey:@"customFont"]){
        self.description.font = [UIFont fontWithName:[prefs stringForKey:@"availableFonts"] size:[prefs intForKey:@"descriptionSize"]];
    }else{
        self.description.font = [UIFont systemFontOfSize:[prefs intForKey:@"descriptionSize"]];
    }
    self.description.textColor = [prefs colorForKey:@"textColor"];
    
    if(!self.dismissButton){
        self.dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.dismissButton addTarget:self
                               action:@selector(buttonPressed:)
                     forControlEvents:UIControlEventTouchUpInside];
        [self.dismissButton setTitle:@"Dismiss" forState:UIControlStateNormal];
        self.dismissButton.frame = CGRectMake(0, self.frame.size.height/1.3, self.frame.size.width, self.frame.size.height/8.6);
        [self.weather addSubview:self.dismissButton];
    }
    // Creating a refresh timer
    if(!self.refreshTimer){
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:300.0
                                                             target:self
                                                           selector:@selector(updateWeather:)
                                                           userInfo:nil
                                                            repeats:NO];
        
        // making sure the weather is updated once
        [self.refreshTimer fire];
    }

    

}
/*%new
-(void)updateImage:(NSNotification *) notification{
    NSLog(@"IMRUNNINGOK");
    [[CSWeatherInformationProvider sharedProvider] updatedWeatherWithCompletion:^(NSDictionary *weather) {
        UIImage *icon;    
        if([[notification name] isEqualToString:@"setStandard"]){
            icon = weather[@"kCurrentConditionImage_nc-variant"];
        }
        if([[notification name] isEqualToString:@"setFilled"]){
            icon = weather[@"kCurrentConditionImage_white-variant"];
        }
        if([[notification name] isEqualToString:@"setOutline"]){
            icon = weather[@"kCurrentConditionImage_black-variant"];
        }

        self.logo.image = icon;
        self.logo.image = [self.logo.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self.logo setTintColor:[prefs colorForKey:@"glyphColor"]];

        self.logo.contentMode = UIViewContentModeScaleAspectFit;

    }];
}*/

-(void) dealloc {
    [self.refreshTimer invalidate];
    %orig;
}
%new
- (void) buttonPressed: (UIButton*)sender{
    [UIView animateWithDuration:.5
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{self.weather.alpha = 0;}
                     completion:^(BOOL finished){
                         self.weather.hidden = YES;
                         self.weather.alpha = 1;
                     }];
    isDismissed = YES;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"weatherDismissButtonPressed"
     object:self];
}

%new
- (void) updateWeather: (NSTimer *) sender{
    [[CSWeatherInformationProvider sharedProvider] updatedWeatherWithCompletion:^(NSDictionary *weather) {
        UIImage *icon;
        // Updating the image icon
        BOOL setColor = FALSE;
        if([[prefs stringForKey:@"setImageType"] isEqualToString:@"Standard"]){
            icon = weather[@"kCurrentConditionImage_nc-variant"];
        }else if ([[prefs stringForKey:@"setImageType"] isEqualToString:@"Filled Solid Color"]){
            icon = weather[@"kCurrentConditionImage_white-variant"];
            setColor = TRUE;
        }else{
            icon = weather[@"kCurrentConditionImage_black-variant"];
            setColor = TRUE;
        }
        
        self.logo.image = icon;
        if(setColor){
            self.logo.image = [self.logo.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.logo setTintColor:[prefs colorForKey:@"glyphColor"]];
        }
        

        self.logo.contentMode = UIViewContentModeScaleAspectFit;
        
        // Setting the current temperature text
        if(weather[@"kCurrentTemperatureFahrenheit"] != nil){
            self.currentTemp.text = weather[@"kCurrentTemperatureForLocale"];
        }else{
            self.currentTemp.text = @"Error";
        }
        
        // Updating the Greeting Label
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"HH"];
        dateFormat.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        NSDate *currentTime;
        currentTime = [NSDate date];
        
        switch ([[dateFormat stringFromDate:currentTime] intValue]){
            case 0 ... 4:
                self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Evening" value:@"" table:nil];//NSLocalizedString(@"Good_Evening", @"Good Evening equivalent"); //@"Good Evening";
                break;
                
            case 5 ... 11:
                self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Morning" value:@"" table:nil];
                break;
                
            case 12 ... 17:
                self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Afternoon" value:@"" table:nil];
                break;
                
            case 18 ... 24:
                self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Evening" value:@"" table:nil];//NSLocalizedString(@"Good_Evening", @"Good Evening equivalent");//@"Good Evening";
                break;
        }
        
        self.greetingLabel.textAlignment = NSTextAlignmentCenter;
        if([prefs boolForKey:@"customFont"]){
            self.greetingLabel.font = [UIFont fontWithName:[prefs stringForKey:@"availableFonts"] size:[prefs intForKey:@"greetingSize"]];
        }else{
            self.greetingLabel.font = [UIFont systemFontOfSize:[prefs intForKey:@"greetingSize"] weight: UIFontWeightLight];
        }
        ////[UIFont boldSystemFontOfSize:40];
        self.greetingLabel.textColor = [prefs colorForKey:@"textColor"];
        [self.weather addSubview:self.greetingLabel];
        
        //[[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.width/21, self.frame.size.height/2, self.frame.size.width/1.1, self.frame.size.height/10)];
        
        self.description = [[UILabel alloc] initWithFrame:CGRectMake(0, self.frame.size.height/2.1, self.frame.size.width, self.frame.size.height/8.6)];
        self.description.text = weather[@"kCurrentDescription"];
        self.description.textAlignment = NSTextAlignmentCenter;
        self.description.lineBreakMode = NSLineBreakByWordWrapping;
        self.description.numberOfLines = 0;
        self.description.textColor = [prefs colorForKey:@"textColor"];
        self.description.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.description setUserInteractionEnabled:NO];


        if([prefs boolForKey:@"customFont"]){
            self.description.font = [UIFont fontWithName:[prefs stringForKey:@"availableFonts"] size:[prefs intForKey:@"descriptionSize"]];
        }else{
            self.description.font = [UIFont systemFontOfSize:[prefs intForKey:@"descriptionSize"]];
        }
        //self.description.font = [UIFont systemFontOfSize:20];
        self.description.preferredMaxLayoutWidth = self.frame.size.width;
        //[self.description sizeToFit];

        //CGPoint center = self.weather.center;
        //center.y = self.weather.frame.size.height / 1.85;
        //[self.description setCenter:center];


        [self.weather addSubview:self.description];
    }];
}
%end

// Checking content
%hook NCNotificationCombinedListViewController
-(BOOL)hasContent{
    BOOL content = %orig;
    if(content != numberOfNotifcations){
        // send a notification with user info for content. Dont forget to check ((!isOnLockscreen()) ? YES : self.isShowingNotificationsHistory)
        //self.view.hidden = YES;
    }
    // Sending values to the background controller
    //[[TCBackgroundViewController sharedInstance] updateSceenShot: content isRevealed: ((!isOnLockscreen()) ? YES : self.isShowingNotificationsHistory)]; // NC is never set to lock
    numberOfNotifcations = content;
    return content;
}
%end

//Blur 
%hook SBDashBoardViewController
%property (nonatomic, retain) UIVisualEffectView *notifEffectView;
%property (nonatomic, retain) UIVisualEffectView *blurEffectView;

-(void)loadView{
    %orig;
    
    //NSLog(@"lock_TWEAK | blur");
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithBlurRadius:[prefs intForKey:@"blurAmount"]];
    self.blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    //always fill the view
    self.blurEffectView.frame = self.view.bounds;
    self.blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    //[self.view addSubview:blurEffectView];
    //[self.view sendSubviewToBack: blurEffectView];
    [((SBDashBoardView *)self.view).backgroundView addSubview: self.blurEffectView];
    
    // Notification called when the lockscreen / nc is revealed (this is posted by the system)
    [[NSNotificationCenter defaultCenter] addObserverForName: @"weatherDismissButtonPressed" object:NULL queue:NULL usingBlock:^(NSNotification *note) {
        [UIView animateWithDuration:.5
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{self.blurEffectView.alpha = 0;}
                         completion:^(BOOL finished){
                             self.blurEffectView.hidden = YES;
                             self.blurEffectView.alpha = 1;
                         }];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName: @"SBCoverSheetWillPresentNotification" object:NULL queue:NULL usingBlock:^(NSNotification *note) {
        if(!isDismissed) self.blurEffectView.hidden = isOnLockscreen() ? NO : YES;
    }];
}

%end 

%ctor{
    if([prefs boolForKey:@"kLWPEnabled"]){
        %init(_ungrouped);
    }
}
