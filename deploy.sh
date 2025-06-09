#!/bin/bash

# American Authorship Database - Deployment Helper Script
# This script helps you deploy your Shiny app online

echo "🚀 American Authorship Database - Deployment Helper"
echo "=================================================="
echo ""

# Check if we're in the right directory
if [ ! -f "shiny-app/app.R" ]; then
    echo "❌ Please run this script from the project root directory (anesko/)"
    exit 1
fi

echo "📋 Choose your deployment option:"
echo ""
echo "1. ShinyApps.io (Easiest - Free tier available)"
echo "2. Docker + DigitalOcean (Recommended for production)"
echo "3. Docker + Local testing first"
echo "4. AWS/Google Cloud"
echo "5. Setup database only"
echo ""

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo ""
        echo "🎯 Setting up ShinyApps.io deployment..."
        echo ""
        echo "📝 Prerequisites checklist:"
        echo "[ ] R/RStudio installed"
        echo "[ ] Cloud database setup (Neon recommended)"
        echo "[ ] ShinyApps.io account created"
        echo ""
        
        read -p "Have you completed the prerequisites? (y/n): " prereq
        
        if [ "$prereq" = "y" ]; then
            echo ""
            echo "🔧 Installing rsconnect package..."
            R -e "if (!require('rsconnect')) install.packages('rsconnect')"
            
            echo ""
            echo "📱 Next steps:"
            echo "1. Go to https://www.shinyapps.io/admin/#/tokens"
            echo "2. Copy your token and secret"
            echo "3. Run in R console:"
            echo "   rsconnect::setAccountInfo(name='username', token='token', secret='secret')"
            echo "4. Run: cd shiny-app && Rscript deploy_shinyapps.R"
            echo ""
        else
            echo "📚 Please see docs/deployment/README.md for detailed prerequisites"
        fi
        ;;
        
    2)
        echo ""
        echo "🐳 Setting up Docker + DigitalOcean deployment..."
        echo ""
        
        # Check if Docker is installed
        if ! command -v docker &> /dev/null; then
            echo "📦 Docker not found. Installing Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            rm get-docker.sh
        fi
        
        # Check if docker-compose is installed
        if ! command -v docker-compose &> /dev/null; then
            echo "📦 Installing Docker Compose..."
            sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        
        echo "✅ Docker setup complete!"
        echo ""
        echo "📝 Next steps:"
        echo "1. Create database backup: pg_dump -h localhost -U siyang american_authorship > data/backup.sql"
        echo "2. Test locally: docker-compose up --build"
        echo "3. Create DigitalOcean account and follow deployment guide"
        echo "4. See docs/deployment/README.md for detailed instructions"
        ;;
        
    3)
        echo ""
        echo "🧪 Setting up local Docker testing..."
        echo ""
        
        # Create backup first
        echo "📊 Creating database backup..."
        mkdir -p data
        if pg_dump -h localhost -U siyang american_authorship > data/backup.sql 2>/dev/null; then
            echo "✅ Database backup created: data/backup.sql"
        else
            echo "⚠️  Database backup failed. Please ensure PostgreSQL is running and accessible."
            echo "Manual backup: pg_dump -h localhost -U siyang american_authorship > data/backup.sql"
        fi
        
        echo ""
        echo "🐳 Building and starting containers..."
        docker-compose up --build -d
        
        echo ""
        echo "🎉 Local Docker setup complete!"
        echo "📱 Your app should be available at: http://localhost:3838/american-authorship"
        echo ""
        echo "📝 Commands:"
        echo "  View logs:     docker-compose logs -f"
        echo "  Stop:          docker-compose down"
        echo "  Restart:       docker-compose restart"
        ;;
        
    4)
        echo ""
        echo "☁️  Setting up cloud deployment..."
        echo ""
        echo "📚 Please follow the detailed guides in docs/deployment/README.md for:"
        echo "- AWS Fargate deployment"
        echo "- Google Cloud Run deployment"
        echo "- Azure Container Instances"
        echo ""
        echo "🐳 First, test locally with Docker:"
        echo "docker-compose up --build"
        ;;
        
    5)
        echo ""
        echo "🗄️  Database setup options:"
        echo ""
        echo "1. Neon (Recommended - 500MB free, no limits)"
        echo "2. Supabase (500MB free + extra features)"
        echo "3. Railway ($5 monthly credits)"
        echo "4. Convert to SQLite (Simplest)"
        echo ""
        
        read -p "Choose database option (1-4): " db_choice
        
        case $db_choice in
            1)
                echo "🚀 Neon PostgreSQL setup:"
                echo "1. Go to https://neon.tech"
                echo "2. Create free account"
                echo "3. Create new project: 'american-authorship-db'"
                echo "4. Copy connection details"
                echo "5. Run: ./setup_neon.sh"
                echo ""
                echo "Neon offers:"
                echo "✅ 500MB storage (25x more than old ElephantSQL)"
                echo "✅ No connection limits"
                echo "✅ Built-in connection pooling"
                echo "✅ Automatic backups"
                ;;
            2)
                echo "🔥 Supabase setup:"
                echo "1. Go to https://supabase.com"
                echo "2. Create new project: 'american-authorship'"
                echo "3. Get database connection string"
                echo "4. Configure with SSL enabled"
                ;;
            3)
                echo "🚄 Railway setup:"
                echo "1. Go to https://railway.app"
                echo "2. Sign up with GitHub"
                echo "3. Create new project → Add PostgreSQL"
                echo "4. Copy connection details from Variables tab"
                ;;
            4)
                echo "📁 Converting to SQLite..."
                echo "This will create a self-contained database file."
                
                read -p "Proceed with SQLite conversion? (y/n): " sqlite_confirm
                
                if [ "$sqlite_confirm" = "y" ]; then
                    R -e "
                    library(DBI)
                    library(RPostgreSQL)
                    library(RSQLite)
                    
                    # Connect to PostgreSQL
                    pg_con <- dbConnect(RPostgreSQL::PostgreSQL(),
                                       host = 'localhost',
                                       dbname = 'american_authorship',
                                       user = 'siyang',
                                       password = Sys.getenv('DB_PASSWORD', 'anesko2024'))
                    
                    # Create SQLite database
                    sqlite_con <- dbConnect(RSQLite::SQLite(), 'shiny-app/data/american_authorship.sqlite')
                    
                    # Copy tables
                    tables <- dbListTables(pg_con)
                    for (table in tables) {
                      data <- dbReadTable(pg_con, table)
                      dbWriteTable(sqlite_con, table, data, overwrite = TRUE)
                      cat('Copied table:', table, '\n')
                    }
                    
                    dbDisconnect(pg_con)
                    dbDisconnect(sqlite_con)
                    cat('✅ SQLite database created!\n')
                    "
                fi
                ;;
            *)
                echo "📚 See shiny-app/database_setup_guide.md for detailed instructions"
                ;;
        esac
        ;;
        
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "📚 For detailed documentation, see:"
echo "   - docs/deployment/README.md"
echo "   - shiny-app/database_setup_guide.md"
echo ""
echo "🆘 Need help? Check the troubleshooting section in the deployment guide." 