#!/bin/bash

# Barrio Server Startup Script
# This script ensures Docker, PostgreSQL, and the server are running

set -e

cd "$(dirname "$0")"
SERVER_DIR="$(pwd)"

echo "🚀 Starting Barrio Server Services..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if Docker is running
check_docker() {
    if ! docker ps > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running${NC}"
        echo "   Please start Docker Desktop and wait for it to initialize."
        exit 1
    fi
    echo -e "${GREEN}✅ Docker is running${NC}"
}

# Function to start Docker containers
start_docker() {
    echo ""
    echo "🐳 Starting Docker containers..."
    
    # Check if containers are already running
    if docker ps --format "{{.Names}}" | grep -q "barrio-postgres"; then
        echo -e "${GREEN}✅ PostgreSQL container is already running${NC}"
    else
        echo "   Starting PostgreSQL container..."
        docker-compose up -d postgres
        
        echo "   Waiting for PostgreSQL to be ready..."
        for i in {1..30}; do
            if docker exec barrio-postgres pg_isready -U postgres > /dev/null 2>&1; then
                echo -e "${GREEN}✅ PostgreSQL is ready${NC}"
                break
            fi
            if [ $i -eq 30 ]; then
                echo -e "${RED}❌ PostgreSQL failed to start after 30 seconds${NC}"
                exit 1
            fi
            sleep 1
        done
    fi
}

# Function to check dependencies
check_dependencies() {
    echo ""
    echo "🔍 Checking dependencies..."
    npm run check-deps
}

# Function to ensure Prisma is ready
setup_prisma() {
    echo ""
    echo "📦 Setting up Prisma..."
    
    # Generate Prisma client if needed
    if [ ! -d "node_modules/.prisma/client" ]; then
        echo "   Generating Prisma client..."
        npx prisma generate
    fi
    
    # Check if migrations are up to date
    echo "   Checking database migrations..."
    npx prisma migrate status || {
        echo -e "${YELLOW}⚠️  Migrations may be pending. Run 'npm run migrate' if needed.${NC}"
    }
}

# Function to start the server
start_server() {
    echo ""
    echo "🌐 Starting server..."
    echo ""
    
    # Check if server is already running
    if lsof -ti:3000 > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port 3000 is already in use${NC}"
        echo "   The server may already be running."
        echo "   To restart, stop the existing process first."
        exit 1
    fi
    
    echo -e "${GREEN}✅ Starting development server on port 3000...${NC}"
    echo ""
    npm run dev
}

# Main execution
main() {
    check_docker
    start_docker
    check_dependencies
    setup_prisma
    start_server
}

# Run main function
main
