# Campus CRUD API — SonarQube quality gate

Backend Application Development (CSX4110), Assumption University.

**Team:** Thar Lin Htet(6642062) · Honey Linn(6726113) · Mi Hsu Myat Win Myint(6726115)

This is the API we built across Weeks 3–10 — Express, Prisma, MySQL, JWT, Redis,
Azure Key Vault — with an automated quality gate put in front of `deploy.sh`.

---

## The pain point

We review each other's code by hand. That works until the deadline is close, and
then it doesn't: reviewers skim, everyone assumes someone else looked properly,
and bad code reaches the VM because `./deploy.sh` never asks any questions. It
copies whatever is in the folder and restarts PM2.

We did not have to invent this problem. **We pointed SonarQube at our own
coursework and it found 19 issues in code we had already submitted**, including:

- `app.use(cors())` with no options — every origin on the internet allowed
- a `Dockerfile` doing `COPY . .`, which copies anything `.dockerignore` misses
- a container running as **root**
- eight `catch` blocks that swallowed the error, leaving nothing to debug
- Express advertising its version in every response header

Separately, and worse: our `docker-compose.yml` had a **live Azure service
principal secret, the database password, and the JWT secret in plaintext**. Our
`.gitignore` covered `.env` but not the compose file. That repository was one
`git init && git push` away from publishing a working cloud credential.

Week 9 taught us not to put secrets on disk. We did it anyway, in a different
file, and no human review caught it.

## The proposed solution

Put **SonarQube** in front of the deployment. `deploy.sh` now runs the scan as
Step 0 and **refuses to `scp` anything** unless the quality gate passes.

The reviewer still reviews design and intent. The machine handles the part
humans are bad at: applying ~400 rules to every line, every time, without
getting bored.

---

## What is in this repository

| Branch | What it is | Gate |
| --- | --- | --- |
| `main` | The API with all 19 findings fixed | **Passes**, exit 0 — deploy proceeds |
| `feature/sales-reporting` | A realistic bad feature branch | **Fails**, exit 1 — deploy aborts |

---

## Quick start

Requires **Node 20+** and **Docker**.

```bash
npm install
./scripts/run-local-demo.sh
```

That starts SonarQube in Docker, waits for it, mints a token, creates the
quality gate, scans, and exits non-zero if the gate fails. The first run pulls
the image and takes a few minutes; later runs take about 30 seconds.

Report: <http://localhost:9000/dashboard?id=crud-api> (`admin` / `Demo-Sonar-2026`).

Stop it with `docker compose -f docker-compose.sonarqube.yml down`.

## The demo

```bash
git checkout main                     # gate passes, exit 0
./scripts/run-local-demo.sh

git checkout feature/sales-reporting  # gate fails, exit 1
./deploy.sh                           # aborts at Step 0, before scp
```

### What the gate catches on the bad branch

7 issues, and **3 of the 6 gate conditions fail**:

```
ERROR  security_rating               actual=5 (E)   must be A
ERROR  blocker_violations            actual=1       must be 0
ERROR  new_violations                actual=7       must be 0
OK     reliability_rating            actual=1 (A)
OK     duplicated_lines_density      actual=0.0%
OK     new_duplicated_lines_density  actual=0.0%
```

| Planted in `reporting.js` | Rule | Which week warned us |
| --- | --- | --- |
| `jwt.sign()` with a literal key — **Blocker** | `javascript:S6437` | Week 9, secrets |
| Hard-coded database password | `javascript:S2068` | Week 9, secrets |
| MD5 used for a fingerprint | `javascript:S4790` | — |
| `Math.random()` for a download token | `javascript:S2245` | — |
| Cognitive complexity 34 against a limit of 15 | `javascript:S3776` | — |

---

## What the gate does **not** catch

This matters more than the list above, and it is the honest part of the talk.

**1. SQL injection — not detected at all.** `reporting.js` builds a query by
string concatenation, exactly what Week 3 told us never to do:

```js
const sql = "SELECT ... WHERE LOWER(ProductName) LIKE '%" + keyword.toLowerCase() + "%'";
const [rows] = await reportPool.query(sql);
```

SonarQube **Community Build does not flag this in JavaScript.** We verified it
rather than assuming: we wrote a probe file with three different injection
patterns (concatenation into a variable, concatenation inline in the call, and a
template literal) and scanned it. Zero issues. The rule that would catch it,
`javascript:S3649`, requires taint analysis and **does not exist in this
edition** — it needs Developer Edition or SonarQube Cloud.

Interestingly, the equivalent Java rule *does* ship in Community Build. Static
analysis coverage is not uniform across languages, and "we run SonarQube" does
not mean "we are covered."

**2. Missing cache invalidation — not detected.** The new `/api/reports/import`
endpoint writes products but never calls `await redis.del('products:all')`, so
the catalogue serves stale data for 60 seconds. Week 10 called that step
"crucial." No rule catches it, because it is not a bad *pattern* — it is missing
business logic. Only a human who knows the system would spot it.

That is the argument for keeping human review, stated precisely: the gate
handles the mechanical checks so the reviewer has attention left for the things
only a reviewer can do.

---

## About the quality gate

`scripts/setup-quality-gate.sh` builds a gate named **Campus CRUD API** and
attaches it to the project. It keeps SonarQube's seeded new-code conditions for
issues and duplication, adds four conditions on *all* code, and removes the
seeded coverage conditions.

| Condition | Fails when | Scope |
| --- | --- | --- |
| `new_violations` | any new issue | new code |
| `new_duplicated_lines_density` | above 3% | new code |
| `security_rating` | worse than A | all code |
| `reliability_rating` | worse than A | all code |
| `blocker_violations` | above 0 | all code |
| `duplicated_lines_density` | above 3% | all code |

**Why conditions on all code, not just new code?** Because new-code conditions
are worked out from **commit dates** against a baseline analysis. On a freshly
cloned repository every commit predates the first scan, so there is no new code
and the gate passes with almost nothing evaluated. That behaviour is what makes
SonarQube adoptable on a legacy codebase — but it is useless for a demo that has
to fail on demand.

**Why no coverage condition?** We wrote this API across eight weeks with no unit
tests, only the `test_api*.sh` cURL scripts. Coverage is 0%, so gating on it
would fail the clean baseline too and prove nothing. Writing real tests is the
obvious next step; pretending otherwise would be dishonest.

The duplication conditions are configured and currently report 0% — they are
there to catch copy-paste in future work, not because they fire today.

---

## Honest limitations

- **Community Build analyses one branch at a time.** Real pull-request analysis,
  where "new code" means the diff, needs Developer Edition or SonarQube Cloud.
- **A quality gate is not a security audit.** It matches known bad patterns. It
  does not understand our pricing rules and will not tell us they are wrong.
- **False positives exist.** Someone has to own triage, or the team learns to
  reach for `SKIP_QUALITY_GATE=1`, which is worse than having no gate.
- **The override is deliberate.** `SKIP_QUALITY_GATE=1 ./deploy.sh` still works
  and prints a warning. A gate nobody can bypass in an emergency gets removed
  entirely; one that logs its bypass gets respected.
- The SonarQube admin password in `scripts/provision-token.sh` is hardcoded on
  purpose: it is a disposable local container. Do not copy that pattern.

## What we did not do

- No unit tests, so no coverage gate.
- The gate runs locally, not on a server. A real team would run it in CI so it
  cannot be skipped by forgetting; `deploy.sh` is where our pipeline lives, so
  that is where we put it.
- We did not rotate the credentials that were in `docker-compose.yml` as part of
  this repo — that is done in the Azure portal, and it needs doing.
