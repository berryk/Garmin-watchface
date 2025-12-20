# GitHub Secrets Setup Guide

This guide explains how to configure GitHub Secrets for automated Garmin device downloads in CI/CD.

## Why GitHub Secrets?

The Dockerfile uses `connect-iq-sdk-manager-cli` to download device definitions directly from Garmin. This requires Garmin developer account credentials. GitHub Secrets allows you to securely store these credentials without exposing them in your repository.

## Security Benefits

✅ **Secrets are encrypted** - GitHub encrypts secrets at rest
✅ **Not visible in logs** - Secret values are masked in workflow logs
✅ **Not stored in Docker image** - Build args don't persist in image layers
✅ **Access control** - Only authorized workflows can access secrets

## Setup Instructions

### Step 1: Create a Garmin Developer Account

If you don't have one already:

1. Go to [developer.garmin.com](https://developer.garmin.com)
2. Click "Sign Up" and create an account
3. Verify your email address
4. Log in to confirm your account is active

### Step 2: Add Secrets to GitHub Repository

1. **Navigate to your repository settings**
   - Go to your GitHub repository
   - Click **Settings** (top right)

2. **Access Secrets and Variables**
   - In the left sidebar, expand **Secrets and variables**
   - Click **Actions**

3. **Add GARMIN_EMAIL secret**
   - Click **New repository secret**
   - Name: `GARMIN_EMAIL`
   - Secret: Your Garmin developer account email
   - Click **Add secret**

4. **Add GARMIN_PASSWORD secret**
   - Click **New repository secret** again
   - Name: `GARMIN_PASSWORD`
   - Secret: Your Garmin developer account password
   - Click **Add secret**

### Step 3: Verify Secrets are Set

You should now see two secrets listed:
- `GARMIN_EMAIL`
- `GARMIN_PASSWORD`

**Note:** Once added, you cannot view the secret values again. You can only update or delete them.

### Step 4: Test the Workflow

1. Push a commit to trigger the workflow:
   ```bash
   git add .
   git commit -m "Test automated device downloads"
   git push
   ```

2. Go to the **Actions** tab in your repository

3. Watch the workflow run - the Docker build step should show:
   ```
   Installing SDK and devices using connect-iq-sdk-manager...
   ```

## Troubleshooting

### "Login failed" in Docker build

**Problem:** The workflow logs show authentication failures.

**Solutions:**
- Verify your Garmin credentials are correct
- Check that the secrets are named exactly `GARMIN_EMAIL` and `GARMIN_PASSWORD`
- Ensure your Garmin account is active and verified

### Fallback to GitHub release

**Problem:** Build logs show "No Garmin credentials provided, using fallback..."

**Solutions:**
- Secrets may not be set correctly
- Check the secret names match exactly (case-sensitive)
- Ensure you've saved the secrets (not just entered them)

### Device installation warnings

**Problem:** Some devices fail to install

**Solutions:**
- This is expected - not all device IDs may be available
- Check the `DEVICES` list in Dockerfile matches available device IDs
- Visit [Connect IQ Device List](https://developer.garmin.com/connect-iq/compatible-devices/) for valid device IDs

## Updating Secrets

To update a secret:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click on the secret name
3. Click **Update secret**
4. Enter the new value
5. Click **Update secret**

## Removing Secrets

If you want to use the fallback method (GitHub release devices):

1. Delete both secrets from repository settings
2. The workflow will automatically use the fallback SDK download
3. No changes to code required

## Alternative: Environment Secrets

For organization-level secrets (shared across multiple repositories):

1. Go to your **Organization settings**
2. Navigate to **Secrets and variables** → **Actions**
3. Click **New organization secret**
4. Choose which repositories can access the secret

## Security Best Practices

🔒 **Use a dedicated account** - Consider creating a separate Garmin account for CI/CD
🔒 **Rotate credentials** - Periodically update your secrets
🔒 **Limit repository access** - Only give necessary collaborators access to repository settings
🔒 **Monitor workflow logs** - Check for unexpected authentication attempts
🔒 **Use organization secrets** - For shared credentials across projects

## For Local Development

For local Docker builds, use build arguments instead of secrets:

```bash
docker build \
  --build-arg GARMIN_EMAIL="your@email.com" \
  --build-arg GARMIN_PASSWORD="yourpassword" \
  -t garmin-watchface .
```

Or create a `.env` file (never commit this):

```bash
cp .env.example .env
# Edit .env with your credentials
# Build without args (credentials from .env)
```

## More Information

- [GitHub Encrypted Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Docker Build Args Best Practices](https://docs.docker.com/build/building/secrets/)
- [Garmin Connect IQ Developer Portal](https://developer.garmin.com/connect-iq/)
