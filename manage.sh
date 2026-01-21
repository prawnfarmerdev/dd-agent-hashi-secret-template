#!/bin/bash
set -e

SCRIPT_NAME="manage.sh"
VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect container runtime and compose tool
detect_runtime() {
    if command -v podman >/dev/null 2>&1; then
        RUNTIME="podman"
        COMPOSE_CMD="podman compose --in-pod false"
    elif command -v docker >/dev/null 2>&1; then
        RUNTIME="docker"
        COMPOSE_CMD="docker-compose"
    else
        echo -e "${RED}❌ No container runtime found (podman or docker)${NC}"
        exit 1
    fi
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Datadog Agent + Vault Manager${NC}"
    echo -e "${BLUE}  Version: $VERSION${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_usage() {
    echo "Usage: $SCRIPT_NAME [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  clean     - Clean up containers, networks, and temporary files"
    echo "  init      - Initialize environment (checks, .env setup)"
    echo "  deploy    - Deploy services (Vault + Datadog Agent)"
    echo "  test      - Run deployment test suite"
    echo "  all       - Run clean, init, deploy, test sequentially"
    echo "  status    - Show container status and health"
    echo "  logs      - Follow logs from all services"
    echo "  stop      - Stop services without removing"
    echo "  start     - Start stopped services"
    echo "  restart   - Restart services"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME all           # Full deployment with testing"
    echo "  $SCRIPT_NAME init          # Just initialize environment"
    echo "  $SCRIPT_NAME deploy test   # Deploy then test"
}

run_clean() {
    echo -e "${YELLOW}🧹 Running cleanup...${NC}"
    ./clean.sh
}

run_init() {
    echo -e "${YELLOW}🔧 Initializing environment...${NC}"
    ./init.sh
}

run_deploy() {
    echo -e "${YELLOW}🚀 Deploying services...${NC}"
    ./deploy.sh
}

run_test() {
    echo -e "${YELLOW}🧪 Testing deployment...${NC}"
    ./test-deployment.sh
}

run_status() {
    echo -e "${YELLOW}📊 Container Status:${NC}"
    echo ""
    
    # Detect runtime
    detect_runtime
    
    # Show running containers
    echo "Running containers:"
    echo "------------------"
    if $RUNTIME ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -v "NAMES"; then
        echo ""
    else
        echo "No containers running"
    fi
    
    # Show recent logs if containers exist
    if $RUNTIME ps --quiet >/dev/null 2>&1; then
        echo "Recent health checks:"
        echo "--------------------"
        if $RUNTIME inspect vault --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
            echo -e "${GREEN}✅ Vault: healthy${NC}"
        else
            echo -e "${YELLOW}⚠️  Vault: not healthy or not running${NC}"
        fi
        
        if $RUNTIME ps --format "{{.Names}}" | grep -q "datadog-agent"; then
            echo -e "${GREEN}✅ Datadog Agent: running${NC}"
        else
            echo -e "${YELLOW}⚠️  Datadog Agent: not running${NC}"
        fi
    fi
    
    # Check network
    echo ""
    echo "Network:"
    echo "--------"
    $RUNTIME network ls | grep dd-vault-net || echo "dd-vault-net network not found"
}

run_logs() {
    echo -e "${YELLOW}📋 Showing logs (Ctrl+C to exit)...${NC}"
    detect_runtime
    $COMPOSE_CMD logs -f
}

run_stop() {
    echo -e "${YELLOW}🛑 Stopping services...${NC}"
    detect_runtime
    $COMPOSE_CMD stop
}

run_start() {
    echo -e "${YELLOW}▶️ Starting services...${NC}"
    detect_runtime
    $COMPOSE_CMD start
}

run_restart() {
    echo -e "${YELLOW}🔄 Restarting services...${NC}"
    detect_runtime
    $COMPOSE_CMD restart
}

# Main execution
main() {
    print_header
    
    if [ $# -eq 0 ]; then
        print_usage
        exit 0
    fi
    
    case "$1" in
        clean)
            run_clean
            ;;
        init)
            run_init
            ;;
        deploy)
            run_deploy
            ;;
        test)
            run_test
            ;;
        all)
            run_clean
            run_init
            run_deploy
            echo ""
            echo -e "${YELLOW}⏳ Waiting for services to initialize before testing...${NC}"
            sleep 15
            run_test
            ;;
        status)
            run_status
            ;;
        logs)
            run_logs
            ;;
        stop)
            run_stop
            ;;
        start)
            run_start
            ;;
        restart)
            run_restart
            ;;
        help|--help|-h)
            print_usage
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo ""
            print_usage
            exit 1
            ;;
    esac
}

# Allow multiple commands
for cmd in "$@"; do
    main "$cmd"
done

# If no commands processed (shouldn't happen), show help
if [ $# -eq 0 ]; then
    print_usage
fi