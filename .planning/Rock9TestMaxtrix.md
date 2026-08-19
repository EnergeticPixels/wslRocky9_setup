# Rocky Linux 9 Provisioning Test Matrix

## Purpose

Validate that this repository behaves predictably on Rocky Linux 9 across common provisioning combinations.

## Test Window

- Start date: 2026-08-19
- End date: 2026-08-22 (adjust as needed)

## Global Preconditions

1. Host: Windows 11 with WSL2 Rocky Linux 9 guest.
2. System updated before first run:

```bash
sudo dnf makecache
sudo dnf upgrade --refresh -y
```

3. Repository cloned and permissions set:

```bash
cd /home/aqjRocky9/serverProvo
chmod +x provisioning.sh begin_here.sh
```

4. Platform check must pass before each matrix run:

```bash
bash ./provisioning.sh validate-platform
```

5. For each test case, start from a known .env state:

```bash
cp -f .env.sample .env
```

## Evidence To Capture Per Test

- Command output for the run.
- Result of relevant service checks.
- Any warnings or fallback messages.
- Final verdict: PASS or FAIL.
- Notes on remediation if FAIL.

## Result Legend

- PASS: Completed and expected behavior observed.
- FAIL: Error, mismatch, or missing expected behavior.
- BLOCKED: Could not execute due to external issue.

## Matrix

| ID | Profile | Key .env settings | Run command | Validation checks | Result | Notes |
|---|---|---|---|---|---|---|
| M01 | Baseline no optional stacks | DATABASE_TYPE=none, WEB_SERVER_ENABLE=false, JAVA_ENABLE=false, NODE_ENABLE=false, PYTHON_ENABLE=false, REDIS_ENABLE=false | sudo bash ./provisioning.sh run | Script completes; core tools present; no optional installers run |  |  |
| M02 | Full dry run plan safety | Any representative full config | sudo bash ./provisioning.sh run --dry-run | Lists expected scripts only; no package/service changes |  |  |
| M03 | Web only Apache + PHP | WEB_SERVER_ENABLE=true, WEB_SERVER_TYPE=apache, PHP_ENABLE=true | sudo bash ./provisioning.sh run --only web | httpd active; php-fpm active when configured; config test passes |  |  |
| M04 | Web only Nginx + PHP | WEB_SERVER_ENABLE=true, WEB_SERVER_TYPE=nginx, PHP_ENABLE=true | sudo bash ./provisioning.sh run --only web | nginx active; php-fpm active; Apache stopped if conflict |  |  |
| M05 | Web SSL local domain | WEB_SSL_ENABLE=true, WEB_SSL_BASE_DOMAIN=app.local | sudo bash ./provisioning.sh run --only web | TLS cert created; HTTPS vhost/server block present; host mapping documented |  |  |
| M06 | MariaDB path | DATABASE_TYPE=mysql, MARIADB_VERSION=10.11, DB_DEV_SETUP=true | sudo bash ./provisioning.sh run --only db | mariadb active; DB/user created; login works with configured creds |  |  |
| M07 | PostgreSQL path | DATABASE_TYPE=postgres, POSTGRESQL_VERSION=17, DB_DEV_SETUP=true | sudo bash ./provisioning.sh run --only db | postgresql service active; DB/role created; psql login works |  |  |
| M08 | MongoDB path | DATABASE_TYPE=mongodb, MONGODB_VERSION=8.0, DB_DEV_SETUP=true | sudo bash ./provisioning.sh run --only db | mongod active; ping success via mongosh; DB/user setup works |  |  |
| M09 | Redis only | REDIS_ENABLE=true, REDIS_VERSION set to desired target | sudo bash ./provisioning.sh run --only redis | redis service active; redis-cli ping returns PONG |  |  |
| M10 | Java Tomcat mode | JAVA_ENABLE=true, JAVA_VERSION=8, JAVA_SERVER_MODE=tomcat, JAVA_DISTRO=temurin | sudo bash ./provisioning.sh run --only java | Java installed; Tomcat installed/active or fallback applied |  |  |
| M11 | Java JAR mode | JAVA_ENABLE=true, JAVA_SERVER_MODE=jar, JAVA_APP_JAR_PATH valid | sudo bash ./provisioning.sh run --only java | Service/unit created and starts; app bound to configured port |  |  |
| M12 | Node via NVM | NODE_ENABLE=true, NODE_DEFAULT_VERSION=22, NODE_VERSIONS=22 | sudo bash ./provisioning.sh run --only node | nvm install succeeds; default alias set; node -v matches |  |  |
| M13 | Python base only | PYTHON_ENABLE=true, PYTHON_DEV_MODE=none, PYTHON_DATA_SCIENCE_STACK_ENABLE=false | sudo bash ./provisioning.sh run --only python | Base Python + pip installed; pip usable |  |  |
| M14 | Python reflex mode | PYTHON_ENABLE=true, PYTHON_DEV_MODE=reflex | sudo bash ./provisioning.sh run --only python | python3.9 path selected; venv setup succeeds |  |  |
| M15 | End-to-end typical app stack | WEB_SERVER_ENABLE=true, PHP_ENABLE=true, DATABASE_TYPE=postgres, REDIS_ENABLE=true, NODE_ENABLE=true, PYTHON_ENABLE=true | sudo bash ./provisioning.sh run | Full run completes; web+db+cache+runtimes all healthy |  |  |
| M16 | Idempotency rerun | Reuse config from M15 with no changes | sudo bash ./provisioning.sh run | Second run completes with no destructive drift; services remain healthy |  |  |

## Quick Validation Commands

Use these after relevant cases:

```bash
systemctl status httpd --no-pager || true
systemctl status nginx --no-pager || true
systemctl status php-fpm --no-pager || true
systemctl status mariadb --no-pager || true
systemctl status postgresql --no-pager || true
systemctl status mongod --no-pager || true
systemctl status redis --no-pager || true
```

```bash
php -v || true
java -version || true
node -v || true
python3 --version || true
python3.9 --version || true
redis-cli ping || true
psql --version || true
mongosh --version || true
```

## Daily Execution Log

### Day 1

- Planned cases:
- Completed cases:
- Failures:
- Actions taken:

### Day 2

- Planned cases:
- Completed cases:
- Failures:
- Actions taken:

### Day 3

- Planned cases:
- Completed cases:
- Failures:
- Actions taken:

## Exit Criteria

1. All required profiles executed at least once.
2. No unresolved FAIL results.
3. At least one idempotency rerun (M16) passes.
4. Any discovered edge-case behavior is documented for future runs.
