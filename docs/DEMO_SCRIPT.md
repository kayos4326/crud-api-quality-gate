# Demo script

Run order for the live demo. Budget about 4 minutes of the 10.

## Before class

Do this on a reliable network — it pulls ~800 MB.

```bash
npm install
docker compose -f docker-compose.sonarqube.yml up -d
./scripts/wait-for-sonarqube.sh
export SONAR_TOKEN="$(./scripts/provision-token.sh)"
./scripts/setup-quality-gate.sh
```

Leave the container running. Everything above is safe to re-run.

> **Have a fallback.** Screenshot the failed dashboard the night before. If the
> projector or the network misbehaves you still have the evidence.

## Speaking split

Three people, roughly even:

| Who | Section | Time |
| --- | --- | --- |
| 1 | The pain point, and the secret we found in our own repo | ~3 min |
| 2 | What SonarQube is, the gate, the diagrams | ~3 min |
| 3 | The live demo and the limitations | ~4 min |

## The run

### 1. The real finding (~45s)

Open `docs/` and show the `docker-compose.yml` story before any tooling.

> "Before we show you the tool — this is our own coursework. Week 9 spent a
> whole lab teaching us never to write secrets to disk. Our `.gitignore` covered
> `.env`. It did not cover `docker-compose.yml`, which had our live Azure client
> secret, the database password and the JWT secret sitting in plaintext. Three
> of us looked at that repo every week and none of us saw it."

### 2. The clean baseline passes (~45s)

```bash
git checkout main
./scripts/run-local-demo.sh
```

> "This is the API with all 19 findings fixed. Gate passes, exit code zero. If
> this were `deploy.sh`, it would now ship."

### 3. The bad branch (~60s)

```bash
git checkout feature/sales-reporting
git diff main --stat
```

> "A teammate adds sales reporting. About 180 lines. It parses, it would run,
> and nothing in our existing tests says a word about it."

Open `reporting.js` and scroll it once. **Do not explain the bugs yet.**

> "Would you catch everything wrong in this file at 6pm with two other reviews
> waiting?"

### 4. The deploy gets blocked (~60s)

```bash
./deploy.sh
```

> "Same command we have used since Week 3. Step 0 is now the quality gate. It
> failed, so `deploy.sh` exits one and the `scp` never runs. The VM is untouched.
> Nobody had to notice anything."

### 5. Walk the dashboard (~45s)

<http://localhost:9000/dashboard?id=crud-api>

1. **3 of 6 conditions failed** — the summary.
2. **The blocker**: `jwt.sign()` with a literal signing key (`javascript:S6437`).
   Anyone with the source can mint a valid admin token.
3. **`javascript:S2068`** — the hard-coded database password.
4. **`javascript:S3776`** — cognitive complexity 34 against a limit of 15.

### 6. What it missed — the best part (~45s)

> "Now the honest bit. There is a SQL injection in that file, built by string
> concatenation, exactly what Week 3 told us not to do. SonarQube Community
> Build did not flag it. We checked properly — we wrote a probe file with three
> different injection patterns and scanned it. Zero issues. The rule that would
> catch it needs taint analysis, which is a paid edition.
>
> There is also a missing `redis.del` in the new import endpoint, so the
> catalogue serves stale data. No rule catches that either, because it is not a
> bad pattern — it is missing logic.
>
> So the gate is not a replacement for review. It clears the mechanical work so
> the reviewer has attention left for the things only a person can catch."

## Questions you should expect

**"Doesn't this just annoy developers?"**
It does if you switch everything on at once on an existing codebase. That is why
SonarQube's default model is *clean as you code* — judge new and changed code so
the existing mess doesn't block today's work.

**"What if the gate is wrong?"**
`SKIP_QUALITY_GATE=1 ./deploy.sh` still deploys and prints a warning. A gate you
cannot bypass in an emergency gets deleted; one that logs the bypass survives.

**"Why not just use ESLint?"**
ESLint checks style in your editor and you can ignore it. This is a *gate* — a
server-side decision, with history and ratings, that owns the exit code of the
deploy script.

**"Why did you fix the 19 issues instead of showing them?"**
We wanted the baseline to pass honestly. Showing a gate that fails on both
branches proves nothing. The 19 findings are in git history if you want them.

## If something breaks

| Symptom | Fix |
| --- | --- |
| `Cannot connect to the Docker daemon` | Start Docker Desktop. |
| SonarQube never reaches UP | `docker compose -f docker-compose.sonarqube.yml logs sonarqube`. Usually memory — give Docker 4 GB+. |
| `SONAR_TOKEN must be set` | `export SONAR_TOKEN="$(./scripts/provision-token.sh)"` |
| Gate passes on the bad branch | The gate was not attached. Re-run `./scripts/setup-quality-gate.sh`. |
| Clean slate | `docker compose -f docker-compose.sonarqube.yml down -v`, then redo "Before class". |
