// Google Test-based unit tests for math_operations::add
#include "gtest/gtest.h"
#include "../math_operations.h"

TEST(AdditionTests, PositiveNumbers) {
    EXPECT_EQ(5, add(2, 3));
}

TEST(AdditionTests, MixedSign) {
    EXPECT_EQ(-1, add(2, -3));
}

TEST(AdditionTests, Zero) {
    EXPECT_EQ(0, add(0, 0));
}

TEST(AdditionTests, LargeValues) {
    EXPECT_EQ(2147483646, add(1073741823, 1073741823));
}

