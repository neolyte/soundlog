# db/seeds.rb
# Development/demo seed data only.
# Do not use these credentials outside a local or throwaway environment.

# Create initial users
admin = User.create!(
  first_name: "Admin",
  last_name: "User",
  email: "admin@soundlog.local",
  password: "admin123",
  password_confirmation: "admin123",
  admin: true
)

user = User.create!(
  first_name: "Demo",
  last_name: "User",
  email: "user@soundlog.local",
  password: "user123",
  password_confirmation: "user123",
  admin: false
)

puts "✓ Created admin user: admin@soundlog.local / admin123"
puts "✓ Created regular user: user@soundlog.local / user123"

# Create sample clients for each user
admin_client = Client.create!(name: "Admin Client", user: admin)
user_client = Client.create!(name: "User Client", user: user)

puts "✓ Created sample clients"

# Create sample projects
admin_project = Project.create!(
  name: "Admin Project",
  client: admin_client,
  user: admin,
  description: "Sample project for admin user"
)

user_project = Project.create!(
  name: "User Project",
  client: user_client,
  user: user,
  description: "Sample project for regular user"
)

puts "✓ Created sample projects"

# Create sample time entries
TimeEntry.create!(
  user: admin,
  project: admin_project,
  date: Date.current,
  hours: 2.5,
  description: "Sample admin work"
)

TimeEntry.create!(
  user: user,
  project: user_project,
  date: Date.current,
  hours: 3.0,
  description: "Sample user work"
)

puts "✓ Created sample time entries"
puts "\n✅ Database seeded successfully!"
