#import <SenTestingKit/SenTestingKit.h>
#import <gtest/gtest.h>
#import "GoogleTestStub.h"

using testing::TestCase;
using testing::TestInfo;
using testing::TestResult;
using testing::TestPartResult;

class SenTestPrinter : public testing::EmptyTestEventListener {
public:
    SenTestPrinter(SenTestSuiteRun *run) :
        enclosingRun(run),
        testSuiteRun(nil),
        testRun(nil) {}

    void OnTestCaseStart(const TestCase& test_case) {
        NSString *name = [NSString stringWithUTF8String:test_case.name()];
        SenTest *testSuite = [GoogleTestStub testSuiteStubWithName:name testCaseCount:(unsigned int)test_case.test_to_run_count()];
        testSuiteRun = [[SenTestSuiteRun alloc] initWithTest:testSuite];
        [testSuiteRun start];
    }

    void OnTestStart(const TestInfo& test_info) {
        NSString *suite = [[testSuiteRun test] name];
        NSString *name = [NSString stringWithUTF8String:test_info.name()];
        testRun = [[SenTestCaseRun alloc] initWithTest:[GoogleTestStub testCaseStubWithName:name suite:suite]];
        [testRun start];
    }

    void OnTestPartResult(const TestPartResult& test_part_result) {
        if (test_part_result.passed())
            return;

        NSString *path = [[NSString stringWithUTF8String:test_part_result.file_name()] stringByStandardizingPath];
        NSString *description = [NSString stringWithUTF8String:test_part_result.message()];
        NSException *exception = [NSException failureInFile:path atLine:test_part_result.line_number() withDescription:description];
        [testRun addException:exception];
    }

    void OnTestEnd(const TestInfo& test_info) {
        [testSuiteRun addTestRun:testRun];
        [testRun stop];
        testRun = nil;
    }

    void OnTestCaseEnd(const TestCase& test_case) {
        [enclosingRun addTestRun:testSuiteRun];
        [testSuiteRun stop];
        testSuiteRun = nil;
    }

private:
    SenTestSuiteRun *enclosingRun;
    SenTestSuiteRun *testSuiteRun;
    SenTestCaseRun *testRun;
};

@interface GoogleTests : SenTestCase
@end

@implementation GoogleTests

// OCUnit loads tests by looking for all classes derived from SenTestCase and
// calling defaultTestSuite on them. Normally this method returns a
// SenTestSuite containing a SenTestCase for each method of the receiver whose
// name begins with "test". Instead this class acts as its own test suite.

+ (id)defaultTestSuite {
    return [[self alloc] init];
}

- (Class)testRunClass {
    return [SenTestSuiteRun class];
}

- (NSString *)name {
    return NSStringFromClass([self class]);
}

- (unsigned int)testCaseCount {
    return (unsigned int)testing::UnitTest::GetInstance()->test_to_run_count();
}

- (void)performTest:(SenTestRun *)testRun {
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];

    int i = 0;
    int argc = (int)[arguments count];
    const char **argv = (const char **)calloc((unsigned int)argc + 1, sizeof(const char *));
    for (NSString *arg in arguments) {
        argv[i++] = [arg UTF8String];
    }

    testing::InitGoogleTest(&argc, (char **)argv);
    testing::TestEventListeners& listeners = testing::UnitTest::GetInstance()->listeners();
    delete listeners.Release(listeners.default_result_printer());
    listeners.Append(new SenTestPrinter((SenTestSuiteRun *)testRun));
    free(argv);

    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wunused-result"
    RUN_ALL_TESTS();
    #pragma clang diagnostic pop
}

@end
