require 'redmine'

Redmine::Plugin.register :redmine_loader do
  name 'MS Project file loader'
  author 'Roman Shipiev'
  description 'Basic MS Project file loader (XML)'
  version '0.0.12'
  requires_redmine :version_or_higher => '0.9.2'
  url 'https://bitbucket.org/rubynovich/redmine_loader'
  author_url 'http://roman.shipiev.me'


  # Commented out because it refused to work in development mode
  default_tracker_name = 'Features' #Tracker.find_by_id( 1 ).name
  default_tracker_alias = 'Tracker'

  settings :default => {'tracker' => default_tracker_name, 'tracker_alias' => default_tracker_alias }, :partial => 'settings/loader_settings'

  project_module :project_xml_importer do
    permission :import_issues_from_xml, :loader => [:new, :create]
  end

  menu :project_menu, :loader, { :controller => 'loader', :action => 'new' },
    :caption => :label_menu_loader, :after => :new_issue, :param => :project_id
end

if Rails::VERSION::MAJOR < 3
  require 'dispatcher'
  object_to_prepare = Dispatcher
else
  object_to_prepare = Rails.configuration
end

object_to_prepare.to_prepare do
  [:issue].each do |cl|
    require "loader_#{cl}_patch"
  end

  [
    [Issue, LoaderPlugin::IssuePatch]
  ].each do |cl, patch|
    cl.send(:include, patch) unless cl.included_modules.include? patch
  end
end
