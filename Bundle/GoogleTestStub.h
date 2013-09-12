#import <SenTestingKit/SenTestingKit.h>

@interface GoogleTestStub : SenTest

+ (instancetype)testCaseStubWithName:(NSString *)name suite:(NSString *)suiteName;
+ (instancetype)testSuiteStubWithName:(NSString *)name testCaseCount:(unsigned int)count;

@end
