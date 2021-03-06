start = Time.now
if !CONFIG.donorbox || !CONFIG.donorbox.email || !CONFIG.donorbox.key
  raise "Donorbox email an API key haven't been added to config"
end
donorbox_email = CONFIG.donorbox.email
donorbox_key = CONFIG.donorbox.key
page = 1
per_page = 100
debug = true
total_verified_users = 0
new_verified_users = 0
new_verified_user_parents = 0
failed_users = 0
failed_parents = 0
donors = {}
while true
  url = "https://donorbox.org/api/v1/donors?page=#{page}&per_page=#{per_page}"
  puts url if debug
  response = RestClient.get( url, {
    "Authorization" => "Basic #{Base64.strict_encode64( "#{donorbox_email}:#{donorbox_key}" ).strip}",
    "User-Agent" => "iNaturalist/Donorbox"
  } )
  json = JSON.parse( response )
  break if json.size == 0
  json.each do |donor|
    next if donors[donor["id"]]
    donors[donor["id"]] = true
    puts "Donor #{donor["id"]}"
    if user = User.find_by_email( donor["email"] )
      unless user.donor?
        if user.update_attributes( donorbox_donor_id: donor["id"] )
          puts "\tMarked #{user} as a donor"
          new_verified_users += 1
        else
          puts "Failed to mark #{user} as a donor: #{user.errors.full_messages.to_sentence}"
          failed_users += 1
        end
      end
      total_verified_users += 1
    end
    if user_parent = UserParent.find_by_email( donor["email"] )
      unless user_parent.donor?
        begin
          if user_parent.update_attributes( donorbox_donor_id: donor["id"] )
            puts "\tMarked #{user_parent} as a donor"
            new_verified_user_parents += 1
          else
            puts "Failed to mark #{user_parent} as a donor: #{user.errors.full_messages.to_sentence}"
            failed_parents += 1
          end
        rescue OpenSSL::SSL::SSLError => e
          # Mail failed to send
          puts "Failed to mark #{user_parent} as a donor: mail delivery failed (#{e})"
          failed_parents += 1
        end
      end
    end
  end
  page += 1
end
puts
puts "#{donors.size} donors, #{total_verified_users} donor users, #{new_verified_users} new donor users, #{new_verified_user_parents} new donor parents, #{failed_users} failed users, #{failed_parents} failed parents in #{Time.now - start}s"
puts
