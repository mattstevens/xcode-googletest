# Google Test Integration With Xcode

This project demonstrates two ways to integrate the Google Test C++ unit testing library with Xcode:

## Standalone Executable

This is the more typical setup seen when using Google Test, but does not provide integration with Xcode's unit testing UI. It is illustrated by the "standalone" target. The Google Test library can either be built separately as a framework or as a static library as shown in this project. The framework or static library is linked to a command line tool that includes all unit tests, and when this tool is run typical Google Test output is generated.

To run tests as part of an Xcode build and get inline reporting of failures add a run script phase that executes the tool from it's built location. The standalone target demonstrates this, when built the tool will execute as part of the build and any test failures will be highlighted inline in code and appear in the issue navigator.

To debug a failing test in a configuration like this you can temporarily disable execution of the test runner as part of the build by expanding the script phase and enabling the "Run script only when installing" option.

## Unit Test Bundle

The "TestBundle" and "TestBundle-iOS" targets define Xcode unit test bundles that can run both Google Test and Objective-C test cases. They allow for simple execution of C++ tests in iOS apps and running both C++ and Objective-C tests through a single test runner. They also integrate with Xcode's unit test running and reporting capabilties.

As with the standalone tool, the test bundle links the Google Test library and includes all unit tests. To run it, select the "demo" or "demo-ios" static library as the active target and execute its test action. Test results will appear in the build log and test navigator, and tests can be debugged as usual. Tests can also be run individually by right-clicking on the test or test case in the test navigator and selecting the "Test" action. Once run with this filter the "Test Again" command will also work to run just the selected test(s).

Because Xcode displays only a single line of failed test output in its interface, you may need to view the build log and expand the output for the failed test case to see all relevant Google Test output for test failures.

Note that test bundles can be passed distinct command line arguments so Google Test can be controlled via the usual --gtest arguments. To do this edit the scheme for the "demo" target, select the Test action, then the Arguments tab. Here you can uncheck the "Use the Run action's arguments and environment variables" option and specify the --gtest options to control Google Test's behavior.
