#!/usr/bin/env bash
set -euo pipefail

# Temporary compatibility patch:
# patrol 4.6.1 embeds Telegraph Swift sources that fail to compile with the
# iOS 26.2 simulator SDK used by local runtime QA. Keep this patch scoped to
# the cached Patrol package and run it before Patrol builds.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$MOBILE_DIR/pubspec.lock"
PUB_CACHE_ROOT="${PUB_CACHE:-$HOME/.pub-cache}"
SEARCH_ROOT="$PUB_CACHE_ROOT/hosted/pub.dev"

if [[ ! -d "$SEARCH_ROOT" ]]; then
  echo "patrol xcode26.2 patch: pub cache not found at $SEARCH_ROOT (skip)"
  exit 0
fi

patrol_version=""
if [[ -f "$LOCK_FILE" ]]; then
  patrol_version="$(
    awk '
      $1=="patrol:" { in_pkg=1; next }
      in_pkg && $1=="version:" { gsub(/"/, "", $2); print $2; exit }
      in_pkg && /^[^[:space:]]/ { in_pkg=0 }
    ' "$LOCK_FILE"
  )"
fi

patrol_dirs=()
if [[ -n "$patrol_version" ]]; then
  candidate="$SEARCH_ROOT/patrol-$patrol_version/darwin/Classes/Telegraph"
  if [[ -d "$candidate" ]]; then
    patrol_dirs+=("$candidate")
  fi
fi

if [[ ${#patrol_dirs[@]} -eq 0 ]]; then
  while IFS= read -r dir; do
    patrol_dirs+=("$dir")
  done < <(find "$SEARCH_ROOT" -type d -path "*/patrol-*/darwin/Classes/Telegraph")
fi

if [[ ${#patrol_dirs[@]} -eq 0 ]]; then
  echo "patrol xcode26.2 patch: no Patrol Telegraph sources found (skip)"
  exit 0
fi

patched_count=0
for dir in "${patrol_dirs[@]}"; do
  tls_file="$dir/Security/TLSPolicy.swift"
  http_route_file="$dir/Protocols/HTTP/Routing/HTTPRoute.swift"
  localization_file="$(dirname "$dir")/AutomatorServer/Localization.swift"
  ios_automator_file="$(dirname "$dir")/AutomatorServer/Automator/IOSAutomator.swift"
  patrol_client_file="$(dirname "$dir")/AutomatorServer/PatrolAppServiceClient.swift"
  regex_file="$dir/Helpers/Extensions/NSRegularExpression+Ext.swift"
  url_file="$dir/Helpers/Extensions/URL+Ext.swift"

  if [[ -f "$tls_file" ]]; then
    perl -0pi -e 's/#if swift\(>=6\.0\)\n    return URLCredential\(\)\n#else\n    return URLCredential\(trust: trust\)\n#endif/return URLCredential()/g; s/return URLCredential\(trust: trust\)/return URLCredential()/g' "$tls_file"
    patched_count=$((patched_count + 1))
    echo "patrol xcode26.2 patch: normalized $tls_file"
  else
    echo "patrol xcode26.2 patch: already compatible $tls_file"
  fi

  if [[ -f "$url_file" ]]; then
    perl -0pi -e 's/return (?:Foundation\.)?FileManager\.default\.mimeType\(pathExtension: pathExtension\)/return "application\/octet-stream"/g' "$url_file"
    patched_count=$((patched_count + 1))
    echo "patrol xcode26.2 patch: normalized $url_file"
  else
    echo "patrol xcode26.2 patch: already compatible $url_file"
  fi

  if [[ -f "$localization_file" ]]; then
    perl -0pi -e 's/guard let dictionary = (?:Foundation\.)*NSDictionary\(contentsOfFile: filePath\) as\? \[String: String\] else \{/guard\n      let data = try? Foundation.Data(contentsOf: Foundation.URL(fileURLWithPath: filePath)),\n      let dictionary = try? Foundation.PropertyListSerialization.propertyList(\n        from: data, options: [], format: nil) as? [String: String]\n    else {/g' "$localization_file"
    patched_count=$((patched_count + 1))
    echo "patrol xcode26.2 patch: normalized $localization_file"
  else
    echo "patrol xcode26.2 patch: already compatible $localization_file"
  fi

  if [[ -f "$regex_file" ]]; then
    cat > "$regex_file" <<'SWIFT'
//
//  NSRegularExpression+Ext.swift
//  Telegraph
//
//  Created by Yvo van Beek on 2/5/17.
//  Copyright © 2017 Building42. All rights reserved.
//

import Foundation

public final class Regex {
  public struct MatchingOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let caseInsensitive = MatchingOptions(rawValue: 1 << 0)
  }

  private let pattern: String
  private let baseOptions: MatchingOptions

  public init(pattern: String, options: MatchingOptions = []) throws {
    self.pattern = pattern
    self.baseOptions = options
  }

  func matches(value: String) -> Bool {
    return !matchAll(in: value).isEmpty
  }

  func matchAll(in value: String, options: MatchingOptions = []) -> [RegexMatch] {
    var compareOptions: String.CompareOptions = [.regularExpression]
    if baseOptions.contains(.caseInsensitive) || options.contains(.caseInsensitive) {
      compareOptions.insert(.caseInsensitive)
    }

    guard value.range(of: pattern, options: compareOptions) != nil else { return [] }
    return [RegexMatch(value: value, groupValues: [])]
  }

  func telegraphStringByReplacingMatches(
    in value: String, withPattern replacement: String, options: MatchingOptions = []
  ) -> String {
    var compareOptions: String.CompareOptions = [.regularExpression]
    if baseOptions.contains(.caseInsensitive) || options.contains(.caseInsensitive) {
      compareOptions.insert(.caseInsensitive)
    }

    return value.replacingOccurrences(of: pattern, with: replacement, options: compareOptions)
  }
}

struct RegexMatch {
  let value: String
  let groupValues: [String]
}
SWIFT
    patched_count=$((patched_count + 1))
    echo "patrol xcode26.2 patch: replaced $regex_file"
  else
    echo "patrol xcode26.2 patch: already compatible $regex_file"
  fi

  if [[ -f "$http_route_file" ]] && grep -q '\.stringByReplacingMatches(' "$http_route_file"; then
    perl -0pi -e 's/\.stringByReplacingMatches\(/.telegraphStringByReplacingMatches(/g' "$http_route_file"
    patched_count=$((patched_count + 1))
    echo "patrol xcode26.2 patch: updated $http_route_file"
  else
    echo "patrol xcode26.2 patch: already compatible $http_route_file"
  fi

  if [[ -f "$patrol_client_file" ]]; then
    if ! grep -q '^import Foundation$' "$patrol_client_file"; then
      perl -0pi -e 's|(//  source: schema\.dart\n//\n)|$1\nimport Foundation\n|g' "$patrol_client_file"
    fi
    if ! grep -q '^import CoreFoundation$' "$patrol_client_file"; then
      perl -0pi -e 's|^import Foundation$|import Foundation\nimport CoreFoundation|gm' "$patrol_client_file"
    fi
    python3 - "$patrol_client_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
start = text.index("  private func performRequest(\n")
end = text.rindex("\n}")
replacement = '''  private func performRequest(
    requestName: String, body: Data? = nil, completion: @escaping (Result<Data, Error>) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      var readStreamRef: Unmanaged<CFReadStream>?
      var writeStreamRef: Unmanaged<CFWriteStream>?
      CFStreamCreatePairWithSocketToHost(
        nil,
        self.address as CFString,
        UInt32(self.port),
        &readStreamRef,
        &writeStreamRef
      )

      guard
        let inputRef = readStreamRef?.takeRetainedValue(),
        let outputRef = writeStreamRef?.takeRetainedValue()
      else {
        completion(.failure(PatrolError.internal("Failed to open Patrol app service socket")))
        return
      }

      let inputStream = inputRef as InputStream
      let outputStream = outputRef as OutputStream
      inputStream.open()
      outputStream.open()
      defer {
        inputStream.close()
        outputStream.close()
      }

      let requestBody = body ?? Data()
      let headers =
        "POST /\\(requestName) HTTP/1.1\\r\\n" +
        "Host: \\(self.address):\\(self.port)\\r\\n" +
        "Content-Type: application/json\\r\\n" +
        "Content-Length: \\(requestBody.count)\\r\\n" +
        "Connection: close\\r\\n\\r\\n"
      var requestData = Data(headers.utf8)
      requestData.append(requestBody)

      var writeError: Error?
      requestData.withUnsafeBytes { rawBuffer in
        guard let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
          writeError = PatrolError.internal("Failed to prepare Patrol app service request")
          return
        }

        var offset = 0
        while offset < requestData.count {
          let written = outputStream.write(
            base.advanced(by: offset),
            maxLength: requestData.count - offset
          )
          if written <= 0 {
            writeError = PatrolError.internal("Failed to write Patrol app service request")
            return
          }
          offset += written
        }
      }

      if let writeError = writeError {
        completion(.failure(writeError))
        return
      }

      var responseData = Data()
      var buffer = [UInt8](repeating: 0, count: 4096)
      let deadline = Date().addingTimeInterval(self.timeout)
      while Date() < deadline {
        let count = inputStream.read(&buffer, maxLength: buffer.count)
        if count > 0 {
          responseData.append(contentsOf: buffer.prefix(count))
        } else if count == 0 {
          break
        } else {
          completion(
            .failure(PatrolError.internal("Failed to read Patrol app service response"))
          )
          return
        }
      }

      guard !responseData.isEmpty else {
        completion(.failure(PatrolError.internal("Empty Patrol app service response")))
        return
      }

      let separator = Data([13, 10, 13, 10])
      guard let separatorRange = responseData.range(of: separator) else {
        completion(.failure(PatrolError.internal("Invalid Patrol app service HTTP response")))
        return
      }

      let headerData = responseData[..<separatorRange.lowerBound]
      let bodyData = responseData[separatorRange.upperBound...]
      guard
        let headerText = String(data: Data(headerData), encoding: .utf8),
        let statusLine = headerText.components(separatedBy: "\\r\\n").first
      else {
        completion(.failure(PatrolError.internal("Invalid Patrol app service HTTP status")))
        return
      }

      let statusParts = statusLine.split(separator: " ")
      guard statusParts.count > 1, let statusCode = Int(statusParts[1]) else {
        completion(.failure(PatrolError.internal("Invalid Patrol app service HTTP status")))
        return
      }

      if statusCode == 200 {
        completion(.success(Data(bodyData)))
      } else {
        let message =
          "Invalid response: \\(headerText) \\(String(data: Data(bodyData), encoding: .utf8) ?? "")"
        completion(.failure(PatrolError.internal(message)))
      }
    }
  }
'''
path.write_text(text[:start] + replacement + text[end:])
PY
    patched_count=$((patched_count + 1))
    echo "patrol xcode26.2 patch: normalized $patrol_client_file"
  else
    echo "patrol xcode26.2 patch: already compatible $patrol_client_file"
  fi

  if [[ -f "$ios_automator_file" ]] && grep -q 'UIDevice.current.systemVersion' "$ios_automator_file"; then
    perl -0pi -e 's/return UIDevice\.current\.systemVersion/let version = ProcessInfo.processInfo.operatingSystemVersion\n      return "\\(version.majorVersion).\\(version.minorVersion).\\(version.patchVersion)"/g' "$ios_automator_file"
    perl -0pi -e 's/let floatVersion = \(UIDevice\.current\.systemVersion as NSString\)\.floatValue\n      return floatVersion < 14/return ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 14/g' "$ios_automator_file"
    patched_count=$((patched_count + 1))
    echo "patrol xcode26.2 patch: updated $ios_automator_file"
  else
    echo "patrol xcode26.2 patch: already compatible $ios_automator_file"
  fi

  if [[ -f "$tls_file" ]] && grep -q 'URLCredential(trust:' "$tls_file"; then
    echo "patrol xcode26.2 patch: failed to patch $tls_file" >&2
    exit 1
  fi
  if [[ -f "$url_file" ]] && ! grep -q 'return "application/octet-stream"' "$url_file"; then
    echo "patrol xcode26.2 patch: failed to patch $url_file" >&2
    exit 1
  fi
  if [[ -f "$localization_file" ]] && ! grep -q 'Foundation.PropertyListSerialization.propertyList' "$localization_file"; then
    echo "patrol xcode26.2 patch: failed to patch $localization_file" >&2
    exit 1
  fi
  if [[ -f "$regex_file" ]] && ! grep -q 'public final class Regex' "$regex_file"; then
    echo "patrol xcode26.2 patch: failed to patch $regex_file" >&2
    exit 1
  fi
  if [[ -f "$http_route_file" ]] && ! grep -q 'telegraphStringByReplacingMatches' "$http_route_file"; then
    echo "patrol xcode26.2 patch: failed to patch $http_route_file" >&2
    exit 1
  fi
  if [[ -f "$patrol_client_file" ]] && ! grep -q '^import Foundation$' "$patrol_client_file"; then
    echo "patrol xcode26.2 patch: failed to add Foundation import to $patrol_client_file" >&2
    exit 1
  fi
  if [[ -f "$patrol_client_file" ]] && ! grep -q '^import CoreFoundation$' "$patrol_client_file"; then
    echo "patrol xcode26.2 patch: failed to add CoreFoundation import to $patrol_client_file" >&2
    exit 1
  fi
  if [[ -f "$patrol_client_file" ]] && ! grep -q 'CFStreamCreatePairWithSocketToHost' "$patrol_client_file"; then
    echo "patrol xcode26.2 patch: failed to patch $patrol_client_file" >&2
    exit 1
  fi
  if [[ -f "$patrol_client_file" ]] && grep -q 'timeoutIntervalForRequest\|timeoutIntervalForResource' "$patrol_client_file"; then
    echo "patrol xcode26.2 patch: failed to remove unavailable URLSessionConfiguration timeouts from $patrol_client_file" >&2
    exit 1
  fi
  if [[ -f "$patrol_client_file" ]] && grep -q 'completionHandler: {' "$patrol_client_file"; then
    echo "patrol xcode26.2 patch: failed to replace URLSession completion handler in $patrol_client_file" >&2
    exit 1
  fi
  if [[ -f "$patrol_client_file" ]] && grep -q 'URLSession' "$patrol_client_file"; then
    echo "patrol xcode26.2 patch: failed to remove URLSession from $patrol_client_file" >&2
    exit 1
  fi
  if [[ -f "$ios_automator_file" ]] && grep -q 'UIDevice.current.systemVersion' "$ios_automator_file"; then
    echo "patrol xcode26.2 patch: failed to patch $ios_automator_file" >&2
    exit 1
  fi
done

echo "patrol xcode26.2 patch: done ($patched_count edit(s))"
