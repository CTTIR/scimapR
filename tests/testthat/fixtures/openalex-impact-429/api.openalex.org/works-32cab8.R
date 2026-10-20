# The daily budget is used up: HTTP 429 with the rate-limit headers.
httr2::response(
  status_code = 429L,
  url = "https://api.openalex.org/works",
  headers = list(
    `Content-Type` = "application/json",
    `Retry-After` = "21600",
    `X-RateLimit-Limit` = "1",
    `X-RateLimit-Remaining-USD` = "0"
  ),
  body = charToRaw("{\"error\": \"Rate limit exceeded\"}")
)
