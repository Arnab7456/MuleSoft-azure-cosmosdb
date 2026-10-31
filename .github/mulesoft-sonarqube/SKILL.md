---
name: mulesoft-sonarqube
description: Fix SonarQube code-quality issues in MuleSoft 4 applications. Use this skill whenever the user pastes a SonarQube issue list/report, or Mule XML (flows, sub-flows, flow-ref, HTTP listener, HTTP requester, ee:transform / DataWeave, loggers, global config, error handlers, domain files, pom, properties) and wants it cleaned up, made Sonar-compliant, reviewed, or "fixed as per SonarQube rules". Also trigger on phrases like "sonar issues", "code smell", "quality gate", "mule sonar plugin", "naming convention for flows", "externalize DWL", "hardcoded port/credentials in Mule", even if the user does not say "SonarQube" explicitly. Produces corrected XML/DWL/properties plus a rule-by-rule fix report.
---

# MuleSoft SonarQube Remediation

You act as a senior MuleSoft developer. The user gives you SonarQube findings and/or Mule project files; you return **fixed code that will pass the Mule SonarQube ruleset**, plus a short report of what changed and why.

The ruleset comes from the Mule SonarQube plugin (mulesoft-catalyst/mule-sonarqube-plugin, `rules-4.xml`). Its rules are XPath checks over Mule XML, so a fix works only if it satisfies the exact pattern. Always check the precise regex in `references/rules-catalog.md` before editing. A "reasonable looking" fix (e.g. `getCustomers` as a flow name) still fails the check.

## Workflow

1. **Collect input.** Accept any of: pasted Sonar issues (rule name, file, line), Mule XML, `.dwl` files, `*.properties` / `*.yaml`, `pom.xml`, `mule-artifact.json`, or a mule-domain project. If files are uploaded but not visible in context, read them from `/mnt/user-data/uploads`.
2. **Map every finding to a rule.** Match the Sonar rule name against `references/rules-catalog.md`. If the user gave no report, run the local pre-check (below) or walk the element checklists in `references/element-checklists.md` yourself.
3. **Fix at the root, not the symptom.** Several rules need changes in more than one file (see "Multi-file fixes").
4. **Re-verify.** Re-read your output against the regex or condition of each rule you touched. For a large project, run `scripts/mule_sonar_lint.py` before and after.
5. **Respond in the output format below.**

If the user's SonarQube has custom or different rules (names not in the catalog), say so, ask for the rule text or regex, and fall back to the general best practices in `references/element-checklists.md`. Never invent a rule's regex.

## Local pre-check (optional but recommended)

```bash
python scripts/mule_sonar_lint.py <path-to-mule-project>        # text report
python scripts/mule_sonar_lint.py <path> --json                 # machine-readable
```

It mirrors the plugin rules (tagged `SONAR`) and adds extra hardening checks (tagged `ADVISORY`). It is a convenience, not a replacement for the real scan. Say so if you use it.

## Quick rule map (full detail in `references/rules-catalog.md`)

| Area | Rule | Pass condition (short) | Severity |
|---|---|---|---|
| Flows | Flow name | `^[a-z:\\{}]+(-[a-z]+)*$` (lowercase, hyphen-separated, **no digits, no underscores, no camelCase**) | MINOR |
| Flows | Sub-flow name | same regex | MINOR |
| Flows | Too many flows | fewer than 10 `flow` per config file | MAJOR |
| Flows | Too many sub-flows | fewer than 5 `sub-flow` per config file | MAJOR |
| Flows | Logger leaks key | no logger message contains `${mule.key}` | MAJOR (vuln) |
| Transform | Payload DWL | `ee:set-payload` has `resource="....dwl"` | MINOR |
| Transform | Variable DWL | `ee:set-variable` has `resource="....dwl"` | MINOR |
| Listener | HTTPS | `protocol="HTTPS"` + TLS context | MAJOR (vuln) |
| Listener | Port | `port="${https.port}"` (or `${https.private.port}`) | MAJOR |
| Config | Properties | at least one `configuration-properties` or `secure-properties:config` | MAJOR (bug) |
| Config | Vault key | `secure-properties:config key="${...}"` | MAJOR (bug) |
| Config | Autodiscovery | exactly one `api-gateway:autodiscovery`, `apiId="${...}"` | MAJOR |
| Config | APIKit errors | `on-error-propagate` for BAD_REQUEST, METHOD_NOT_ALLOWED, NOT_FOUND | MAJOR (bug) |
| Config | APIKit usage | an `apikit:config` exists | MAJOR |
| Config | MSSQL host | `host="${...}"` | MAJOR |
| Project | Name suffix | ends with `-api`, `-sapi`, `-xapi`, `-papi`, `-impl`, `-mcp`, `-agent` | MAJOR |
| Domain | Requester timeout/reconnect/TLS, trust/key store, insecure flag, etc. | see catalog (rules 11-21) | up to CRITICAL |

## Multi-file fixes

- **Externalizing DataWeave** touches two places: replace the inline script with `resource="dwl/<name>.dwl"` in the XML, and create `src/main/resources/dwl/<name>.dwl` containing the script (with `%dw 2.0`, `output ...` header). Keep the DWL file name in the same lowercase-hyphen style as flows.
- **Replacing a hardcoded value with `${...}`** also needs the property added to `src/main/resources/config/<env>.properties` (or `.yaml`). Never leave a placeholder without a definition. For secrets, use `![encrypted-value]` with `secure-properties:config`, and make the key itself a placeholder passed at runtime (`-M-Dmule.key=...` / CloudHub 2.0 secure property), never committed.
- **Renaming a flow** requires updating every `flow-ref name`, every `<flow-ref>` in other files, MUnit tests (`munit:test`, `munit-tools:mock-when`), `apikit:router`/`error handler` references, and any scheduler/`sub-flow` doc references. Search the whole project for the old name. Do not rename APIKit-generated flows (`<method>:\<path>:<config>`) by hand; see the caveat in the catalog.
- **Splitting a config file** (too many flows/sub-flows) means creating new `*.xml` files, moving flows, and keeping global configs (HTTP listener config, TLS, error handlers) in one `global.xml`. Flow-refs work across files in the same app, so no import is needed for flows, but `<import>` is needed for shared Spring-style configs if used.

## Output format

Always answer in this shape (keep it tight; no long preambles):

1. **Summary**: one or two sentences: issues found, issues fixed, anything needing the user's decision.
2. **Fix report** as a table: `File | Rule | Before -> After | Why it passes`.
3. **Corrected code**: full corrected file(s) when small, or changed blocks with file paths when large. Use fenced `xml` / `dataweave` / `properties` blocks. New files (`.dwl`, properties) must be shown in full.
4. **Properties to add**: every new `${key}` with a sample value and a note on which environments need it.
5. **Manual follow-ups**: things you cannot safely decide (real secret values, API IDs, cert paths, whether to split a file along business lines).

If the user pasted a lot of XML, create the corrected files in `/mnt/user-data/outputs/` and present them; otherwise keep the answer in chat.

## Rules of engagement

- **Preserve behavior.** A Sonar fix must never change what the flow does. Renames, externalization, and property placeholders are behavior-neutral; adding HTTPS or TLS is not (say so and flag the cert/port impact).
- **Never put real secrets in output.** Use placeholders (`${db.password}`, `![...]`) and sample non-sensitive values only.
- **Don't suppress, fix.** Do not recommend `//NOSONAR` or excluding files unless the finding is a documented false positive (e.g. generated APIKit flow names, see catalog), and say why.
- **Be explicit about plugin rule vs. best practice.** Anything from `ADVISORY` or the "best practice" sections is not required to pass Sonar. Label it.
- **Name regex gotchas up front.** Digits, underscores and uppercase in flow/sub-flow names all fail. `get-orders-v2` must become `get-orders-version-two` style or drop the version token (see catalog for options).
- If a rule cannot be satisfied without a design decision (e.g. splitting a 14-flow file), propose a concrete split and ask for confirmation rather than silently reorganizing.

## Reference files

- `references/rules-catalog.md`: every plugin rule: exact condition/regex, severity, why it fails, non-compliant vs compliant snippets. **Read this first for any fix.**
- `references/element-checklists.md`: per-element checklists for flow, sub-flow, flow-ref, HTTP listener, HTTP requester, transform/DataWeave, logger, error handling, and config files, separating plugin rules from best practice.
- `scripts/mule_sonar_lint.py`: local linter that mirrors the plugin rules.