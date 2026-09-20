# 10-minute presentation script

The same script is stored in the PowerPoint speaker notes. Use Presenter View during the presentation.

## Speaking order

| Presenter | Slides | Target time |
| --- | --- | --- |
| Thar Lin Htet | 1–3 | 3 minutes |
| Honey Linn | 4–6 | 3 minutes |
| Mi Hsu Myat Win Myint | 7–9 | 4 minutes |

## Slide 1 — SonarQube Quality Gate

**Thar · 35 seconds**

Good morning. We are Thar Lin Htet, Honey Linn, and Mi Hsu Myat Win Myint.

Our project adds a SonarQube quality gate to the backend API that we built in this course. The gate checks our code before `deploy.sh` sends anything to Azure.

Today we will show the problem, explain SonarQube, and run a real deployment that gets stopped.

## Slide 2 — Scenario

**Thar · 1 minute 10 seconds**

Our scenario comes from the API we built throughout this course.

Before this project, the workflow was simple. A developer changed the code, another person reviewed it, and `deploy.sh` copied the files to our Azure VM and restarted PM2.

The problem is the space between review and deployment. A reviewer can be tired or rushed. If they miss a hard-coded password, an unsafe Docker setting, or a very complicated function, `deploy.sh` does not ask any questions. It continues.

Our pain point was that code quality depended on one person noticing every problem before the deadline.

## Slide 3 — Evidence from our API

**Thar · 1 minute 15 seconds**

We tested the idea on our own code instead of inventing an example.

The first SonarQube scan found nineteen issues. Our security rating was D. It reported unrestricted CORS, a Docker container running as root, recursive copying that could include sensitive files, and error handlers that hid useful information.

While preparing the safe public repository, our manual audit found something even more serious. A Docker Compose file contained our Azure client secret, database password, and JWT secret in plaintext.

SonarQube did not discover that file because we did not include the unsafe original in the demo repository. The tool found nineteen code issues. Our manual audit found the live credentials.

We removed sensitive values before publishing. Honey will now explain the technology.

## Slide 4 — SonarQube

**Honey · 1 minute**

SonarQube is a static analysis tool. It reads our source code and configuration files without starting the API.

The process has three parts. First, the scanner uploads the code. Second, SonarQube applies its JavaScript and Docker rules and calculates ratings. Third, the quality gate decides whether the result passes.

The important part is the exit code. A passing gate returns zero, so `deploy.sh` continues. A failing gate returns one, so the script stops before `scp` sends files to Azure.

This makes the scan an enforced checkpoint instead of a report that everyone can ignore.

## Slide 5 — Architecture

**Honey · 1 minute 10 seconds**

The developer runs the same `deploy.sh` used in class. We added Step zero. That step starts SonarQube in Docker when necessary, creates an analysis token, configures the gate, and scans the working tree.

SonarQube sends its result back to the script. If the result passes, the existing deployment continues. It copies the API to Azure, connects through SSH, installs dependencies, applies Prisma migrations, and restarts PM2.

If the result fails, the script exits immediately. `scp` never runs, so the Azure VM remains unchanged.

Every box and connector represents a real script or system in our repository.

## Slide 6 — Two branches

**Honey · 50 seconds**

We made the demonstration repeatable with two Git branches.

`main` contains the fixed API. It reports zero issues, security rating A, and exit code zero.

The feature branch adds sales reporting with deliberate problems. It reports seven issues, security rating E, and exit code one.

The gate requires security and reliability ratings of A, zero blocker issues, no new issues, and duplication no higher than three percent.

We did not add a coverage condition. Our course API has manual cURL test scripts but no unit-test suite, so a coverage gate would fail both branches and prove nothing.

Mi Hsu Myat will now run the implementation.

## Slide 7 — Live demo

**Mi Hsu Myat · 1 minute 25 seconds**

Now I will run the live demonstration.

First, I check out `main` and run the local demo script. The final line says `QUALITY GATE PASSED` and returns exit code zero.

Second, I check out `feature/sales-reporting`. This is the branch in our open GitHub pull request.

Third, I run the real deploy command: `./deploy.sh`.

The scan reports the problems and returns exit code one. The script prints `DEPLOY ABORTED`. Step one never appears, which proves `scp` did not run and no file reached Azure.

GitHub says this branch has no merge conflicts. That means the files can be combined. SonarQube answers whether the code meets our quality rules.

## Slide 8 — Verified result

**Mi Hsu Myat · 1 minute 15 seconds**

SonarQube reports seven issues, security rating E, and one blocker.

The blocker is a literal key passed to JWT sign. Anyone who reads that source can use the same key to create a token that our API accepts.

The other findings include a hard-coded database password, `Math.random` used for a download token, MD5 used for a fingerprint, and a commission function with cognitive complexity thirty-four. The configured limit is fifteen.

Three gate conditions fail: security rating, blocker count, and new issue count. Any one failure is enough to stop deployment.

## Slide 9 — Limits and conclusion

**Mi Hsu Myat · 1 minute 20 seconds**

The most important result is what the gate did not catch.

First, `reporting.js` contains a SQL query built with string concatenation. We tested three JavaScript injection patterns. Community Build reported zero injection issues. The taint-analysis rule requires Developer Edition or SonarQube Cloud.

Second, the bulk import route writes products but forgets to clear the Redis cache. Users can receive old data for sixty seconds. Static analysis cannot know that our business logic requires cache invalidation.

Automated checks handle repeatable rules consistently. Human reviewers still check system behavior and business logic. Using both gives the team a safer deployment process.

The runnable code, both branches, diagrams, and instructions are available in our public GitHub repository.

Thank you. We are ready for questions.
