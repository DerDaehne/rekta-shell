import QtQuick
import QtTest
import Start

TestCase {
    name: "Calc"

    function test_points_go_before_lines_and_brackets_before_both() {
        compare(Calc.result("2+3*4", "."), 14);
        compare(Calc.result("(2+3)*4", "."), 20);
        compare(Calc.result("2 * (3 + (4 - 1)) / 3", "."), 4);
        compare(Calc.result("10-4-3", "."), 3, "from the left");
        compare(Calc.result("8/4/2", "."), 1, "from the left");
    }

    function test_a_power_binds_to_the_right_and_tighter_than_a_sign() {
        compare(Calc.result("2^3^2", "."), 512);
        compare(Calc.result("-2^2", "."), -4);
        compare(Calc.result("2^-1", "."), 0.5);
        compare(Calc.result("2*-3", "."), -6);
    }

    function test_a_percent_sign_takes_a_hundredth() {
        compare(Calc.result("10%", "."), 0.1);
        compare(Calc.result("100*10%", "."), 10);
        compare(Calc.result("200/50%", "."), 400);
    }

    function test_after_a_plus_or_minus_a_percentage_is_that_share_of_the_value_before_it() {
        compare(Calc.result("100+10%", "."), 110);
        compare(Calc.result("100-10%", "."), 90);
        compare(Calc.result("100+10%+5", "."), 115, "the share of the value before, then on");
        compare(Calc.result("2*50+10%", "."), 110, "of the whole value before");
        compare(Calc.result("100+100+10%", "."), 220, "of all that comes before");
        compare(Calc.result("100+10%*2", "."), 100.2, "a side that goes on after the percent sign is no share");
    }

    function test_the_written_signs_for_times_divided_and_minus_count_as_the_typed_ones() {
        compare(Calc.result("6×7", "."), 42);
        compare(Calc.result("8÷2", "."), 4);
        compare(Calc.result("5−2", "."), 3);
    }

    function test_numbers_take_the_locale_s_decimal_separator_only() {
        compare(Calc.result("2,5*2", ","), 5);
        compare(Calc.result(",5+1", ","), 1.5);
        compare(Calc.result("2.5*2", ","), null, "a point is no separator where the comma is");
        compare(Calc.result("2.5*2", "."), 5);
    }

    function test_a_division_by_zero_or_a_result_beyond_any_number_is_no_calculation() {
        compare(Calc.result("1/0", "."), null);
        compare(Calc.result("1/(2-2)", "."), null);
        compare(Calc.result("(1/0)^0", "."), null, "not even where the rest would make a number of it");
        compare(Calc.result("0^-1", "."), null);
        compare(Calc.result("(-8)^0.5", "."), null);
    }

    function test_a_number_alone_a_bracket_left_open_or_any_other_text_is_no_calculation() {
        for (const text of ["", "2", "-2", "(5)", "(1+2", "1+2)", "()", "2+", "2 3", "2(3)", "2+x", "1e3+1", "Math.PI*2"])
            compare(Calc.result(text, "."), null, `"${text}"`);
    }

    function test_a_result_shows_twelve_significant_digits_with_the_locale_s_separator() {
        compare(Calc.shown(Calc.result("0.1+0.2", "."), "."), "0.3");
        compare(Calc.shown(Calc.result("1/3", "."), "."), "0.333333333333");
        compare(Calc.shown(Calc.result("1/4", ","), ","), "0,25");
        compare(Calc.shown(Calc.result("2-5", "."), "."), "-3");
    }

    function test_a_calculation_starts_with_a_digit_a_bracket_a_minus_or_the_separator() {
        for (const character of ["0", "7", "(", "-", "−"])
            verify(Calc.canStart(character, "."), character);
        verify(Calc.canStart(",", ","));
        for (const character of ["+", "*", ")", ",", "a", " "])
            verify(!Calc.canStart(character, "."), character);
    }
}
