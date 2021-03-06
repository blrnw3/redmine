require 'net/http'
require 'net/https'
require 'json'

class ProducerAlertsToTickets
	
	def query_api
		url_base = Setting.plugin_aam_producer_alerts['producer_alerts_url']
		auth = {
			username: Setting.plugin_aam_producer_alerts['username'],
			password: Setting.plugin_aam_producer_alerts['password']
		}
		params = '?username=' + auth[:username] + '&password=' + auth[:password]
		uri = URI.join(url_base, params)
		http = Net::HTTP.new(uri.host, uri.port)
		
		if url_base.include? "https"
			http.use_ssl = true
			http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		end
		
		req = Net::HTTP::Get.new(uri.request_uri)
		return http.request(req)
  end
	
	def add_tickets_from_alerts
		response_json = (ActiveSupport::JSON.decode query_api.body)["data"]
		@alerts_count = response_json['count']
		puts "Producer returned #{@alerts_count} alerts" if @debugging
		
    response_json['alerts'].each do |alert|
			unless Issue.find_by_uuid alert['ticket_uuid']
				#New alert, so create new ticket stub
				puts "Processing new alert: " + alert['subject'] if @debugging
				
				ticket = Issue.new
				#Guaranteed fields from Producer
				ticket.uuid = alert['ticket_uuid']
				ticket.subject = alert['subject']
				ticket.description = alert['description']
				
				ticket.cinema_id = alert['complex_id'] if Cinema.find_by_external_id alert['complex_id']
				
				screen = Screen.find_by_uuid alert['screen_uuid']
				ticket.screen_id = screen.id if screen
				
				device = Device.find_by_uuid alert['device_uuid']
				ticket.device_id = device.id if device
				
				#Open the ticket immediately
				ticket.start_date = DateTime.now
				
				#Add required fields to pass the active record callbacks for an Issue
				ticket.author_id = User.first.id #Anonymous
				ticket.project_id = Project.first.id #Hopefully Lifeguard
				ticket.tracker_id = Tracker.first.id #Hopefully Support
				
				#Print error messages in debug mode
				success = @debugging ? ticket.save! : ticket.save

				@new_count += 1 if success
			else
				@skipped_count += 1
			end
		end
	end
	  
	def run(debug)
		@debugging = debug || false
		puts "Start, #{Time.now.to_s}:  Running Producer alerts_to_tickets with debugging " + @debugging.to_s

		@new_count = 0
		@alerts_count = 0
		@skipped_count = 0
		
		add_tickets_from_alerts
		
		error_count = @alerts_count - @new_count - @skipped_count
		puts "WARNING! #{error_count} new alerts could not be ticketised. Run task in debug mode to solve." if error_count > 0
		
		puts "End, #{Time.now.to_s}:  #{@new_count} alerts were ticketised (#{@skipped_count} existing tickets skipped)."
	end
  
end