#import "LiveWeather.h"
#import "LiveWeatherView.h"
#include "notify.h"
#import "Asteroid.h"

@interface LiveWeatherView ()
@property (assign, nonatomic) BOOL readyForUpdates;
@property (nonatomic, retain) WUIWeatherConditionBackgroundView *referenceView;
@property (nonatomic, retain) UIImageView *logo;
@end

@implementation LiveWeatherView

static WUIDynamicWeatherBackground* dynamicBG = nil;
static WUIWeatherCondition* condition = nil;



- (instancetype)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithRed:0.118 green:0.118 blue:0.125 alpha:1.00];
        [[CSWeatherInformationProvider sharedProvider] updatedWeatherWithCompletion:^(NSDictionary *weather) {
          self.logo = [[UIImageView alloc] initWithFrame:self.frame];
          UIImage *icon;
          icon = weather[@"kCurrentConditionImage"];
          self.logo.image = icon;
          self.logo.contentMode = UIViewContentModeScaleAspectFit;
          self.logo.center = self.center;
          [self addSubview: self.logo];

          WeatherPreferences* wPrefs = [%c(WeatherPreferences) sharedPreferences];
          City* city = [wPrefs localWeatherCity];
          if(city){
           self.referenceView = [[%c(WUIWeatherConditionBackgroundView) alloc] initWithFrame:self.bounds];
           [self.referenceView.background setCity:city];
           [[self.referenceView.background condition] resume];
           
           self.referenceView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
           [self addSubview:self.referenceView];
           [self sendSubviewToBack:self.referenceView];
           
          }
        }];
    }

    return self;
}
-(void)updateWeatherDisplay{
    if(self.referenceView){
        [self.referenceView removeFromSuperview];
        self.referenceView = nil;
    }
    WeatherPreferences* wPrefs = [%c(WeatherPreferences) sharedPreferences];
    City* city = [wPrefs localWeatherCity];
    if(city){
        self.referenceView = [[%c(WUIWeatherConditionBackgroundView) alloc] initWithFrame:self.bounds];
        [self.referenceView.background setCity:city];
        [[self.referenceView.background condition] resume];
        self.referenceView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.referenceView];
        [self sendSubviewToBack:self.referenceView];
    }

    [[CSWeatherInformationProvider sharedProvider] updatedWeatherWithCompletion:^(NSDictionary *weather) {
          UIImageView *logo = [[UIImageView alloc] initWithFrame:self.frame];
          UIImage *icon;
          icon = weather[@"kCurrentConditionImage"];
          logo.image = icon;
          logo.contentMode = UIViewContentModeScaleAspectFit;
    }];

}

@end