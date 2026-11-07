Throwaway ECDSA P-256 certificate and key for tests only (`openssl req -x509`, valid 100 years, for
`localhost` and `127.0.0.1`). It protects nothing: it is public in this repository and the app never
uses it. Tests serve it with `HttpServer.bindSecure` to exercise pinning.

The pin tests use a fake hasher, so they do not depend on this certificate's real fingerprint.
