{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Keep engine fallback lookups on the same origin. MINT bundles every font
    // used by this Latin-script slice and must not leak a visitor IP to a CDN.
    fontFallbackBaseUrl: "font-fallback/",
  },
});
