# Secrets Directory

This directory contains sensitive credentials for the American Authorship Database application.

## Security Guidelines

🔒 **CRITICAL**: Files in this directory (except templates and README) are **NEVER** committed to git.

## Setup Instructions

### First-Time Setup

1. **Generate a strong database password:**

   ```bash
   # Generate a 32-character random password
   openssl rand -base64 32
   ```

2. **Create the password file:**

   ```bash
   # Copy the template
   cp secrets/db_password.txt.template secrets/db_password.txt

   # Edit with your password (use the one generated above)
   nano secrets/db_password.txt
   # OR
   echo "YOUR_GENERATED_PASSWORD" > secrets/db_password.txt
   ```

3. **Verify the file is ignored by git:**

   ```bash
   git status secrets/
   # Should only show README.md and .template files
   ```

### Password Rotation

To rotate the database password:

1. **Generate new password:**
   ```bash
   openssl rand -base64 32
   ```

2. **Update the password file:**
   ```bash
   echo "NEW_PASSWORD" > secrets/db_password.txt
   ```

3. **Update the database:**
   ```sql
   -- Connect to PostgreSQL as superuser
   ALTER USER authorship_admin WITH PASSWORD 'NEW_PASSWORD';
   ```

4. **Restart services:**
   ```bash
   docker-compose down
   docker-compose up -d
   ```

## Files

- `db_password.txt.template` - Template for database password (safe to commit)
- `db_password.txt` - **ACTUAL** password (NEVER commit!)
- `README.md` - This file (safe to commit)

## Verification

After setup, verify secrets are working:

```bash
# Check that docker-compose can read the secret
docker-compose config | grep -A 5 secrets

# Test database connection
docker-compose exec postgres psql -U authorship_admin -d american_authorship -c "SELECT 1;"
```

## Emergency Password Reset

If you've accidentally committed credentials:

1. **Immediately rotate the password** (see Password Rotation above)
2. **Remove from git history:**
   ```bash
   # Use BFG Repo Cleaner or git-filter-repo
   git filter-repo --path secrets/db_password.txt --invert-paths
   ```
3. **Force push** (if safe to do so):
   ```bash
   git push --force
   ```
4. **Notify team** that credentials were compromised

## Best Practices

- ✅ Use `openssl rand -base64 32` for password generation
- ✅ Rotate passwords every 90 days
- ✅ Never share passwords via email or chat
- ✅ Use environment-specific passwords (dev vs. prod)
- ❌ Never commit `db_password.txt` to version control
- ❌ Never reuse passwords across environments
- ❌ Never use simple/guessable passwords

## Production Deployment

For production, use a proper secrets management system:

- **Kubernetes**: Use Kubernetes Secrets or sealed-secrets
- **AWS**: Use AWS Secrets Manager or Parameter Store
- **Azure**: Use Azure Key Vault
- **GCP**: Use Google Secret Manager
- **HashiCorp Vault**: For multi-cloud deployments

Example for Kubernetes:

```bash
# Create secret from file
kubectl create secret generic db-password \
  --from-file=password=secrets/db_password.txt \
  --namespace=authorship-prod
```
