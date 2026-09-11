#!/bin/bash

set -e

echo "Creating .env from Vercel environment variables..."

cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}
API_URL=${API_URL}
EOF

echo ".env created successfully."
