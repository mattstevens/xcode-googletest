
class Counter {
public:
    Counter();

    int GetCount() { return count_; }
    int Increment();

private:
    int count_;
};