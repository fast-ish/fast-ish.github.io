#!/bin/bash

# fastish Documentation Local Server
# Serves the docsify documentation site locally for development

set -e

PORT=${1:-3000}
HOST=${2:-localhost}

echo "🚀 Starting fastish documentation server..."
echo "📍 Server will be available at: http://${HOST}:${PORT}"
echo "🛑 Press Ctrl+C to stop the server"
echo ""

# Check if Python 3 is available
if command -v python3 &> /dev/null; then
    echo "✅ Using Python 3 HTTP server"
    python3 -m http.server $PORT --bind $HOST
# Fallback to Python 2
elif command -v python &> /dev/null; then
    echo "✅ Using Python 2 HTTP server"
    cd "$(dirname "$0")"
    python -m SimpleHTTPServer $PORT
# Check for Node.js http-server
elif command -v npx &> /dev/null; then
    echo "✅ Using npx http-server"
    npx http-server -p $PORT -a $HOST -o
# Check for PHP
elif command -v php &> /dev/null; then
    echo "✅ Using PHP built-in server"
    php -S ${HOST}:${PORT}
else
    echo "❌ Error: No suitable HTTP server found."
    echo ""
    echo "Please install one of the following:"
    echo "  - Python 3: brew install python3"
    echo "  - Node.js: brew install node"
    echo "  - PHP: brew install php"
    exit 1
fi
