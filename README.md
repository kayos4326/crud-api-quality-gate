# CRUD API with a SonarQube quality gate

Backend Application Development (CSX4110), Assumption University

Team members:

- Thar Lin Htet (6642062)
- Honey Linn (6726113)
- Mi Hsu Myat Win Myint (6726115)

This project uses the CRUD API we built in class. The API uses Express, Prisma,
MySQL, JWT, Redis, Azure Key Vault, and Docker.

We added SonarQube because our old deployment script uploaded the project
without checking the code first. Now the script runs a quality check before it
copies anything to the Azure VM.

## Why we made this

Checking code by hand is useful, but it is easy to miss something when the team
is busy. We scanned our API and SonarQube found 19 issues. Some examples were:

- CORS allowed requests from every website
- the Docker container ran as root
- the Dockerfile could copy files that should stay private
- several error handlers did not log the real error
- Express showed its version in response headers

We fixed these problems on `main`.

We also created `feature/sales-reporting` for the demo. That branch contains
deliberate mistakes, so the quality gate fails and stops the deployment.

| Branch | Result |
| --- | --- |
| `main` | The scan passes and deployment can continue |
| `feature/sales-reporting` | The scan fails and deployment stops |

## What you need

- Node.js 20 or newer
- Docker Desktop
- Java for the SonarQube scanner

## Run the project check

Install the packages:

```bash
npm install
```

Run the local SonarQube demo:

```bash
./scripts/run-local-demo.sh
```

The first run may take a few minutes because Docker has to download SonarQube.
After it starts, the report is available at:

<http://localhost:9000/dashboard?id=crud-api>

Local SonarQube login:

```text
Username: admin
Password: Demo-Sonar-2026
```

Stop SonarQube with:

```bash
docker compose -f docker-compose.sonarqube.yml down
```

## Try both branches

The clean branch should pass:

```bash
git checkout main
./scripts/run-local-demo.sh
```

The demo branch should fail:

```bash
git checkout feature/sales-reporting
./deploy.sh
```

When the second command runs, `deploy.sh` stops at Step 0. It does not run
`scp`, so no project files are uploaded to Azure.

## Quality gate rules

The gate fails when:

- the security or reliability rating is worse than A
- there is a blocker issue
- SonarQube finds a new issue
- duplicated code is above 3%

We did not add a coverage rule because this class project has shell-based API
tests, not a unit-test suite with a coverage report.

## What happens on the demo branch

SonarQube reports seven issues. The examples include a hard-coded JWT key, a
hard-coded database password, MD5, `Math.random()` used for a token, and a
function that is too difficult to follow.

The expected gate result is:

```text
ERROR  security_rating               actual=5 (E)   must be A
ERROR  blocker_violations            actual=1       must be 0
ERROR  new_violations                actual=7       must be 0
OK     reliability_rating            actual=1 (A)
OK     duplicated_lines_density      actual=0.0%
OK     new_duplicated_lines_density  actual=0.0%
```

## SonarQube does not catch everything

The bad branch also has an SQL query built with string concatenation. SonarQube
Community Build did not report it for JavaScript. The branch also forgets to
clear the Redis product cache after an import. SonarQube cannot understand that
project-specific rule.

This is why we still need code review. SonarQube catches many common problems,
but a person still has to check the business logic and security decisions.

## Main files

| File | Purpose |
| --- | --- |
| `app.js` | Express API |
| `deploy.sh` | Checks the code, then deploys it |
| `scripts/quality-gate.sh` | Runs the SonarQube scan |
| `scripts/setup-quality-gate.sh` | Creates the gate rules |
| `docker-compose.sonarqube.yml` | Runs local SonarQube |
| `docker-compose.yml` | Runs the API and Redis |
| `prisma/schema.prisma` | Database models |

## Current limits

- The SonarQube server runs locally instead of in GitHub Actions.
- Community Build scans one branch at a time. Pull-request analysis needs a
  paid SonarQube edition or SonarQube Cloud.
- The project does not have a unit-test coverage report yet.
- `SKIP_QUALITY_GATE=1 ./deploy.sh` is available for an emergency, so the person
  deploying the project must use that option carefully.
