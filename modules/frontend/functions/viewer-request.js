// Combined CloudFront viewer-request function.
//
// Responsibilities (executed in order):
//   1. Bot interceptor: redirect social-media / search-engine crawlers
//      hitting /worlds/* to the API's /meta endpoint so they receive
//      server-rendered Open Graph metadata.
//   2. Directory-index rewrite: rewrite `/foo/` and `/foo` to
//      `/foo/index.html` so S3 serves prerendered HTML. This makes the
//      prerendered routes (e.g. /about/, /faq/, /ai-bedtime-stories/)
//      fetchable as full HTML by non-JS agents (ChatGPT, Claude,
//      Perplexity, etc.). SPA-only routes still fall back to /200.html
//      via the existing CloudFront custom_error_response rules.
//
// CloudFront only allows a single viewer-request function per cache
// behavior, so these two concerns live in one function.
//
// Templated by Terraform via `templatefile()`; $${domain_name} is the
// frontend domain (e.g. dev.cosmonaut-ai.com, cosmonaut-ai.com).
function handler(event) {
  var request = event.request;
  var headers = request.headers;
  var uri = request.uri;

  // 1. Bot interception for /worlds/ routes.
  if (uri.indexOf('/worlds/') === 0) {
    var userAgent = headers['user-agent']
      ? headers['user-agent'].value.toLowerCase()
      : '';
    var isBot =
      /bot|facebookexternalhit|twitter|discord|telegram|linkedin|slack|whatsapp|applebot|google|signal/i.test(
        userAgent,
      );

    if (isBot) {
      return {
        statusCode: 302,
        statusDescription: 'Found',
        headers: {
          location: { value: 'https://api.${domain_name}/meta' + uri },
          'cache-control': { value: 'no-cache, no-store, must-revalidate' },
        },
      };
    }
  }

  // 2. Directory-index rewrite.
  //    - Has an extension (file request): pass through unchanged.
  //    - Trailing slash: append index.html.
  //    - Otherwise (no extension, no slash): append /index.html.
  if (/\.[a-zA-Z0-9]+$/.test(uri)) {
    return request;
  }
  if (uri.endsWith('/')) {
    request.uri = uri + 'index.html';
  } else {
    request.uri = uri + '/index.html';
  }
  return request;
}
