//! Proxy-only build. The endpoint is supplied at runtime, never committed.
pub fn valid_host(host: &str) -> bool {
    !host.is_empty() && host.len() <= 253 && host.split('.').all(|label|
        !label.is_empty() && label.len() <= 63 && !label.starts_with('-') && !label.ends_with('-')
        && label.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-'))
}
#[cfg(test)] mod tests {
 use super::*;
 #[test] fn rejects_header_injection_and_authority_tricks() {
  for h in ["", "google.com\r\nX: evil", "google.com:443", "google.com@evil", "a..b", "-bad.com", "a/b"] { assert!(!valid_host(h), "{h:?}"); }
  assert!(valid_host("daily-cloudcode-pa.googleapis.com"));
 }
}
