namespace :freshbooks do
  desc "Import FreshBooks time entries from CSV"
  task import_time_entries: :environment do
    file_path = ENV["FILE"]
    progress_every = ENV.fetch("PROGRESS_EVERY", FreshbooksImporter::DEFAULT_PROGRESS_EVERY).to_i

    if file_path.blank?
      abort "Usage: bin/rails freshbooks:import_time_entries FILE=db/freshbooks_exports/time_entry_brochard_2026.csv [USER_EMAIL=user@example.com] [PROGRESS_EVERY=250]"
    end

    user = if ENV["USER_EMAIL"].present?
      User.find_by(email: ENV["USER_EMAIL"])
    else
      filename = File.basename(file_path).downcase
      matches = User.all.select { |user| filename.include?(user.last_name.downcase) }
      matches.one? ? matches.first : nil
    end

    if user.blank?
      abort "Could not determine user. Pass USER_EMAIL=user@example.com or include a unique last name in the filename."
    end

    importer = FreshbooksImporter.new(
      file_path,
      user,
      progress_every: progress_every.positive? ? progress_every : nil,
      progress_io: $stdout
    )
    result = importer.import

    puts result.summary

    next if result.errors.empty?

    puts
    puts "Errors:"
    result.errors.each { |error| puts "- #{error}" }
    abort "Import completed with errors"
  end
end
