#!/usr/bin/env python3
"""
Database setup script for MapSumbong.
This script creates all tables, indexes, RLS policies, and functions in Supabase.
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

def get_supabase_client() -> Client:
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not url or not key:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")

    return create_client(url, key)

def execute_sql_file(client: Client, sql_content: str):
    """Execute SQL content by splitting into individual statements."""
    # Split SQL into statements (basic approach - may need refinement for complex SQL)
    statements = []
    current_statement = ""
    in_function = False

    for line in sql_content.split('\n'):
        line = line.strip()

        # Skip comments and empty lines
        if line.startswith('--') or not line:
            continue

        # Handle function definitions
        if line.startswith('CREATE OR REPLACE FUNCTION') or line.startswith('CREATE FUNCTION'):
            in_function = True
        elif line.startswith('$$ LANGUAGE plpgsql;') or line.startswith('$$;'):
            in_function = False

        current_statement += line + '\n'

        # End of statement
        if (not in_function and line.endswith(';')) or (in_function and line == '$$;'):
            if current_statement.strip():
                statements.append(current_statement.strip())
            current_statement = ""
            in_function = False

    # Execute each statement
    for i, statement in enumerate(statements, 1):
        if statement.strip():
            try:
                print(f"Executing statement {i}/{len(statements)}...")
                client.rpc('exec_sql', {'sql': statement}).execute()
            except Exception as e:
                print(f"Error executing statement {i}: {e}")
                print(f"Statement: {statement[:200]}...")
                raise

def setup_database():
    """Main function to set up the database."""
    print("Setting up MapSumbong database...")

    client = get_supabase_client()

    # Read the SQL schema file
    schema_file = os.path.join(os.path.dirname(__file__), '..', 'context', '01_DATABASE_SCHEMA.md')

    with open(schema_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Extract SQL blocks from markdown
    sql_blocks = []
    in_sql_block = False
    current_block = []

    for line in content.split('\n'):
        if line.strip().startswith('```sql'):
            in_sql_block = True
            current_block = []
        elif line.strip() == '```' and in_sql_block:
            in_sql_block = False
            if current_block:
                sql_blocks.append('\n'.join(current_block))
        elif in_sql_block:
            current_block.append(line)

    # Execute all SQL blocks
    for i, sql in enumerate(sql_blocks, 1):
        print(f"Executing SQL block {i}/{len(sql_blocks)}...")
        try:
            execute_sql_file(client, sql)
        except Exception as e:
            print(f"Error in SQL block {i}: {e}")
            # Continue with other blocks
            continue

    print("Database setup completed!")

if __name__ == "__main__":
    setup_database()</content>
<parameter name="filePath">c:\Users\codyj\Desktop\Coding\mapsumbong\backend\setup_database.py