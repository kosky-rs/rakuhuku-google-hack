# /deploy - Rakufuku Deploy Skill

Deploy backend (Cloud Run) and/or frontend (Firebase Hosting).

## Usage
- `/deploy` or `/deploy all` - Deploy both backend and frontend
- `/deploy backend` - Deploy backend only
- `/deploy frontend` - Deploy frontend only

## Steps

### 1. Pre-deploy check
Run `flutter analyze --no-fatal-infos --no-fatal-warnings` in `frontend/` directory. If there are errors (excluding test files), stop and report.

### 2. Execute deployment
Run the deploy script with GCP_PROJECT_ID set:

```
GCP_PROJECT_ID=rakufuku-pwa bash deploy.sh <target>
```

Where `<target>` is determined by the argument:
- No argument or `all` -> `all` (backend + frontend)
- `backend` -> `backend`
- `frontend` -> `frontend`

### 3. Post-deploy verification
After deployment completes:
- For backend: Run `curl -s https://rakufuku-api-1024882237054.asia-northeast1.run.app/api/v1/health` and verify `{"status":"healthy"}`
- For frontend: Report the hosting URL `https://rakufuku-pwa.web.app`

### 4. Report results
Report deployed URLs and health check status to the user.

## Environment
- GCP Project: `rakufuku-pwa`
- Region: `asia-northeast1`
- Backend: Cloud Run (`rakufuku-api`)
- Frontend: Firebase Hosting (`rakufuku-pwa.web.app`)
- Deploy script: `deploy.sh` at project root
