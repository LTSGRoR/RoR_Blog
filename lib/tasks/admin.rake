namespace :admin do
  desc "Create a production administrator from ADMIN_EMAIL, ADMIN_NAME and ADMIN_PASSWORD"
  task provision: :environment do
    email = ENV.fetch("ADMIN_EMAIL")
    password = ENV.fetch("ADMIN_PASSWORD")
    raise "ADMIN_PASSWORD must have at least 12 characters" if password.length < 12
    raise "Account already exists; use the password recovery flow to rotate its password" if User.exists?(email: email)

    user = User.new(email: email, name: ENV.fetch("ADMIN_NAME", "Administrator"), password: password, role: :admin)
    user.skip_confirmation!
    user.save!
    puts "Administrator created."
  end
end
