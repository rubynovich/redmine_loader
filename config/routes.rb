if Rails::VERSION::MAJOR >= 3
  RedmineApp::Application.routes.draw do
    match 'redmine_loader/:action', :controller => 'loader'
  end
else
  ActionController::Routing::Routes.draw do |map|
    map.connect 'redmine_loader/:action', :controller => 'loader'
  end
end
