require 'redmine'

Redmine::Plugin.register :redmine_loader do

  name 'Basic project file loader for Redmine'

  author 'Simon Stearn largely hacking Andrew Hodgkinsons trackrecord code (sorry Andrew)'

  description 'Basic project file loader'

  version '0.0.12'

  requires_redmine :version_or_higher => '0.9.2'

  # Commented out because it refused to work in development mode
  default_tracker_name = 'Features' #Tracker.find_by_id( 1 ).name
  default_tracker_alias = 'Tracker'

  settings :default => {'tracker' => default_tracker_name, 'tracker_alias' => default_tracker_alias }, :partial => 'settings/loader_settings'

  project_module :project_xml_importer do
    permission :import_issues_from_xml, :loader => [:new, :create]
  end

  menu :project_menu, :loader, { :controller => 'loader', :action => 'new' },
    :caption => :label_menu_loader, :after => :new_issue, :param => :project_id

  if Rails::VERSION::MAJOR < 3
    # MS Project used YYYY-MM-DDTHH:MM:SS format. There no support of time zones, so time will be in UTC
    ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.merge!(
      :ms_xml => lambda{ |time| time.utc.strftime("%Y-%m-%dT%H:%M:%S") }
    )

    # MS Project used YYYY-MM-DDTHH:MM:SS format. There no support of time zones, so time will be in UTC
    ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.merge!(
      :ms_xml => lambda{ |time| time.utc.strftime("%Y-%m-%dT%H:%M:%S") }
    )
  else
    # MS Project used YYYY-MM-DDTHH:MM:SS format. There no support of time zones, so time will be in UTC
    Date::DATE_FORMATS.merge!(
      :ms_xml => lambda{ |time| time.utc.strftime("%Y-%m-%dT%H:%M:%S") }
    )

    # MS Project used YYYY-MM-DDTHH:MM:SS format. There no support of time zones, so time will be in UTC
    Date::DATE_FORMATS.merge!(
      :ms_xml => lambda{ |time| time.utc.strftime("%Y-%m-%dT%H:%M:%S") }
    )
  end
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
