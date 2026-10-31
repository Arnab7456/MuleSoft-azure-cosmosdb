# Mule SonarQube Rules Catalog (Mule 4)

Source: `rules-4.xml` of the Mule SonarQube plugin (mulesoft-catalyst/mule-sonarqube-plugin). Rule bodies are XPath expressions over the Mule XML. The placeholder test used throughout is:

```
isConfigurable(value)  ==  value matches  ^\$\{.*\}$
```

So `${http.port}` passes; `8081`, `localhost`, `abc${x}` (text before the placeholder) all fail.

Your organization's SonarQube may carry a customized copy of this ruleset. If a finding does not match anything here, ask for the rule text.

## Contents

1. Application rules
2. Project rule
3. Flow rules
4. Configuration rules (1-10 for applications)
5. Domain rules (11-21, only evaluated on `mule-domain` files)
6. Known false positives and caveats

---

## 1. Application rules (scope: whole application)

### APP-1: Application should use APIKit to auto-generate the implementation interface
- Pass: `count(//apikit:config) > 0`
- Severity: MAJOR, code smell
- Fix: generate the flows from the RAML/OAS with APIKit (Anypoint Studio: *Import RAML* / *Scaffold flows from API spec*), which adds `<apikit:config>` and `<apikit:router>`.

```xml
<apikit:config name="api-config" api="resource::...:api:1.0.0:raml:zip:api.raml" outboundHeadersMapName="outboundHeaders" httpStatusVarName="httpStatus"/>
```

### APP-2: Application should have an APIKit global exception strategy
- Pass: an `on-error-propagate` whose `type` starts with `APIKIT`
- Severity: MAJOR, code smell
- Fix: add the APIKit error handler (see CFG-4) in a global/main flow.

---

## 2. Project rule

### PRJ-1: Project name should follow naming convention
- Pass: project name matches `^.*-(api|sapi|xapi|papi|impl|mcp|agent)$`
- Severity: MAJOR, code smell
- Fix: rename the project / `artifactId` / `<name>` so it ends in one suffix. Mapping guide: System API -> `-sapi`, Process API -> `-papi`, Experience API -> `-xapi`, generic API -> `-api`, implementation -> `-impl`, MCP server -> `-mcp`, agent -> `-agent`.
- Example: `customer-sapi`, `order-processing-papi`.
- Also update: `pom.xml` (`artifactId`, `name`), `mule-artifact.json` if it carries the name, CI/CD pipeline variables, Anypoint Exchange asset, and CloudHub 2.0 deployment name.

---

## 3. Flow rules

### FLW-1: Configuration file should not have too many flows
- Pass: `count(mule:flow) < 10` per XML file
- Severity: MAJOR, code smell
- Fix: split into several files by responsibility, e.g. `interface.xml` (APIKit router + listeners), `implementation.xml`, `error-handler.xml`, `global.xml`, `<domain>-subflows.xml`.

### FLW-2: Configuration file should not have too many sub-flows
- Pass: `count(mule:sub-flow) < 5` per XML file
- Severity: MAJOR, code smell
- Fix: move sub-flows to a dedicated file (`common-subflows.xml`) grouped by purpose. Flow-refs resolve across files in the same app.

### FLW-3: Flow names should match a naming convention
- Pass regex: `^[a-z:\\{}]+(-[a-z]+)*$`
- What it allows: lowercase letters, `:`, `\`, `{`, `}`, then groups of `-lowercase`.
- What it rejects: **uppercase, digits, underscores, dots, spaces, parentheses**.
- Severity: MINOR, code smell

| Non-compliant | Compliant |
|---|---|
| `getCustomers` | `get-customers` |
| `Get_Customer_Flow` | `get-customer-flow` |
| `process-order-v2` | `process-order` (drop version) or `process-order-version-two` |
| `main_flow` | `main-flow` |
| `sync.orders` | `sync-orders` |
| `flow1` | `customer-sync-flow` (name should describe purpose, no digits) |

### FLW-4: Sub-flow names should match a naming convention
- Same regex and rules as FLW-3.
- Suggested pattern: `<verb>-<noun>-subflow` (e.g. `build-error-response-subflow`).

### FLW-6: Encryption key should not be logged
- Pass: no `logger` whose `message` contains `${mule.key}`
- Severity: MAJOR, **vulnerability**
- Fix: delete the logger or remove the key from the message. Never log any property that holds a key, password, token, or secret.

```xml
<!-- Non-compliant -->
<logger level="INFO" message="Using key ${mule.key}"/>
<!-- Compliant -->
<logger level="INFO" category="com.company.customer-sapi" message="Secure properties initialised"/>
```

---

## 4. Configuration rules

### CFG-1: Credentials and resources should be managed with application properties
- Pass: at least one `secure-properties:config` OR `mule:configuration-properties` exists in the application
- Severity: MAJOR, **bug** (application scope)
- Fix:
```xml
<configuration-properties file="config/${env}.properties" doc:name="Configuration properties"/>
```
Add `<global-property name="env" value="dev"/>` or pass `-Denv=dev` at runtime.

### CFG-2: Credentials vault should not use a hardcoded encryption key
- Pass: `secure-properties:config/@key` matches `^\$\{.*\}$`
- Severity: MAJOR, **bug**
```xml
<!-- Non-compliant -->
<secure-properties:config name="Secure_Properties_Config" file="config/${env}-secure.properties" key="MyHardcodedKey123" >
<!-- Compliant -->
<secure-properties:config name="Secure_Properties_Config" file="config/${env}-secure.properties" key="${mule.key}">
  <secure-properties:encrypt algorithm="AES" mode="CBC"/>
</secure-properties:config>
```
Supply `mule.key` at runtime (JVM arg or CloudHub 2.0 secure property). Never in a committed properties file. Do not log it (FLW-6).

### CFG-3: AutoDiscovery should be used to register the app in API Manager
- Pass: `count(api-gateway:autodiscovery) = 1` (exactly one per application)
- Severity: MAJOR, vulnerability
```xml
<api-gateway:autodiscovery apiId="${api.id}" ignoreBasePath="true" flowRef="main-flow"/>
```
Zero or two or more both fail.

### CFG-4: HTTP status codes should be set inside the exception handler
- Pass: `on-error-propagate` blocks exist with `type` = `APIKIT:BAD_REQUEST`, `APIKIT:METHOD_NOT_ALLOWED`, `APIKIT:NOT_FOUND` (all three required)
- Severity: MAJOR, **bug**
```xml
<error-handler name="global-error-handler">
  <on-error-propagate type="APIKIT:BAD_REQUEST" enableNotifications="true" logException="true">
    <ee:transform>
      <ee:message><ee:set-payload resource="dwl/error-bad-request.dwl"/></ee:message>
      <ee:variables><ee:set-variable variableName="httpStatus">400</ee:set-variable></ee:variables>
    </ee:transform>
  </on-error-propagate>
  <on-error-propagate type="APIKIT:NOT_FOUND"> ... 404 ... </on-error-propagate>
  <on-error-propagate type="APIKIT:METHOD_NOT_ALLOWED"> ... 405 ... </on-error-propagate>
  <!-- good practice, not required by the plugin: NOT_ACCEPTABLE 406, UNSUPPORTED_MEDIA_TYPE 415, NOT_IMPLEMENTED 501 -->
</error-handler>
```

### CFG-5: Data transformations in external DWL files: payload
- Pass: every `ee:transform/ee:message/ee:set-payload` has `@resource` matching `^.*dwl$`
- Severity: MINOR, code smell
```xml
<!-- Non-compliant -->
<ee:transform><ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload map { id: $.id }]]></ee:set-payload></ee:message></ee:transform>

<!-- Compliant -->
<ee:transform><ee:message><ee:set-payload resource="dwl/map-customers.dwl"/></ee:message></ee:transform>
```
and create `src/main/resources/dwl/map-customers.dwl`:
```dataweave
%dw 2.0
output application/json
---
payload map { id: $.id }
```
Note: the resource path is relative to `src/main/resources`. The value must end in `dwl` (lowercase).

### CFG-6: Data transformations in external DWL files: variable
- Pass: `ee:set-variable` has `@resource` matching `^.*dwl$`
- Severity: MINOR, code smell
```xml
<ee:variables>
  <ee:set-variable variableName="customerId" resource="dwl/extract-customer-id.dwl"/>
</ee:variables>
```
Caveat: the plugin's XPath targets `ee:message/ee:set-variable`, while real Mule 4 variables live under `ee:variables`. Treat externalizing both as the safe choice; it passes either way.

### CFG-7: HTTP listener should use HTTPS
- Pass: `http:listener-config/http:listener-connection/@protocol = 'HTTPS'`
- Severity: MAJOR, **vulnerability**
```xml
<http:listener-config name="https-listener-config">
  <http:listener-connection host="0.0.0.0" port="${https.port}" protocol="HTTPS" tlsContext="tls-server-context"/>
</http:listener-config>
<tls:context name="tls-server-context">
  <tls:key-store type="jks" path="${tls.keystore.path}" alias="${tls.key.alias}" keyPassword="${secure::tls.key.password}" password="${secure::tls.keystore.password}"/>
</tls:context>
```
Behavior note: switching from HTTP to HTTPS changes the endpoint scheme. Check that callers, API Manager, and the CloudHub 2.0 ingress/Runtime Fabric setup support it. On CloudHub 2.0, TLS is often terminated at the ingress; if the platform terminates TLS, confirm with the platform team before changing and consider documenting an exception rather than breaking the app.

### CFG-8: HTTP listener should use a specific port property
- Pass: `listener-connection/@port` equals `${https.port}` or `${https.private.port}` (the repo has both a stricter and a looser variant; the safest value is `${https.port}`)
- Severity: MAJOR, code smell
- Fix: `port="${https.port}"` and add `https.port=8082` (or the target) to every environment properties file. On CloudHub 2.0 the app port is typically 8081 for HTTP / 8082 for HTTPS inside the pod; verify for your runtime.

### CFG-9: API ID in AutoDiscovery should not be hardcoded
- Pass: `autodiscovery/@apiId` matches `^\$\{.*\}$`
- Severity: MAJOR, code smell
- Fix: `apiId="${api.id}"` with `api.id` per environment (API instance IDs differ between sandbox/prod).

### CFG-10: MSSQL DB host should not be hardcoded
- Pass: `db:config/db:mssql-connection/@host` matches `^\$\{.*\}$`
- Severity: MAJOR, code smell
```xml
<db:mssql-connection host="${db.host}" port="${db.port}" user="${db.user}" password="${secure::db.password}" databaseName="${db.name}"/>
```
Apply the same to `user`, `password`, `port`, `databaseName`, and to other DB connection types as hardening.

---

## 5. Domain rules (evaluated on `mule-domain` files)

These fire only when the XML root is `mule-domain`. If the project is a normal app, they do not apply, but treating them as standards for app-level `http:request-config` and `tls:context` is good practice.

| ID | Condition for a pass | Severity |
|---|---|---|
| DOM-11 | every `http:request-config` reconnection `reconnect/@count` is `${...}` | MAJOR, bug |
| DOM-12 | every reconnect `@frequency` is `${...}` | MAJOR, bug |
| DOM-13 | every `secure-properties:encrypt` is `algorithm="AES"` and `mode="CBC"` | MAJOR, vuln |
| DOM-14 | `http:listener-connection/@port` is `${...}` | MAJOR |
| DOM-15 | every `http:request-connection/@tlsContext` is `${...}` (as written in the plugin) | MINOR, bug |
| DOM-16 | `tls:trust-store/@path` is `${...}` | MINOR, vuln |
| DOM-17 | `tls:key-store/@path` is `${...}` | MINOR, vuln |
| DOM-18 | `tls:trust-store` has **no** `insecure` attribute | **CRITICAL**, vuln |
| DOM-19 | every HTTPS `listener-connection` has a `tlsContext` | MAJOR, vuln |
| DOM-20 | no `http:default-header` / `http:query-param` value of the form `#[ ... ]` | **CRITICAL** |
| DOM-21 | every `http:request-config/@responseTimeout` is `${...}` | **CRITICAL**, bug |

Compliant requester config:
```xml
<http:request-config name="customer-request-config" responseTimeout="${customer.http.response.timeout}">
  <http:request-connection host="${customer.http.host}" port="${customer.http.port}" protocol="HTTPS" tlsContext="${customer.tls.context}">
    <reconnection>
      <reconnect count="${customer.http.reconnect.count}" frequency="${customer.http.reconnect.frequency}"/>
    </reconnection>
  </http:request-connection>
</http:request-config>
```
For DOM-20, move dynamic header/query values from the config's defaults to the `http:request` operation itself (`<http:headers>#[...]</http:headers>`).

DOM-18 fix: remove `insecure="true"` and import the real certificate chain into the trust store.

---

## 6. Known false positives and caveats

- **APIKit-generated flow names** such as `get:\customers\(id):api-config` can fail FLW-3 because `(` and `)` are outside the allowed character class. These names are generated and must match the router's expectations. Do not hand-rename them. Options: ask the Sonar admin to exclude APIKit-generated flows (or `sonar.exclusions` for `interface.xml`), or accept the minor issue. State this to the user rather than renaming.
- **Rule 4 (APIKit errors) is application-scope**: it passes if the three handlers exist anywhere in the app, so keep them in one global error-handler file.
- **Counting rules are per file**, not per application. Splitting files fixes FLW-1/2.
- **The numbering skips 5 in the flows ruleset** (ids 1, 2, 3, 4, 6). That is normal.
- Rule severities and types can be changed in the SonarQube quality profile, so what you see in the report may differ from the table above. The pass condition is what matters.