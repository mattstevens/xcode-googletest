#include "Counter.h"

Counter::Counter() :
    count_(0) {}

int Counter::Increment() {
    return ++count_;
}
