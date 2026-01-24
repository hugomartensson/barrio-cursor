#!/bin/bash

# Quick status check for all services

cd "$(dirname "$0")"

echo "🔍 Checking Barrio Server Status..."
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check Docker
echo -n "Docker: "
if docker ps > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${RED}❌ Not running - Start Docker Desktop${NC}"
fi

# Check PostgreSQL container
echo -n "PostgreSQL Container: "
if docker ps --format "{{.Names}}" | grep -q "barrio-postgres"; then
    echo -e "${GREEN}✅ Running${NC}"
    
    # Check if accepting connections
    echo -n "PostgreSQL Ready: "
    if docker exec barrio-postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Yes${NC}"
    else
        echo -e "${YELLOW}⚠️  Starting...${NC}"
    fi
else
    echo -e "${RED}❌ Not running - Run: docker-compose up -d${NC}"
fi

# Check server port
echo -n "Server (Port 3000): "
if lsof -ti:3000 > /dev/null 2>&1; then
    PID=$(lsof -ti:3000)
    echo -e "${GREEN}✅ Running (PID: $PID)${NC}"
else
    echo -e "${RED}❌ Not running${NC}"
fi

# Check .env
echo -n ".env file: "
if [ -f .env ]; then
    echo -e "${GREEN}✅ Exists${NC}"
else
    echo -e "${RED}❌ Missing${NC}"
fi

# Check node_modules
echo -n "Dependencies: "
if [ -d node_modules ]; then
    echo -e "${GREEN}✅ Installed${NC}"
else
    echo -e "${RED}❌ Missing - Run: npm install${NC}"
fi

echo ""
echo "💡 To start everything, run: ./start-services.sh"
