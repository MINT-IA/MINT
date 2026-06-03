# CJT-018 — Full Path ID Recheck

Date: 2026-06-03  
Simulator: iPhone 17 Pro `B03E429D-0422-4357-B754-536637D979F9`

## Probe

After reinstalling a real build with no temporary CJT-018 route override and no
direct-T6 flag, S005 was rerun with only the T6 coordinate fallback replaced by:

```yaml
- tapOn:
    id: "onboarding-insight-view"
```

## Result

Artifact folder:

`evidence/maestro-ci/cjt-018-full-path-id-recheck-20260603T102238/`

Maestro result:

```text
[Failed] cjt018_s005_full_path_id_recheck (39s)
Element not found: Id matching regex: onboarding-insight-view
1/1 Flow Failed
```

MCP snapshot on T6 after the failure exposed:

```text
e15|tap|button|Voir||
```

There was no `onboarding-insight-view` identifier in the true current build.

## Conclusion

The true current production code does not expose the T6 CTA id. Earlier
bad-frame evidence remains relevant for temporary explicit-semantics probes, but
should not be interpreted as the clean production state.

CJT-018 therefore has two separate runtime facts:

- current code: id is absent, so Maestro cannot use `onboarding-insight-view`;
- explicit semantics wrappers tried so far: id appears, but maps to the bad
  upper frame around `x=67,y=205`.
