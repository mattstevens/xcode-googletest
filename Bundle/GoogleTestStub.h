#import <XCTest/XCTest.h>

@interface GoogleTestStub : XCTest

+ (instancetype)testCaseStubWithName:(NSString *)name suite:(NSString *)suiteName;
+ (instancetype)testSuiteStubWithName:(NSString *)name testCaseCount:(NSUInteger)count;

@end
