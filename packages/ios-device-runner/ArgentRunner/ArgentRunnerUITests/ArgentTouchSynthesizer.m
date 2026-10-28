#import "ArgentTouchSynthesizer.h"

/// The selectors used on XCTest's private classes, declared as protocols so the
/// compiler can check the calls without a class symbol to link against.
@protocol ArgentPointerEventPath <NSObject>
- (instancetype)initForTouchAtPoint:(CGPoint)point offset:(NSTimeInterval)offset;
- (void)moveToPoint:(CGPoint)point atOffset:(NSTimeInterval)offset;
- (void)liftUpAtOffset:(NSTimeInterval)offset;
@end

@protocol ArgentSynthesizedEventRecord <NSObject>
- (instancetype)initWithName:(NSString *)name
        interfaceOrientation:(UIInterfaceOrientation)orientation;
- (void)addPointerEventPath:(id<ArgentPointerEventPath>)path;
- (BOOL)synthesizeWithError:(NSError *_Nullable *_Nullable)error;
@end

/// How long after its last waypoint a finger lifts, so the move and the lift
/// are two distinct events in the stream.
static const NSTimeInterval kLiftDelay = 0.01;

@implementation ArgentTouchSynthesizer

+ (NSString *_Nullable)unavailabilityReason {
  Class pathClass = NSClassFromString(@"XCPointerEventPath");
  Class recordClass = NSClassFromString(@"XCSynthesizedEventRecord");

  if (pathClass == Nil || recordClass == Nil) {
    return @"this Xcode's XCTest has no XCPointerEventPath/XCSynthesizedEventRecord";
  }

  SEL pathSelectors[] = {
      @selector(initForTouchAtPoint:offset:),
      @selector(moveToPoint:atOffset:),
      @selector(liftUpAtOffset:),
  };
  for (size_t i = 0; i < sizeof(pathSelectors) / sizeof(SEL); i++) {
    if (![pathClass instancesRespondToSelector:pathSelectors[i]]) {
      return [NSString stringWithFormat:@"XCPointerEventPath no longer responds to %@",
                                        NSStringFromSelector(pathSelectors[i])];
    }
  }

  SEL recordSelectors[] = {
      @selector(initWithName:interfaceOrientation:),
      @selector(addPointerEventPath:),
      @selector(synthesizeWithError:),
  };
  for (size_t i = 0; i < sizeof(recordSelectors) / sizeof(SEL); i++) {
    if (![recordClass instancesRespondToSelector:recordSelectors[i]]) {
      return [NSString stringWithFormat:@"XCSynthesizedEventRecord no longer responds to %@",
                                        NSStringFromSelector(recordSelectors[i])];
    }
  }

  return nil;
}

+ (NSString *_Nullable)synthesizeFingers:
            (NSArray<NSArray<NSArray<NSNumber *> *> *> *)fingers
                      interfaceOrientation:(UIInterfaceOrientation)orientation {
  NSString *unavailable = [self unavailabilityReason];
  if (unavailable != nil) {
    return unavailable;
  }

  @try {
    id<ArgentSynthesizedEventRecord> record =
        [[NSClassFromString(@"XCSynthesizedEventRecord") alloc]
                 initWithName:@"argent-touch-paths"
         interfaceOrientation:orientation];

    for (NSArray<NSArray<NSNumber *> *> *waypoints in fingers) {
      NSArray<NSNumber *> *first = waypoints.firstObject;
      id<ArgentPointerEventPath> path = [[NSClassFromString(@"XCPointerEventPath") alloc]
          initForTouchAtPoint:CGPointMake(first[0].doubleValue, first[1].doubleValue)
                       offset:first[2].doubleValue];

      for (NSUInteger i = 1; i < waypoints.count; i++) {
        NSArray<NSNumber *> *waypoint = waypoints[i];
        [path moveToPoint:CGPointMake(waypoint[0].doubleValue, waypoint[1].doubleValue)
                 atOffset:waypoint[2].doubleValue];
      }

      [path liftUpAtOffset:waypoints.lastObject[2].doubleValue + kLiftDelay];
      [record addPointerEventPath:path];
    }

    NSError *error = nil;
    if (![record synthesizeWithError:&error]) {
      return [NSString stringWithFormat:@"XCTest refused the touch events: %@",
                                        error.localizedDescription ?: @"no error given"];
    }

    return nil;
  } @catch (NSException *exception) {
    return [NSString stringWithFormat:@"%@: %@", exception.name ?: @"NSException",
                                      exception.reason ?: @"unhandled Objective-C exception"];
  }
}

@end
