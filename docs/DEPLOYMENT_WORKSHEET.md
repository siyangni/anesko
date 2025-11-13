# Deployment Worksheet

Use this worksheet to track your deployment configuration and credentials.

**⚠️ SECURITY WARNING**: This file will contain sensitive information.
- **DO NOT** commit this file to git (it's in .gitignore)
- Store securely (password manager, encrypted drive)
- Share only via secure channels

---

## Project Information

**Project Name**: American Authorship Database (1860-1920)
**Deployment Date**: _______________
**Deployed By**: _______________
**Environment**: [ ] Development [ ] Staging [ ] Production

---

## 1. NeonDB Configuration

### Account Details
- **NeonDB Account Email**: _______________
- **Project Name**: american-authorship-db
- **Project ID**: _______________
- **Region**: _______________

### Connection Details

**Standard Endpoint** (for direct connections):
```
Host: _______________________________________________
Port: 5432
Database: neondb
Username: _______________
Password: _______________
SSL Mode: require

Full connection string:
postgresql://[username]:[password]@[host]/neondb?sslmode=require
```

**Pooled Endpoint** (for Shiny app - RECOMMENDED):
```
Host: _______________________________________________
Port: 5432
Database: neondb
Username: _______________
Password: _______________
SSL Mode: require

Full connection string:
postgresql://[username]:[password]@[host-pooler]/neondb?sslmode=require
```

### NeonDB Settings
- **Compute Size**: [ ] Free (0.25 vCPU) [ ] Small (0.5 vCPU) [ ] Medium (1 vCPU) [ ] Large (2+ vCPU)
- **Storage**: ______ GiB used / ______ GiB available
- **Connection Pool Enabled**: [ ] Yes [ ] No
- **Connection Pool Mode**: [ ] Transaction [ ] Session
- **Connection Pool Size**: _______
- **Auto-suspend Delay**: _______ minutes
- **Autoscaling Min**: _______ vCPU
- **Autoscaling Max**: _______ vCPU

### Branches
- **Production Branch**: _______________
- **Development Branch**: _______________
- **Testing Branch**: _______________

### Backups
- **Point-in-Time Recovery**: [ ] Enabled [ ] Not Available
- **Manual Backup Schedule**: _______________
- **Last Backup**: _______________
- **Backup Location**: _______________

---

## 2. Database Migration Status

### Data Import Checklist
- [ ] Schema created (tables, indexes, constraints)
- [ ] book_entries imported (_______ rows)
- [ ] book_sales imported (_______ rows)
- [ ] royalty_tiers imported (_______ rows)
- [ ] app_users created (if using auth)
- [ ] Indexes created and analyzed
- [ ] Data integrity verified
- [ ] Test queries successful

### Migration Details
- **Migration Date**: _______________
- **Migration Method**: [ ] Automated script [ ] Manual psql [ ] CSV import
- **Data Source**: _______________
- **Migration Time**: _______ minutes
- **Issues Encountered**: _______________

---

## 3. Shiny Hosting Configuration

### Hosting Option Selected
- [ ] **Option 1**: ShinyApps.io
- [ ] **Option 2**: Self-Hosted Shiny Server
- [ ] **Option 3**: Docker on Cloud
- [ ] **Option 4**: Other: _______________

---

### Option 1: ShinyApps.io

**Account Details**:
- **Account Name**: _______________
- **Account Email**: _______________
- **Tier**: [ ] Free [ ] Starter ($9) [ ] Basic ($39) [ ] Standard ($99) [ ] Professional ($299)

**Application Details**:
- **App Name**: american-authorship
- **App URL**: https://_______________
.shinyapps.io/american-authorship/
- **Deploy Date**: _______________

**Configuration**:
- **Instance Size**: [ ] Small (1GB) [ ] Medium (2GB) [ ] Large (4GB)
- **Max Worker Processes**: _______
- **Connection Timeout**: _______ seconds
- **Idle Timeout**: _______ minutes

**rsconnect Credentials**:
```
Token: _______________
Secret: _______________
```

**Environment Variables Set**:
- [ ] DB_HOST
- [ ] DB_NAME
- [ ] DB_USER
- [ ] DB_PASSWORD
- [ ] DB_PORT
- [ ] DB_SSL_MODE

---

### Option 2: Self-Hosted Shiny Server

**Server Details**:
- **Provider**: [ ] DigitalOcean [ ] AWS [ ] GCP [ ] Azure [ ] Other: _______
- **Server IP**: _______________
- **Server Hostname**: _______________
- **SSH Port**: 22
- **SSH Key Location**: _______________

**Server Specs**:
- **CPU**: _______ cores
- **RAM**: _______ GB
- **Storage**: _______ GB
- **OS**: [ ] Ubuntu 22.04 [ ] Ubuntu 20.04 [ ] Other: _______
- **Region**: _______________

**Software Versions**:
- **R Version**: _______
- **Shiny Server Version**: _______
- **Nginx Version**: _______ (if using)
- **PostgreSQL Client**: _______

**Domain & SSL**:
- **Domain Name**: _______________
- **DNS Provider**: _______________
- **SSL Certificate**: [ ] Let's Encrypt [ ] Other: _______
- **SSL Expiry Date**: _______________

**App Location**:
- **Shiny Server Directory**: /srv/shiny-server/american-authorship
- **App Log Location**: /var/log/shiny-server/
- **Environment Config**: [ ] /etc/environment [ ] systemd service [ ] .Renviron

**Nginx Configuration** (if using):
- **Config File**: /etc/nginx/sites-available/shiny-app
- **Access Logs**: /var/log/nginx/access.log
- **Error Logs**: /var/log/nginx/error.log

**Firewall Rules**:
- [ ] Port 22 (SSH) - Open
- [ ] Port 80 (HTTP) - Open
- [ ] Port 443 (HTTPS) - Open
- [ ] Port 3838 (Shiny) - [ ] Open [ ] Internal only

---

### Option 3: Docker Deployment

**Container Registry**:
- **Registry**: [ ] Docker Hub [ ] AWS ECR [ ] GCP GCR [ ] Azure ACR
- **Image Name**: _______________
- **Image Tag**: _______________
- **Registry URL**: _______________

**Orchestration**:
- **Method**: [ ] Docker Compose [ ] Kubernetes [ ] AWS ECS [ ] Other: _______
- **Cluster Name**: _______________
- **Service Name**: _______________

**Container Details**:
- **Container Name**: american-authorship-shiny
- **CPU Limit**: _______ cores
- **Memory Limit**: _______ GB
- **Restart Policy**: [ ] always [ ] unless-stopped [ ] on-failure

**Volumes**:
- [ ] Logs: ./shiny-app/logs → /var/log/shiny-server
- [ ] Other: _______________

**Secrets**:
- **Secret Storage**: [ ] Docker secrets [ ] Kubernetes secrets [ ] AWS Secrets Manager [ ] Other: _______
- **DB Password Secret**: _______________

**Load Balancer** (if using):
- **Provider**: _______________
- **DNS Name**: _______________
- **Health Check Path**: /american-authorship/

---

## 4. Application Configuration

### Environment Variables

**Database Connection** (in production):
```bash
DB_HOST="_______________"
DB_NAME="neondb"
DB_USER="_______________"
DB_PASSWORD="_______________"  # Use secrets in production!
DB_PORT="5432"
DB_SSL_MODE="require"
```

### Connection Pool Settings

**File**: `shiny-app/config/app_config.R`
```r
POOL_SIZE_MIN <- _______
POOL_SIZE_MAX <- _______
POOL_IDLE_TIMEOUT <- _______
POOL_VALIDATION_INTERVAL <- _______
```

### Authentication Settings

**Authentication Enabled**: [ ] Yes [ ] No

**If enabled**:
- **Auth Source**: [ ] Database [ ] File [ ] LDAP [ ] Other: _______
- **Session Timeout**: _______ minutes
- **Max Failed Attempts**: _______
- **Lockout Duration**: _______ minutes

**Demo Credentials** (disable in production!):
- [ ] Disabled
- [ ] Enabled (development only)

---

## 5. Monitoring & Alerting

### Uptime Monitoring
- **Service**: [ ] UptimeRobot [ ] Pingdom [ ] StatusCake [ ] Other: _______
- **Check URL**: _______________
- **Check Interval**: _______ minutes
- **Alert Email**: _______________
- **Alert Webhook**: _______________

### Application Monitoring
- **Log Aggregation**: [ ] Papertrail [ ] Loggly [ ] CloudWatch [ ] None
- **Error Tracking**: [ ] Sentry [ ] Rollbar [ ] Other: _______
- **Analytics**: [ ] Google Analytics [ ] Plausible [ ] None

### NeonDB Monitoring
- **Neon Console Alerts**: [ ] Configured
- **Alert Thresholds**:
  - CPU Usage: > _______%
  - Memory Usage: > _______%
  - Storage: > _______%
  - Compute Hours: > _______

---

## 6. Backup & Recovery

### Database Backups
- **Backup Method**: [ ] NeonDB auto-backup [ ] Manual pg_dump [ ] Both
- **Backup Schedule**: _______________
- **Backup Retention**: _______ days
- **Backup Location**: _______________
- **Last Backup Date**: _______________
- **Last Backup Size**: _______ MB

### Application Backups
- **Code Repository**: https://github.com/siyangni/anesko
- **Branch**: _______________
- **Last Commit**: _______________
- **Config Backups**: _______________

### Disaster Recovery
- **RTO (Recovery Time Objective)**: _______ hours
- **RPO (Recovery Point Objective)**: _______ hours
- **Recovery Tested**: [ ] Yes (Date: _______) [ ] No

---

## 7. Performance Metrics

### Baseline Performance
- **Page Load Time**: _______ ms
- **Query Response Time**: _______ ms
- **Concurrent Users Tested**: _______
- **Memory Usage (Idle)**: _______ MB
- **Memory Usage (Peak)**: _______ MB

### Load Testing Results
- **Test Date**: _______________
- **Test Tool**: [ ] shinyloadtest [ ] Apache Bench [ ] Other: _______
- **Simulated Users**: _______
- **Duration**: _______ minutes
- **Success Rate**: _______%
- **Average Response Time**: _______ ms
- **95th Percentile**: _______ ms
- **Max Response Time**: _______ ms

---

## 8. Cost Tracking

### Monthly Costs

**NeonDB**:
- Plan: [ ] Free [ ] Pro [ ] Other: _______
- Monthly Cost: $_______
- Current Usage: _______ compute hours, _______ GiB storage

**Hosting**:
- Provider: _______________
- Plan: _______________
- Monthly Cost: $_______

**Other Services**:
- Domain: $_______ /year
- SSL Certificate: $_______ /year
- Monitoring: $_______ /month
- Other: $_______ /month

**Total Monthly Cost**: $_______

### Usage Trends
| Month | Users | Page Views | Compute Hours | Total Cost |
|-------|-------|------------|---------------|------------|
| _____ | _____ | __________ | _____________ | $_________ |
| _____ | _____ | __________ | _____________ | $_________ |
| _____ | _____ | __________ | _____________ | $_________ |

---

## 9. Access Control

### Administrative Access

**NeonDB Admin**:
- Email: _______________
- 2FA Enabled: [ ] Yes [ ] No

**Hosting Provider Admin**:
- Email: _______________
- 2FA Enabled: [ ] Yes [ ] No

**Server SSH Access**:
- User: _______________
- Key Location: _______________
- Additional Users: _______________

### Application Users

**Admin Users**:
| Username | Email | Role | Created |
|----------|-------|------|---------|
| ________ | _____ | ____ | _______ |
| ________ | _____ | ____ | _______ |

**Service Accounts**:
| Account | Purpose | Last Rotated |
|---------|---------|--------------|
| _______ | _______ | ____________ |
| _______ | _______ | ____________ |

---

## 10. Maintenance Schedule

### Regular Maintenance

**Daily**:
- [ ] Check application logs
- [ ] Monitor uptime status
- [ ] Review error rates

**Weekly**:
- [ ] Review NeonDB usage
- [ ] Check backup status
- [ ] Review performance metrics
- [ ] Check for R package updates

**Monthly**:
- [ ] Review access logs
- [ ] Analyze cost trends
- [ ] Test disaster recovery
- [ ] Update documentation
- [ ] Review security patches

**Quarterly**:
- [ ] Load testing
- [ ] Dependency updates
- [ ] Security audit
- [ ] Cost optimization review

### Update History

| Date | Component | Version | Notes |
|------|-----------|---------|-------|
| ____ | _________ | _______ | _____ |
| ____ | _________ | _______ | _____ |
| ____ | _________ | _______ | _____ |

---

## 11. Troubleshooting Contacts

### Technical Support

**NeonDB Support**:
- Email: support@neon.tech
- Community: https://community.neon.tech/
- Status Page: https://neonstatus.com/

**Hosting Provider Support**:
- Provider: _______________
- Email: _______________
- Phone: _______________
- Support Portal: _______________

**R/Shiny Support**:
- RStudio Community: https://community.rstudio.com/
- Shiny Issues: https://github.com/rstudio/shiny/issues

### Internal Contacts

**Project Lead**:
- Name: _______________
- Email: _______________
- Phone: _______________

**Technical Contact**:
- Name: _______________
- Email: _______________
- Phone: _______________

**Escalation Path**:
1. _______________
2. _______________
3. _______________

---

## 12. Deployment Checklist

### Pre-Deployment
- [ ] All code committed to git
- [ ] Tests passing
- [ ] Data migrated to NeonDB
- [ ] Connection tested
- [ ] Environment variables configured
- [ ] Secrets secured
- [ ] SSL certificate obtained (if needed)
- [ ] DNS configured (if needed)
- [ ] Backup plan in place

### Deployment
- [ ] Application deployed
- [ ] Health check passing
- [ ] All modules loading
- [ ] Data displaying correctly
- [ ] Plots rendering
- [ ] No console errors
- [ ] Authentication working (if enabled)
- [ ] Performance acceptable

### Post-Deployment
- [ ] Monitoring configured
- [ ] Alerts set up
- [ ] Backup verified
- [ ] Documentation updated
- [ ] Stakeholders notified
- [ ] URL shared
- [ ] Load testing completed
- [ ] SSL/HTTPS verified

### Go-Live Approval
- [ ] Technical lead approval
- [ ] Project manager approval
- [ ] Security review complete
- [ ] Data integrity verified
- [ ] Backup tested
- [ ] Rollback plan documented

**Approved By**: _______________
**Date**: _______________
**Signature**: _______________

---

## 13. Notes & Issues

### Deployment Notes
```
Date: _______________
Notes:






```

### Known Issues
```
Issue 1:
Status: [ ] Open [ ] In Progress [ ] Resolved
Description:

Resolution:


Issue 2:
Status: [ ] Open [ ] In Progress [ ] Resolved
Description:

Resolution:
```

### Future Improvements
- [ ] _______________
- [ ] _______________
- [ ] _______________
- [ ] _______________

---

## 14. Quick Reference

### Essential URLs
- **Production App**: _______________
- **Development App**: _______________
- **NeonDB Console**: https://console.neon.tech/
- **Hosting Dashboard**: _______________
- **Monitoring Dashboard**: _______________
- **Status Page**: _______________
- **Documentation**: https://github.com/siyangni/anesko/tree/main/docs

### Essential Commands

**Test Database Connection**:
```bash
psql "postgresql://[user]:[pass]@[host]/neondb?sslmode=require" -c "SELECT version();"
```

**View Logs** (ShinyApps.io):
```
Dashboard → american-authorship → Logs
```

**View Logs** (Self-hosted):
```bash
tail -f /var/log/shiny-server/*.log
```

**View Logs** (Docker):
```bash
docker-compose logs -f shiny
```

**Restart App** (Self-hosted):
```bash
sudo systemctl restart shiny-server
```

**Restart App** (Docker):
```bash
docker-compose restart shiny
```

**Deploy Update** (ShinyApps.io):
```r
rsconnect::deployApp(appDir="shiny-app", forceUpdate=TRUE)
```

---

**Document Version**: 1.0
**Last Updated**: _______________
**Next Review Date**: _______________

