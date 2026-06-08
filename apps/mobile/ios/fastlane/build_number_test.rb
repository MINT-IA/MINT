require "minitest/autorun"
require_relative "build_number"

class MintBuildNumberTest < Minitest::Test
  def test_parses_pubspec_build_number
    content = <<~YAML
      name: mint_mobile
      version: 2.12.4+76
    YAML

    assert_equal 76, MintBuildNumber.parse_pubspec_build_number(content)
  end

  def test_uses_safety_margin_when_pubspec_is_not_greater_than_testflight
    build_number = MintBuildNumber.next_build_number(
      pubspec_build_number: 71,
      latest_testflight_build_number: 71,
      ci_candidate: nil,
    )

    assert_equal 76, build_number
  end

  def test_uses_ci_candidate_when_it_is_higher_than_pubspec_and_testflight_margin
    build_number = MintBuildNumber.next_build_number(
      pubspec_build_number: 76,
      latest_testflight_build_number: 71,
      ci_candidate: 260608190501,
    )

    assert_equal 260608190501, build_number
  end
end
