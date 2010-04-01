require 'rubygems'
require 'pivotal-tracker'
require 'yaml'

config = YAML.load(open(File.join(File.dirname(__FILE__), 'config.yml')))

PivotalTracker::Client.token = config['token']

shareholder_outstanding = Hash.new{ |h,k| h[k] = [] }
shareholder_emails = Hash.new

config['projects'].each do |project_id|
  project = PivotalTracker::Project.find(project_id)
  stories = project.stories.all(:current_state => ['finished', 'delivered'])
  unaccepted_stories = stories.select{ |s| s.labels.nil? || !s.labels.split(',').include?('sh_accepted') }
  next if unaccepted_stories.length == 0
  project_members = project.memberships.all
  unaccepted_stories.each do |story|
    # this story should have an email sent out
    shareholder = project_members.detect{ |m| m.name == story.requested_by }
    if shareholder.nil?
      # shareholder account is inactive
      #puts "   Story #{story.name} should probably be reassigned"
      shareholder_outstanding['inactive'].push({'project_name' => project.name, 'story' => story})
    else
      shareholder_emails[shareholder.email] ||= shareholder
      #puts "   Will email #{shareholder.email} about #{story.name}"
      shareholder_outstanding[shareholder.email].push({'project_name' => project.name, 'story' => story})
    end
  end
end

shareholder_outstanding.each do |email, stories|
  from = config['from']['email']
  if email == 'inactive'
    to = config['inactive_email']
    subject = config['inactive_subject'] || "You need to reassign Pivotal Stories"
    message = <<-END

#{config['from']['name']} has completed one or more of the following stories.

************ ACTION ITEM *****************************************************

Each of these stories needs to be reassigned to an active shareholder so that
it can be accepted.

Stories needing acceptance:

  END
  else
    to = "#{shareholder_emails[email].name} <#{email}>"
    subject = config['subject'] || "You need to accept Pivotal Stories"
    message = <<-END

#{config['from']['name']} has completed one or more of the stories you requested.
Each of these stories require your acceptance in order to be complete.

Stories needing acceptance:

  END
  end
  
  # TODO Remove this before putting anywhere
  # to = "jason.noble@primedia.com"
  stories.each do |story|
    message << ["\t[#{story['project_name']}] #{story['story'].name}", "\tURL: #{story['story'].url}"].join("\n")
    message << "\n\n"
  end
  message <<  <<-END
For each story, please verify the functionality you requested was implemented
correctly.

If you accept the story, please add a "sh_accepted" label by opening the story
and selecting the "Label Actions..." dropdown, then selecting the sh_accepted
label.  You can optionally add comments.

If you do not accept the story, please add a comment to the story stating what
is not implemented correctly.  You then need to change the status of the story
from Finished/Delivered to Rejected.

If you have any questions, please let a member of the Ruby team know.

Thanks,
#{config['from']['name']}
  END
  puts "From: #{from}"
  puts "To: #{to}"
  puts "Subject: #{subject}"
  puts
  puts message
  puts 
  puts "="*80
  puts
  #Pony.mail(:to => to, :from => from, :subject => subject, :body => message)
end