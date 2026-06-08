module MintBuildNumber
  DEFAULT_SAFETY_MARGIN = 5
  VERSION_PATTERN = /^version:\s*[\d.]+\+(\d+)\s*$/

  def self.parse_pubspec_build_number(pubspec_content)
    match = pubspec_content.match(VERSION_PATTERN)
    raise ArgumentError, "pubspec.yaml: cannot parse 'version: X.Y.Z+N' line" unless match

    match[1].to_i
  end

  def self.ci_timestamp_candidate(now: Time.now.utc)
    now.utc.strftime("%y%m%d%H%M%S").to_i
  end

  def self.next_build_number(
    pubspec_build_number:,
    latest_testflight_build_number:,
    ci_candidate: ci_timestamp_candidate,
    safety_margin: DEFAULT_SAFETY_MARGIN
  )
    candidates = [
      pubspec_build_number.to_i,
      latest_testflight_build_number.to_i + safety_margin.to_i,
    ]
    candidates << ci_candidate.to_i if ci_candidate && ci_candidate.to_i.positive?

    candidates.max
  end
end
