# SoundLog - Time Tracking App

A minimal, boring Rails 8 time tracking app for manual time entry.

Deploys via Capistrano + Puma + systemd, using MySQL for the database.

## Features

- **User management**: Admin + member accounts with bcrypt authentication
- **Clients**: Create and manage clients (users own their own)
- **Projects**: Organize time by project under a client
- **Time entries**: Log hours manually with project, date, and description
- **Monthly view**: Filter entries by month with totals
- **CSV export**: Download time entries for a month
- **Simple access**: Users see only their own data; admins see everything

## Tech Stack

- **Rails 8.0** with Importmap, Turbo, Stimulus
- **MySQL 8.0+** for database
- **Puma 6** with systemd service management
- **Capistrano 3.19** for deployment
- **rbenv** for Ruby version management

## Prerequisites

- Ruby 3.3.0 (via rbenv)
- MySQL 8.0+ (local + production)
- Bundler
- Git

## Setup

### 1. Create Rails App

If you haven't already, generate a new Rails 8 app with MySQL:

```bash
cd /home/roman/code
rails new soundlog --database=mysql --skip-test
cd soundlog
```

### 2. Copy SoundLog Files

Copy all generated code files from this repository into your Rails app directory.

### 3. Install Dependencies

```bash
bundle install
```

### 4. Create & Migrate Database

```bash
rails db:create
rails db:migrate
rails db:seed
```

### 5. Start Development Server

```bash
./bin/dev
```

Visit `http://localhost:3000`

## Test Users (from seeds)

These accounts are created by `rails db:seed` for local development and demo use only. Do not use these credentials in staging or production.

- **Admin**: admin@soundlog.local / admin123
- **Member**: user@soundlog.local / user123

## Deployment

Production deployment uses **Capistrano** with **Puma** and **systemd**.

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete setup guide including:
- Server prerequisites (rbenv, MySQL, Nginx)
- Capistrano configuration
- Systemd service setup
- Nginx reverse proxy config
- First-time deployment steps

Quick reference:
```bash
cap production deploy
cap production puma:restart
```

## Architecture

### Models
- **User**: email, password_digest, admin flag
- **Client**: name, user_id (owner)
- **Project**: name, user_id (owner), client_id, active flag, description
- **TimeEntry**: user_id, project_id, date, hours (decimal), description

### Key Patterns

**Authorization:**
- Admin: can see/manage everything
- Regular user: can only see/manage their own clients, projects, and time entries

**Routes:**
- POST /login, DELETE /logout (authentication)
- /clients, /projects, /time_entries (RESTful CRUD)
- /time_entries?month=2026-04 (monthly filtering)
- /time_entries.csv (CSV export)

**Views:**
- Server-rendered ERB, no JavaScript framework
- Minimal inline CSS for simplicity
- No dependencies on CSS frameworks

## File Structure

```
app/
  models/
    user.rb
    client.rb
    project.rb
    time_entry.rb
  controllers/
    application_controller.rb
    sessions_controller.rb
    clients_controller.rb
    projects_controller.rb
    time_entries_controller.rb
    dashboard_controller.rb
  views/
    layouts/application.html.erb
    sessions/new.html.erb
    clients/{index,new,edit,show}.html.erb
    projects/{index,new,edit,show}.html.erb
    time_entries/{index,new,edit,show}.html.erb
    dashboard/index.html.erb

db/
  migrate/
    [timestamps]_create_*.rb
  seeds.rb

config/
  routes.rb
  database.yml (auto-generated)
```

## Usage

### Log Time
1. Click "Time Entries"
2. Click "+ Log Time"
3. Select project, date, hours
4. Add optional description
5. Submit

### Manage Work
1. Create Clients (your clients/customers)
2. Create Projects under Clients
3. Log time to Projects
4. Filter by month to review

### Export Data
1. Go to Time Entries
2. Select month via filter
3. Click "Export CSV"
4. Download .csv file with: Date, Project, Client, Hours, Description

### Admin Functions
1. Log in as admin
2. Can view/edit all users' time entries
3. Can create/edit any client or project
4. Can manage all data globally

## Notes

- No complex features: no timers, budgets, invoicing, notifications
- Database: PostgreSQL (configure in config/database.yml)
- Authentication: bcrypt (has_secure_password)
- Views: Pure ERB with inline CSS
- Deployment: Standard Rails (Heroku, Render, etc. ready)

## Next Steps (Future)

- FreshBooks CSV import (rake task for admin)
- Edit user profiles
- More admin dashboard stats
- API for mobile if needed
