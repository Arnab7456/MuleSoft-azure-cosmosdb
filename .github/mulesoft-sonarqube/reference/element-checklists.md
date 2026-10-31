# Per-element checklists

Use these when walking a Mule file element by element. Each item is tagged:

- **[SONAR]**: enforced by the plugin ruleset (see `rules-catalog.md`). Must be fixed to pass.
- **[BEST PRACTICE]**: not enforced by the plugin, but a senior reviewer would flag it, and it often prevents other Sonar generic findings (hard-coded credentials, etc.). Label it as optional when reporting.

## Contents

1. Flow
2. Sub-flow
3. Flow-ref
4. HTTP Listener
5. HTTP Requester
6. Transform / DataWeave
7. Logger
8. Error handling
9. Global config and properties
10. File and project structure

---

## 1. Flow

- [SONAR] Name matches `^[a-z:\\{}]+(-[a-z]+)*$`: lowercase words joined by hyphens, no digits/underscores/uppercase.
- [SONAR] Fewer than 10 flows in the file.
- [BEST PRACTICE] One flow = one responsibility. If a flow exceeds ~10-15 processors, extract sub-flows or private flows.
- [BEST PRACTICE] Every flow has a `doc:name` that describes it in business terms.
- [BEST PRACTICE] Source flows (listener/scheduler) are thin: validate, call a private flow, build the response.
- [BEST PRACTICE] Name pattern: `<verb>-<resource>-flow` for private flows, APIKit generates the interface flows.

## 2. Sub-flow

- [SONAR] Name matches the same regex as flows.
- [SONAR] Fewer than 5 sub-flows in the file; move shared ones to `common-subflows.xml`.
- [BEST PRACTICE] Sub-flows have no error handler of their own (they inherit the caller's). If you need local error handling, use a private flow instead.
- [BEST PRACTICE] Name pattern: `<verb>-<noun>-subflow`.

## 3. Flow-ref

No plugin rule, but renames break these silently, so check them whenever a flow or sub-flow is renamed.

- [BEST PRACTICE] `name` points to an existing flow/sub-flow (search the whole project, including other XML files and MUnit).
- [BEST PRACTICE] Use static names, not `#[...]` expressions, so tooling and Sonar XPath can resolve them. If dynamic dispatch is truly needed, keep a whitelist.
- [BEST PRACTICE] Avoid circular flow-refs.
- [BEST PRACTICE] Same naming regex for the referenced name, so rename both sides together.

```xml
<flow-ref name="build-error-response-subflow" doc:name="Build error response"/>
```

## 4. HTTP Listener

- [SONAR] `listener-connection protocol="HTTPS"` with a `tlsContext` (CFG-7, DOM-19).
- [SONAR] `port="${https.port}"` (CFG-8).
- [SONAR] Exactly one `api-gateway:autodiscovery` per app with `apiId="${api.id}"` (CFG-3, CFG-9).
- [BEST PRACTICE] `host="0.0.0.0"` is expected for containers; make it a property if it varies by environment.
- [BEST PRACTICE] Listener path via property or the APIKit base path (`/api/*`).
- [BEST PRACTICE] Set `<http:response statusCode="#[vars.httpStatus default 200]">` and an error response so errors do not return 200.
- [BEST PRACTICE] Add `allowedMethods` where only specific verbs are expected.

```xml
<http:listener-config name="https-listener-config" doc:name="HTTP Listener config">
  <http:listener-connection host="0.0.0.0" port="${https.port}" protocol="HTTPS" tlsContext="tls-server-context"/>
</http:listener-config>
```

## 5. HTTP Requester

Plugin rules DOM-11 to DOM-21 target `mule-domain` files. In an application, treat them as standards to match.

- [SONAR/domain] `responseTimeout="${...}"` on the config (DOM-21, CRITICAL).
- [SONAR/domain] Reconnection `count` and `frequency` as placeholders (DOM-11/12).
- [SONAR/domain] `tlsContext` on HTTPS connections (DOM-15), no `insecure` trust store (DOM-18).
- [SONAR/domain] No `#[...]` in config-level default headers or query params (DOM-20); put dynamic values on the `http:request` operation.
- [BEST PRACTICE] Host, port, basePath, protocol all as `${...}`.
- [BEST PRACTICE] `path`/`method` static in the operation; build query via `<http:query-params>`; avoid string concatenation of URLs.
- [BEST PRACTICE] Never hardcode `Authorization` values, use an OAuth/Basic auth config with placeholders.
- [BEST PRACTICE] Explicit `<http:response-validator>` or error mapping for `HTTP:*` errors.

```xml
<http:request config-ref="customer-request-config" method="GET" path="/customers" doc:name="Get customers">
  <http:headers>#[{ 'x-correlation-id': correlationId }]</http:headers>
</http:request>
```

## 6. Transform / DataWeave

- [SONAR] `ee:set-payload` has `resource="....dwl"` (CFG-5).
- [SONAR] `ee:set-variable` has `resource="....dwl"` (CFG-6). Real Mule 4 variables sit under `ee:variables`; externalize them too.
- [BEST PRACTICE] DWL files live under `src/main/resources/dwl/`, named like flows (`map-customers.dwl`).
- [BEST PRACTICE] Always declare `%dw 2.0` and `output ...`.
- [BEST PRACTICE] Use `default` for nullable fields; avoid magic numbers; extract shared functions into `src/main/resources/modules/*.dwl` and `import`.
- [BEST PRACTICE] Do not inline credentials, URLs or environment-specific values in DWL; use `p('key')`.
- [BEST PRACTICE] Keep each transformation under ~50 lines; split otherwise.

```xml
<ee:transform doc:name="Map customers">
  <ee:message><ee:set-payload resource="dwl/map-customers.dwl"/></ee:message>
  <ee:variables><ee:set-variable variableName="httpStatus" resource="dwl/http-status-ok.dwl"/></ee:variables>
</ee:transform>
```
For a trivial constant like a status code, an external DWL file is still what the rule asks for. Keep it one line plus the header.

## 7. Logger

- [SONAR] Message never contains `${mule.key}` (FLW-6).
- [BEST PRACTICE] Never log full `payload`, headers, tokens, passwords, PII. Log ids and counts.
- [BEST PRACTICE] Set `category` (e.g. `com.company.customer-sapi.get-customers`) and an appropriate `level` (DEBUG for payload details, INFO for lifecycle, ERROR in error handlers).
- [BEST PRACTICE] Include correlation: `"[#[correlationId]] Fetching customer #[vars.customerId]"`.
- [BEST PRACTICE] No empty messages, no `System.out` in scripts/Java.
- [BEST PRACTICE] Keep expression cost low in loggers at INFO; wrap heavy ones at DEBUG.

```xml
<logger level="INFO" category="com.company.customer-sapi" message="#['[$(correlationId)] get-customers started']" doc:name="Log start"/>
```

## 8. Error handling

- [SONAR] `on-error-propagate` for `APIKIT:BAD_REQUEST`, `APIKIT:METHOD_NOT_ALLOWED`, `APIKIT:NOT_FOUND`, each setting the HTTP status (CFG-4, APP-2).
- [SONAR] `apikit:config` present (APP-1).
- [BEST PRACTICE] Also handle `APIKIT:NOT_ACCEPTABLE` (406), `APIKIT:UNSUPPORTED_MEDIA_TYPE` (415), `APIKIT:NOT_IMPLEMENTED` (501), and an `ANY` fallback returning 500 with a safe message.
- [BEST PRACTICE] One global error handler in `error-handler.xml`, referenced via `<error-handler ref="..."/>`; no stack traces in responses.
- [BEST PRACTICE] Use `on-error-continue` only when you really return a successful flow result.

## 9. Global config and properties

- [SONAR] At least one `configuration-properties` or `secure-properties:config` (CFG-1).
- [SONAR] `secure-properties:config key="${...}"`, never a literal (CFG-2); AES/CBC for domain (DOM-13).
- [SONAR] MSSQL `host="${...}"` (CFG-10).
- [BEST PRACTICE] Every DB, JMS, Salesforce, SFTP, SMTP connection: host, port, user, password, schema as placeholders; passwords via `${secure::...}`.
- [BEST PRACTICE] Environment files: `config/dev.properties`, `config/test.properties`, `config/prod.properties`, with the same key set in all.
- [BEST PRACTICE] Property keys lowercase-dot: `db.host`, `https.port`, `customer.http.response.timeout`.

## 10. File and project structure

- [SONAR] Project name suffix `-api|-sapi|-xapi|-papi|-impl|-mcp|-agent` (PRJ-1).
- [SONAR] Max 9 flows and 4 sub-flows per file.
- [BEST PRACTICE] Suggested layout under `src/main/mule/`: `interface.xml`, `implementation.xml`, `global.xml`, `error-handler.xml`, `common-subflows.xml`.
- [BEST PRACTICE] `src/main/resources/`: `dwl/`, `config/`, `api/` (spec), `log4j2.xml`.
- [BEST PRACTICE] MUnit tests mirror flow names; rerun them after any rename.