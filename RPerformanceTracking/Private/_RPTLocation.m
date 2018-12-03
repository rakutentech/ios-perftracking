#import "_RPTLocation.h"

static NSString *const KEY = @"com.rakuten.performancetracking.location";

/* RPT_EXPORT */ @implementation _RPTLocation

- (instancetype)initWithData:(NSData *)data
{
	do
	{
		if (![data isKindOfClass:NSData.class] || !data.length) break;
		
		NSDictionary *values = [NSJSONSerialization JSONObjectWithData:data options:0 error:0];
		if (![values isKindOfClass:NSDictionary.class]) break;
		
		NSArray *responseList = values[@"list"];
		if (![responseList isKindOfClass:NSArray.class] || responseList.count == 0) break;
		
		NSDictionary *responseValues = [NSDictionary dictionaryWithDictionary:(NSDictionary *)responseList[0]];
		if (![responseValues isKindOfClass:NSDictionary.class]) break;
		
		NSArray *resultSubdivisionDetails = responseValues[@"subdivisions"];
		if (![resultSubdivisionDetails isKindOfClass:NSArray.class] || resultSubdivisionDetails.count == 0) break;
		
		NSDictionary *subdivisionValues = resultSubdivisionDetails[0];
		if (![subdivisionValues isKindOfClass:NSDictionary.class]) break;
		
		NSDictionary *countryDetails = responseValues[@"country"];
		if (![countryDetails isKindOfClass:NSDictionary.class]) break;
		
		NSString *location = subdivisionValues[@"names"][@"en"];
		
		NSString *country = countryDetails[@"iso_code"];
		if (![location isKindOfClass:NSString.class] || !location.length ||
			![country isKindOfClass:NSString.class] || !country.length) break;
		/*
		 * City is valid.
		 */
		if ((self = [super init]))
		{
			_location = location;
			_country = country;
		}
		return self;
	} while(0);
	
	return nil; // invalid object
}

+ (instancetype)loadLocation
{
	NSData *locationData = [NSUserDefaults.standardUserDefaults objectForKey:KEY];
	return locationData ? [self.alloc initWithData:locationData] : nil;
}

+ (void)persistWithData:(NSData *)data
{
	if (data.length) [NSUserDefaults.standardUserDefaults setObject:data forKey:KEY];
}

@end

@implementation _RPTLocationFetcher

+ (void)fetch
{
    NSURLSessionConfiguration *sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration;
    NSString *subscriptionKey = [NSBundle.mainBundle objectForInfoDictionaryKey:@"RPTSubscriptionKey"];
    
    NSURL *locationURL = nil;
    NSString *locationURLString = [NSBundle.mainBundle objectForInfoDictionaryKey:@"RPTLocationAPIEndpoint"];
    
    if (locationURLString.length) { locationURL = [NSURL URLWithString:locationURLString]; }
#if DEBUG
    NSAssert(locationURL, @"Your application's Info.plist must contain a key 'RPTLocationAPIEndpoint' set to the endpoint URL of your Location API");
#endif
    
    if (!locationURL) return;
    
    if (subscriptionKey) { sessionConfiguration.HTTPAdditionalHeaders = @{@"Ocp-Apim-Subscription-Key":subscriptionKey}; }
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    
    [[session dataTaskWithURL:locationURL completionHandler:^(NSData *data, __unused NSURLResponse *response, __unused NSError * error)
      {
          if (!error && [response isKindOfClass:NSHTTPURLResponse.class])
          {
              NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
              if (httpResponse.statusCode == 200 && data)
              {
                  _RPTLocation *locationConfig = [_RPTLocation.alloc initWithData:data];
                  if (locationConfig)
                  {
                      [_RPTLocation persistWithData:data];
                  }
              }
          }
      }] resume];
}
@end
