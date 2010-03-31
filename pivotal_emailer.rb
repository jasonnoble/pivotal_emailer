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
  from = "Ruby Team <railsdev@rentals.com>"
  # to = "#{shareholder_emails[email].name} <#{email}>"
  # TODO This needs to handle inactive users
  to = "jason.noble@primedia.com"
  subject = "You need to accept Pivotal Stories"
  
  message = <<-END

Your Ruby Development team has completed one or more of the stories you requested.
Each of these stories require your acceptance in order to be complete.

Stories needing acceptance:

  END
  
  stories.each do |story|
    message << ["\t[#{story['project_name']}] #{story['story'].name}", "\tURL: #{story['story'].url}"].join("\n")
    message << "\n\n"
  end
  message <<  <<-END
For each story, please verify the functionality you requested was implemented correctly.

If you accept the story, please add a "sh_accepted" label by opening the story and selecting
the "Label Actions..." dropdown, then selecting the sh_accepted label.  You can optionally add 
comments.

If you do not accept the story, please add a comment to the story stating what is not implemented
correctly.  You then need to change the status of the story from Finished/Delivered to Rejected.

If you have any questions, please let a member of the Ruby team know.

Thanks,
Your Ruby Devs
  END

  puts email, "#######################", message, ''
  #Pony.mail(:to => to, :from => from, :subject => subject, :body => message)
end
  
__END__

rentals = PivotalTracker::Project.find(22353)
rentals.stories.all(:current_state => 'finished').sort{|a,b| a.name <=> b.name}.each {|s| puts s.name} && nil