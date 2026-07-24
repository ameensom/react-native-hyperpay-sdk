
#import <Foundation/Foundation.h>
#import "HyperPay.h"
#import <React/RCTLog.h>
#import <PassKit/PassKit.h>

@implementation HyperPay

OPPPaymentProvider *provider;
OPPCheckoutProvider *checkoutProvider; // must be retained for the whole async Apple Pay flow
NSString *shopperResultURL = @"";
NSString *merchantIdentifier = @"";
NSString *countryCode = @"";
NSString *mode=@"TestMode";
NSArray *supportedNetworks;
NSString *companyName=@"";

RCT_EXPORT_MODULE(HyperPay)

-(instancetype)init
{
  
    self = [super init];
    if (self) {
        provider = [OPPPaymentProvider paymentProviderWithMode:OPPProviderModeTest];
    }
    return self;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"onTransactionComplete",@"onProgress"];
}

/**
 React Native functions
 */


RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(setup: (NSDictionary*)options) {
    shopperResultURL=[options valueForKey:@"shopperResultURL"];
    if ([options valueForKey:@"merchantIdentifier"])
        merchantIdentifier=[options valueForKey:@"merchantIdentifier"];
    if ([options valueForKey:@"companyName"])
        companyName=[options valueForKey:@"companyName"];
    if ([options valueForKey:@"countryCode"])
       countryCode=[options valueForKey:@"countryCode"];
    if ([options valueForKey:@"supportedNetworks"])
        supportedNetworks=[options valueForKey:@"supportedNetworks"];
    if ([[options valueForKey:@"mode"] isEqual:@"LiveMode"])
      provider = [OPPPaymentProvider paymentProviderWithMode:OPPProviderModeLive];
    else
      provider = [OPPPaymentProvider paymentProviderWithMode:OPPProviderModeTest];
    return options;
}


RCT_EXPORT_METHOD(createPaymentTransaction: (NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSError * _Nullable error;

    OPPCardPaymentParams *params = [OPPCardPaymentParams cardPaymentParamsWithCheckoutID:[options valueForKey:@"checkoutID"]
                                                                        paymentBrand:[options valueForKey:@"paymentBrand"]
                                                                              holder:[options valueForKey:@"holderName"]
                                                                              number:[options valueForKey:@"cardNumber"]
                                                                         expiryMonth:[options valueForKey:@"expiryMonth"]
                                                                          expiryYear:[options valueForKey:@"expiryYear"]
                                                                                 cvv:[options valueForKey:@"cvv"]
                                                                               error:&error];

    if (error) {
      NSLog(@"%s", "error");
      reject(@"createTransaction",error.localizedDescription, error);

    } else {
       params.shopperResultURL =shopperResultURL;
       
      OPPTransaction *transaction = [OPPTransaction transactionWithPaymentParams:params];

      [provider submitTransaction:transaction completionHandler:^(OPPTransaction * _Nonnull transaction, NSError * _Nullable error) {
        NSDictionary *transactionResult;
        if (transaction.type == OPPTransactionTypeAsynchronous) {
            
           transactionResult = @{
          @"redirectURL":transaction.redirectURL.absoluteString,
          @"status":@"pending",
          @"checkoutId":transaction.paymentParams.checkoutID
          };
          resolve(transactionResult);

        }  else if (transaction.type == OPPTransactionTypeSynchronous) {

          transactionResult = @{
          @"status":@"completed",
          @"checkoutId":transaction.paymentParams.checkoutID
          };
          resolve(transactionResult);
        } else {
          reject(@"createTransaction",error.localizedDescription, error);
        }
      }];
    }
}



RCT_EXPORT_METHOD(applePay:(NSDictionary*)params resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
  
  OPPCheckoutSettings *checkoutSettings = [[OPPCheckoutSettings alloc] init];
  PKPaymentRequest *paymentRequest = [OPPPaymentProvider paymentRequestWithMerchantIdentifier:merchantIdentifier countryCode:countryCode];

  // A PKPaymentRequest with no currencyCode is invalid, so iOS cannot build the Apple Pay
  // sheet and OPP swallows it without calling any handler (the silent spinner). OPP's helper
  // sets countryCode but NOT currencyCode, so set them explicitly here.
  paymentRequest.countryCode = (countryCode.length > 0) ? countryCode : @"SA";
  paymentRequest.currencyCode = @"SAR";
  paymentRequest.merchantCapabilities = PKMerchantCapability3DS;

  // Map the raw network strings (e.g. lowercase 'mada') to valid PKPaymentNetwork constants.
  // Assigning raw strings makes the PKPaymentRequest invalid, so the Apple Pay sheet never presents.
  NSMutableArray<PKPaymentNetwork> *pkNetworks = [NSMutableArray array];
  for (NSString *n in supportedNetworks) {
    NSString *low = [[n description] lowercaseString];
    if ([low isEqualToString:@"visa"]) { [pkNetworks addObject:PKPaymentNetworkVisa]; }
    else if ([low isEqualToString:@"mastercard"] || [low isEqualToString:@"master"]) { [pkNetworks addObject:PKPaymentNetworkMasterCard]; }
    else if ([low isEqualToString:@"mada"]) { if (@available(iOS 12.1.1, *)) { [pkNetworks addObject:PKPaymentNetworkMada]; } }
    else if ([low isEqualToString:@"amex"] || [low isEqualToString:@"americanexpress"]) { [pkNetworks addObject:PKPaymentNetworkAmex]; }
  }
  if (pkNetworks.count > 0) {
    paymentRequest.supportedNetworks = pkNetworks;
  }

  if ([params valueForKey:@"companyName"]){
      companyName=[params valueForKey:@"companyName"];
  }
  // amount arrives as a major-unit string (e.g. "18" = 18.00 SAR); parse it directly instead
  // of treating it as minor units (the old intValue * 10^-2 turned "18" into 0.18).
  NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithString:[params valueForKey:@"amount"]];
  if (amount == nil || [amount isEqualToNumber:[NSDecimalNumber notANumber]]) {
    amount = [NSDecimalNumber zero];
  }
  paymentRequest.paymentSummaryItems = @[[PKPaymentSummaryItem summaryItemWithLabel:companyName amount:amount]];


  checkoutSettings.shopperResultURL=shopperResultURL;
  checkoutSettings.applePayPaymentRequest = paymentRequest;
  // Assign to the retained file-scope variable (NOT a local) so the provider survives the
  // async present flow; a local would be deallocated immediately and the checkout would die.
  checkoutProvider = [OPPCheckoutProvider checkoutProviderWithPaymentProvider:provider
                                                                   checkoutID:[params valueForKey:@"checkoutID"]
                                                                     settings:checkoutSettings];

  [checkoutProvider presentCheckoutWithPaymentBrand:@"APPLEPAY"
    loadingHandler:^(BOOL inProgress) {
      [self sendEventWithName:@"onProgress" body:@(inProgress)];
      // Executed whenever SDK sends request to the server or receives the response.
      // You can start or stop loading animation based on inProgress parameter.
  } completionHandler:^(OPPTransaction * _Nullable transaction, NSError * _Nullable error) {
      if (error) {
//          reject(@"applePay",checkoutID,error);
        reject(@"applePay",error.localizedDescription, error);
          // See code attribute (OPPErrorCode) and NSLocalizedDescription to identify the reason of failure.
      } else {
          if (transaction.redirectURL)
              resolve(@{@"redirectURL": transaction.redirectURL.absoluteString});
          else
              resolve(@{@"resourcePath": transaction.resourcePath});
      }
      checkoutProvider = nil;
  } cancelHandler:^{
       reject(@"applePay",@"cancel",NULL);
      // Executed if the shopper closes the payment page prematurely.
       checkoutProvider = nil;
  }];

}


@end


