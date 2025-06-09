# Deployment Guide - American Authorship Database

This guide provides step-by-step instructions for deploying your Shiny app online using different hosting options.

## 🚀 Quick Start Options

1. **[ShinyApps.io](#option-1-shinyappsio)** - Easiest, good for demos (Free tier available)
2. **[Docker + Cloud](#option-2-docker--cloud-platforms)** - More control, production-ready
3. **[DigitalOcean/AWS](#option-3-vps-deployment)** - Full control, cost-effective
4. **[Heroku](#option-4-heroku)** - Simple deployment platform

---

## Option 1: ShinyApps.io

**Best for:** Quick demos, testing, academic presentations  
**Cost:** Free tier available (25 active hours/month)  
**Effort:** ⭐⭐☆☆☆ (Easy)

### Prerequisites
- R/RStudio installed locally
- Cloud database setup (see `database_setup_guide.md`)

### Steps

1. **Set up cloud database** (required - ShinyApps.io doesn't support local PostgreSQL)
   ```bash
   # See shiny-app/database_setup_guide.md for detailed instructions
   # Recommended: Use Neon free tier (500MB, no limits)
   ./setup_neon.sh
   ./migrate_to_neon.sh
   ```

2. **Install deployment package**
   ```r
   install.packages("rsconnect")
   ```

3. **Configure authentication**
   - Go to [shinyapps.io](https://www.shinyapps.io)
   - Create account, go to Account > Tokens
   - Copy token and secret:
   ```r
   rsconnect::setAccountInfo(
     name = 'your-username',
     token = 'your-token', 
     secret = 'your-secret'
   )
   ```

4. **Deploy the app**
   ```bash
   cd ~/anesko/shiny-app
   Rscript deploy_shinyapps.R
   ```

### Limitations
- 25 active hours/month on free tier
- No direct database hosting
- Limited customization
- Slower performance for large datasets

### **📋 Quick Deployment with Neon**

```bash
# Complete deployment in 4 steps:
./setup_neon.sh          # Configure Neon database
./migrate_to_neon.sh      # Migrate your data
./test_app_with_neon.sh   # Test locally first
./deploy_to_shinyapps.sh  # Deploy live
```

---

## Option 2: Docker + Cloud Platforms

**Best for:** Production apps, scalability, full control  
**Cost:** $5-20/month depending on cloud provider  
**Effort:** ⭐⭐⭐⭐☆ (Moderate)

### Prerequisites
- Docker installed locally
- Cloud provider account (DigitalOcean, AWS, Google Cloud)

### Steps

1. **Create database backup**
   ```bash
   cd ~/anesko
   pg_dump -h localhost -U siyang american_authorship > data/backup.sql
   ```

2. **Test locally with Docker**
   ```bash
   # Build and run with Docker Compose
   docker-compose up --build
   
   # Visit http://localhost:3838/american-authorship
   # Test all functionality
   ```

3. **Deploy to cloud provider**

   #### Option 2a: DigitalOcean App Platform
   ```bash
   # Create account at digitalocean.com
   # Install doctl CLI
   snap install doctl
   doctl auth init
   
   # Create app
   doctl apps create --spec .do/app.yaml
   ```

   #### Option 2b: Google Cloud Run
   ```bash
   # Install gcloud CLI
   # Set up project
   gcloud auth login
   gcloud config set project your-project-id
   
   # Build and deploy
   gcloud builds submit --tag gcr.io/your-project-id/american-authorship
   gcloud run deploy --image gcr.io/your-project-id/american-authorship --platform managed
   ```

   #### Option 2c: AWS Fargate
   ```bash
   # Install AWS CLI
   aws configure
   
   # Create ECR repository
   aws ecr create-repository --repository-name american-authorship
   
   # Build and push
   docker build -t american-authorship .
   docker tag american-authorship:latest your-account.dkr.ecr.region.amazonaws.com/american-authorship:latest
   docker push your-account.dkr.ecr.region.amazonaws.com/american-authorship:latest
   ```

### Advantages
- Full control over environment
- Scalable and reliable
- Can include database in same setup
- Professional deployment

---

## Option 3: VPS Deployment

**Best for:** Budget-conscious, full control, learning  
**Cost:** $5-10/month for VPS  
**Effort:** ⭐⭐⭐⭐⭐ (Advanced)

### Steps

1. **Create VPS**
   - DigitalOcean Droplet ($5/month)
   - AWS EC2 t3.micro (Free tier eligible)
   - Vultr, Linode, or similar

2. **Set up server**
   ```bash
   # SSH into your server
   ssh root@your-server-ip
   
   # Update system
   apt update && apt upgrade -y
   
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   
   # Install Docker Compose
   curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
   chmod +x /usr/local/bin/docker-compose
   ```

3. **Deploy application**
   ```bash
   # Clone your repository
   git clone https://github.com/your-username/anesko.git
   cd anesko
   
   # Set up environment variables
   cp .env.example .env
   nano .env  # Add your database credentials
   
   # Start services
   docker-compose up -d
   ```

4. **Set up domain and SSL**
   ```bash
   # Install nginx
   apt install nginx
   
   # Configure reverse proxy
   # Install Certbot for free SSL
   apt install certbot python3-certbot-nginx
   certbot --nginx -d your-domain.com
   ```

---

## Option 4: Heroku

**Best for:** Quick deployment, Git-based workflow  
**Cost:** $7/month for basic dyno  
**Effort:** ⭐⭐⭐☆☆ (Moderate)

### Steps

1. **Prepare for Heroku**
   ```bash
   # Install Heroku CLI
   # Create these files in shiny-app/:
   ```

   **Procfile:**
   ```
   web: R -f app.R --gui-none --no-save
   ```

   **runtime.txt:**
   ```
   r-4.3.0-20230621
   ```

   **init.R:**
   ```r
   # Install required packages
   my_packages = c("shiny", "shinydashboard", "DBI", "RPostgreSQL", "pool", "dplyr", "ggplot2", "plotly", "DT")
   install_if_missing = function(p) {
     if (p %in% rownames(installed.packages()) == FALSE) {
       install.packages(p)
     }
   }
   invisible(sapply(my_packages, install_if_missing))
   ```

2. **Deploy to Heroku**
   ```bash
   cd ~/anesko/shiny-app
   git init
   git add .
   git commit -m "Initial commit"
   
   heroku create american-authorship-db
   heroku buildpacks:set https://github.com/virtualstaticvoid/heroku-buildpack-r.git
   
   # Add database (requires add-on)
   heroku addons:create heroku-postgresql:hobby-dev
   
   git push heroku main
   ```

---

## Database Options (Updated January 2025)

### Recommended: Neon PostgreSQL

**Why Neon?** (Replaced ElephantSQL)
- ✅ **500MB storage** (vs ElephantSQL's 20MB)
- ✅ **No connection limits**
- ✅ **Built-in connection pooling**
- ✅ **Serverless scaling**

**Setup:**
```bash
./setup_neon.sh      # Configure credentials
./migrate_to_neon.sh  # Migrate data
```

### Alternative Options:

1. **Supabase** - 500MB free + real-time features
2. **Railway** - $5/month credits, GitHub integration  
3. **SQLite** - Convert for single-user apps
4. **AWS RDS** - Production with free tier

## Comparison Matrix

| Option | Cost | Ease | Control | Database | SSL | Custom Domain |
|--------|------|------|---------|----------|-----|---------------|
| **ShinyApps.io** | Free-$99/mo | ⭐⭐⭐⭐⭐ | ⭐⭐☆☆☆ | External only | ✅ | Paid plans |
| **Docker+Cloud** | $5-20/mo | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐⭐ | Included | ✅ | ✅ |
| **VPS** | $5-10/mo | ⭐⭐☆☆☆ | ⭐⭐⭐⭐⭐ | Included | Manual | ✅ |
| **Heroku** | $7+/mo | ⭐⭐⭐☆☆ | ⭐⭐⭐☆☆ | Add-on required | ✅ | ✅ |

## Recommendations

### For Academic Research/Demos:
1. **Start with ShinyApps.io** + Neon free tier
2. **Upgrade to paid ShinyApps.io** if more hours needed

### For Production/Portfolio:
1. **DigitalOcean App Platform** (easiest cloud deployment)
2. **VPS with Docker** (most cost-effective)

### For Learning/Experimentation:
1. **Local Docker setup** first
2. **VPS deployment** for hands-on experience

## Security Checklist

- [ ] Database credentials in environment variables (never in code)
- [ ] SSL/HTTPS enabled (`sslmode=require` for cloud databases)
- [ ] Database access restricted to app servers only
- [ ] Regular backups configured
- [ ] Monitoring and logging set up
- [ ] Keep packages updated

## Troubleshooting

### Common Issues:

1. **Database connection fails:**
   - Check SSL configuration (`DB_SSLMODE=require`)
   - Verify credentials and connection strings
   - Test database connection separately

2. **App won't start:**
   - Check R package installation
   - Verify file paths and permissions
   - Review application logs

3. **Slow performance:**
   - Optimize database queries
   - Implement caching
   - Upgrade server resources

### ElephantSQL Migration:

If you were using ElephantSQL (now discontinued):

```bash
# Quick migration to Neon
./setup_neon.sh           # Set up new Neon database
./migrate_to_neon.sh       # Migrate your existing data
./test_app_with_neon.sh    # Test the new setup
```

### Getting Help:

- Check application logs first
- Test locally with same environment
- Search documentation for your hosting platform
- Contact support for paid platforms

---

**Next Steps:**
1. Choose your deployment option
2. Follow the specific guide
3. Set up monitoring and backups
4. Share your deployed app URL!

**Support:** For questions specific to this app, refer to the project documentation or contact the development team.

---

**Updated**: January 2025 (Post-ElephantSQL)  
**Recommended Path**: Neon + ShinyApps.io for fastest deployment 