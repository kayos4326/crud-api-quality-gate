# Demo and rehearsal instructions

## One day before class

1. Open Docker Desktop.
2. Open a terminal.
3. Run:

```bash
cd ~/Desktop/crud-api-quality-gate
npm install
docker compose -f docker-compose.sonarqube.yml up -d
./scripts/wait-for-sonarqube.sh
```

4. Open <http://localhost:9000> and confirm the page loads.
5. Open the PowerPoint and confirm Presenter View shows the notes.
6. Practice once with a 10-minute timer.
7. Save screenshots of the passing and failing terminal output as a backup.

## Five minutes before presenting

Run:

```bash
cd ~/Desktop/crud-api-quality-gate
git checkout main
docker compose -f docker-compose.sonarqube.yml up -d
./scripts/wait-for-sonarqube.sh
```

Open these before presentation mode:

- PowerPoint deck
- Terminal in `~/Desktop/crud-api-quality-gate`
- GitHub pull request
- SonarQube dashboard: <http://localhost:9000/dashboard?id=crud-api>

Do not display `.env`, Azure secrets, database passwords, or SSH keys.

## Live commands on Slide 7

### Clean branch

```bash
git checkout main
./scripts/run-local-demo.sh
```

Wait for:

```text
QUALITY GATE PASSED - deploy.sh would proceed.
```

### Failing branch

```bash
git checkout feature/sales-reporting
./deploy.sh
```

Wait for:

```text
DEPLOY ABORTED - the quality gate failed.
```

The script must stop before this line appears:

```text
Step 1: Transferring backend and static UI files to Azure VM...
```

That absence proves that `scp` never ran.

### After the presentation

```bash
git checkout main
docker compose -f docker-compose.sonarqube.yml down
```

## Emergency fallback

If Docker or SonarQube fails during class:

1. Do not spend the presentation troubleshooting.
2. Show the saved passing and failing screenshots.
3. Open the SonarQube dashboard screenshot.
4. Explain that the verified local result was exit `0` on `main` and exit `1` on `feature/sales-reporting`.

## Timing checkpoints

| Time | Expected position |
| --- | --- |
| 0:00 | Slide 1 |
| 3:00 | Handover from Thar to Honey |
| 6:00 | Handover from Honey to Thar for the live demo |
| 6:10 | Begin live commands |
| 7:25 | Handover from Thar to Mi Hsu Myat for Slide 8 |
| 8:40 | Begin Slide 9 |
| 10:00 | Finish Slide 9 |

## Presentation rules

- Do not merge the intentionally bad pull request.
- Do not run `SKIP_QUALITY_GATE=1 ./deploy.sh` during class.
- Do not claim SonarQube catches every security problem.
- Clearly separate the 19 SonarQube findings from the live credentials found during manual review.
- Leave at least one second after terminal output appears before explaining it.
