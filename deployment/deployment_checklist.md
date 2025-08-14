# Deployment Checklist: American Authorship Dashboard

## Pre-Deployment Setup

### Database Migration
- [ ] **Export local database**
  - [ ] Run `01_export_database.R`
  - [ ] Verify export files created in `database_export/`
  - [ ] Check export summary for all tables

- [ ] **Set up NeonDB**
  - [ ] Create NeonDB account at [neon.tech](https://neon.tech)
  - [ ] Create new project: `american-authorship-db`
  - [ ] Copy connection details (host, user, password)
  - [ ] Set environment variables:
    ```bash
    export NEONDB_HOST=your-host.neon.tech
    export NEONDB_NAME=neondb
    export NEONDB_USER=neondb_owner
    export NEONDB_PASSWORD=your-password
    export NEONDB_PORT=5432
    ```

- [ ] **Import to NeonDB**
  - [ ] Run `02_import_to_neondb.R`
  - [ ] Verify all tables imported successfully
  - [ ] Check row counts match local database

- [ ] **Verify migration**
  - [ ] Run `03_verify_neondb.R`
  - [ ] Confirm all verification tests pass
  - [ ] Test sample queries work correctly

### Application Preparation
- [ ] **Configure application**
  - [ ] Run `04_prepare_app_config.R`
  - [ ] Verify `.env` file created in shiny-app directory
  - [ ] Check `cloud_config.R` updated for production

- [ ] **Test locally with NeonDB**
  - [ ] Navigate to `shiny-app/` directory
  - [ ] Run `R -e "shiny::runApp()"`
  - [ ] Test all modules work with cloud database:
    - [ ] Author Networks module loads and displays data
    - [ ] Royalty Analysis module loads and displays data
    - [ ] Sliding scale filter works correctly
    - [ ] All visualizations render properly

- [ ] **Check dependencies**
  - [ ] Run `05_check_dependencies.R`
  - [ ] Install any missing packages
  - [ ] Resolve any dependency warnings
  - [ ] Verify `DESCRIPTION` file created

## Deployment to shinyapps.io

### Account Setup
- [ ] **Configure shinyapps.io account**
  - [ ] Create account at [shinyapps.io](https://shinyapps.io)
  - [ ] Install rsconnect: `install.packages("rsconnect")`
  - [ ] Get token from shinyapps.io dashboard
  - [ ] Configure rsconnect:
    ```r
    rsconnect::setAccountInfo(
      name = "your-account-name",
      token = "your-token", 
      secret = "your-secret"
    )
    ```

### Deploy Application
- [ ] **Run deployment script**
  - [ ] Execute `06_deploy_to_shinyapps.R`
  - [ ] Monitor deployment progress
  - [ ] Note the application URL

- [ ] **Configure environment variables in shinyapps.io**
  - [ ] Go to shinyapps.io dashboard
  - [ ] Navigate to your app → Settings → Variables
  - [ ] Add environment variables:
    - [ ] `DB_HOST`: Your NeonDB host
    - [ ] `DB_NAME`: `neondb`
    - [ ] `DB_USER`: Your NeonDB user
    - [ ] `DB_PASSWORD`: Your NeonDB password
    - [ ] `DB_PORT`: `5432`
  - [ ] Save and restart application

## Post-Deployment Testing

### Functional Testing
- [ ] **Basic functionality**
  - [ ] Application loads without errors
  - [ ] Database connection works (no connection errors)
  - [ ] Navigation between tabs works

- [ ] **Author Networks module**
  - [ ] Module loads and displays data
  - [ ] Network visualizations render correctly
  - [ ] Filters work properly
  - [ ] Data tables display correctly

- [ ] **Royalty Analysis module**
  - [ ] Module loads and displays data
  - [ ] Charts and plots render correctly
  - [ ] Year range filter works
  - [ ] Publisher/author filters work
  - [ ] **Sliding scale filter works correctly** ⭐
  - [ ] Tier analysis table displays properly

- [ ] **Data integrity**
  - [ ] All data appears complete
  - [ ] No obvious data corruption
  - [ ] Calculations appear correct

### Performance Testing
- [ ] **Run performance tests**
  - [ ] Set APP_URL environment variable
  - [ ] Run `07_test_performance.R`
  - [ ] Review performance report

- [ ] **Manual performance check**
  - [ ] Application loads within 10 seconds
  - [ ] Module switching is responsive
  - [ ] Large visualizations load reasonably fast
  - [ ] No obvious memory leaks during extended use

### Error Monitoring
- [ ] **Check application logs**
  - [ ] Review logs in shinyapps.io dashboard
  - [ ] Look for any error messages
  - [ ] Verify no database connection issues

- [ ] **Browser testing**
  - [ ] Test in Chrome
  - [ ] Test in Firefox
  - [ ] Test in Safari (if available)
  - [ ] Check browser console for JavaScript errors

## Production Readiness

### Documentation
- [ ] **Update documentation**
  - [ ] Document the deployed URL
  - [ ] Update any internal documentation
  - [ ] Create user guide if needed

### Monitoring Setup
- [ ] **Configure monitoring**
  - [ ] Set up email notifications in shinyapps.io
  - [ ] Monitor usage metrics
  - [ ] Set up regular health checks

### Backup and Recovery
- [ ] **Verify backup strategy**
  - [ ] NeonDB automatic backups enabled
  - [ ] Application code backed up in version control
  - [ ] Deployment configuration documented

## Validation Checklist

### Critical Features (Must Work)
- [ ] ✅ Application loads successfully
- [ ] ✅ Database connection established
- [ ] ✅ Author Networks displays data
- [ ] ✅ Royalty Analysis displays data
- [ ] ✅ Sliding scale filter returns correct results
- [ ] ✅ All visualizations render without errors

### Important Features (Should Work)
- [ ] ✅ All filters function correctly
- [ ] ✅ Data tables are sortable and searchable
- [ ] ✅ Export functionality works (if implemented)
- [ ] ✅ Responsive design works on different screen sizes

### Nice-to-Have Features (May Have Minor Issues)
- [ ] ✅ Optimal loading performance
- [ ] ✅ Advanced filtering combinations
- [ ] ✅ Detailed tooltips and help text

## Sign-Off

### Technical Validation
- [ ] **Database migration verified** - Signed: _________________ Date: _________
- [ ] **Application functionality tested** - Signed: _________________ Date: _________
- [ ] **Performance acceptable** - Signed: _________________ Date: _________

### Business Validation
- [ ] **User acceptance testing completed** - Signed: _________________ Date: _________
- [ ] **Data accuracy verified** - Signed: _________________ Date: _________
- [ ] **Ready for production use** - Signed: _________________ Date: _________

## Deployment Information

**Deployment Date**: _______________
**Application URL**: _______________
**NeonDB Instance**: _______________
**shinyapps.io Account**: _______________
**Deployed By**: _______________

## Notes

_Use this space for any deployment-specific notes, issues encountered, or special configurations:_

---

**Next Steps After Deployment:**
1. Monitor application for first 24-48 hours
2. Gather user feedback
3. Plan for any necessary updates or improvements
4. Set up regular maintenance schedule
